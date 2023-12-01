/* vmp-server - A virtual multimedia processor
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import "VMPProfileManager.h"
#import "VMPErrors.h"
#import "VMPJournal.h"
#import "VMPProfileModel.h"

static NSString *const deviceTreeModelPath = @"/proc/device-tree/model";
static NSString *const envBinary = @"/usr/bin/env";

// Declare runtimePlatform and currentProfile rw for internal use
@interface VMPProfileManager ()

@property (readwrite) NSString *runtimePlatform;
@property (readwrite) VMPProfileModel *currentProfile;

@end

@implementation VMPProfileManager

+ (instancetype)managerWithPath:(NSString *)path error:(NSError **)error {
	NSFileManager *mgr;

	mgr = [NSFileManager defaultManager];

	// Currently, we only detect the Jetson Nano based on the device tree model entry.
	if ([mgr fileExistsAtPath:deviceTreeModelPath]) {
		NSString *model;

		model = [NSString stringWithContentsOfFile:deviceTreeModelPath
										  encoding:NSUTF8StringEncoding
											 error:error];
		if (!model) {
			return nil;
		}

		VMPDebug(@"Detected device tree model: %@", model);

		if ([model containsString:@"NVIDIA Jetson"]) {
			VMPDebug(@"Detected NVIDIA Jetson platform");
			return [VMPProfileManager managerWithPath:path
									  runtimePlatform:VMPProfilePlatformDeepstream6
												error:error];
		}
	}

	if ([mgr fileExistsAtPath:envBinary]) {
		// Check if vaapi is supported by running `vainfo` and checking for
		NSTask *task;
		NSData *outputData;
		NSPipe *outputPipe;

		setenv("DISPLAY", ":0", 1); // ":0" is a common virtual display

		task = [[NSTask alloc] init];
		outputPipe = [NSPipe pipe];

		// Configure Task
		[task setLaunchPath:envBinary];
		[task setArguments:@[ @"vainfo" ]];
		[task setStandardOutput:outputPipe];
		[task setStandardError:outputPipe];

		VMPDebug(@"Running vainfo ('%@' vainfo) to check for VAAPI support", envBinary);
		[task launch];
		[task waitUntilExit];

		// Read output
		outputData = [[outputPipe fileHandleForReading] readDataToEndOfFile];

		if ([outputData length] > 0) {
			VMPDebug(@"vainfo output: %@", [[NSString alloc] initWithData:outputData
																 encoding:NSUTF8StringEncoding]);
			NSString *outputString;

			outputString = [[NSString alloc] initWithData:outputData encoding:NSUTF8StringEncoding];

			// TODO: Check explicitly for h264 hardware encoding support
			// We are currently assuming that it is supported if VAAPI is supported
			if ([outputString containsString:@"VA-API version"]) {
				VMPInfo(@"Detected platform supporting VAAPI");
				return [VMPProfileManager managerWithPath:path
										  runtimePlatform:VMPProfilePlatformVAAPI
													error:error];
			}
		}
	}

	return [VMPProfileManager managerWithPath:path runtimePlatform:@"generic" error:error];
}

+ (instancetype)managerWithPath:(NSString *)path
				runtimePlatform:(NSString *)platform
						  error:(NSError **)error {
	return [[VMPProfileManager alloc] initWithPath:path runtimePlatform:platform error:error];
}

- (instancetype)initWithPath:(NSString *)path
			 runtimePlatform:(NSString *)platform
					   error:(NSError **)error {
	self = [super init];

	if (self) {
		_runtimePlatform = platform;

		// Sets availableProfiles property
		if (![self _searchForProfilesInPath:path error:error])
			return nil;

		// Sets currentProfiles property
		if (![self _selectBestProfileWithError:error])
			return nil;
	}

	return self;
}

- (BOOL)_searchForProfilesInPath:(NSString *)path error:(NSError **)error {
	NSFileManager *mgr;
	NSArray<NSString *> *contents;
	NSMutableArray<VMPProfileModel *> *found;

	mgr = [NSFileManager defaultManager];
	contents = [mgr contentsOfDirectoryAtPath:path error:error];
	if (!contents) {
		VMPError(@"Failed to read contents of directory at path '%@'", path);
		return NO;
	}
	found = [NSMutableArray arrayWithCapacity:[contents count]];

	VMPDebug(@"Found %lu files %@ in profile directory '%@'", [contents count], contents, path);

	VMPProfileModel *profile;
	for (NSString *cur in contents) {
		NSDictionary *propertyList;
		NSString *curPath;

		curPath = [path stringByAppendingPathComponent:cur];

		propertyList = [NSDictionary dictionaryWithContentsOfFile:curPath];
		if (!propertyList) {
			VMP_FAST_ERROR(error, VMPErrorCodePropertyListError,
						   @"Failed to read plist at path '%@'", curPath);
			return NO;
		}

		// Create profile object from property list representation
		profile = [[VMPProfileModel alloc] initWithPropertyList:propertyList error:error];
		if (!profile) {
			VMPError(@"Failed to create profile from plist '%@'", cur);
			return NO;
		}

		VMPInfo(@"Found profile: %@", [profile name]);
		[found addObject:profile];
	}

	VMPInfo(@"Loaded %lu profiles", [found count]);
	_availableProfiles = [NSArray arrayWithArray:found];

	return YES;
}

- (BOOL)_selectBestProfileWithError:(NSError **)error {
	VMP_ASSERT(_availableProfiles, @"availableProfiles property must not be nil!");

	VMPProfileModel *curMax;

	if ([_availableProfiles count] == 0) {
		VMP_FAST_ERROR(error, VMPErrorCodeProfileError, @"No profiles found");
		return NO;
	}

	for (VMPProfileModel *p in _availableProfiles) {
		NSInteger curMaxScore;
		NSInteger selScore;

		selScore = [p compatiblityScoreForPlatform:_runtimePlatform];
		// Profile incompatible with runtime platform
		if (selScore == -1)
			continue;

		if (!curMax) {
			curMax = p;
			continue;
		}

		curMaxScore = [curMax compatiblityScoreForPlatform:_runtimePlatform];

		if (curMaxScore < selScore) {
			VMPDebug(
				@"%@ has score of %ld but %@ has score of %ld for platform %@. Selecting 2nd...",
				[curMax name], curMaxScore, [p name], selScore, _runtimePlatform);
			curMax = p;
		}
	}

	if (!curMax) {
		VMP_FAST_ERROR(error, VMPErrorCodeProfileError, @"No profile found for runtime platform");
		return NO;
	}

	_currentProfile = curMax;

	VMPInfo(@"Selected profile: %@", [_currentProfile name]);
	return YES;
}

@end
