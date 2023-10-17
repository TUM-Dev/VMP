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

// Declare runtimePlatform and currentProfile rw for internal use
@interface VMPProfileManager ()

@property (nonatomic, readwrite) NSString *runtimePlatform;
@property (nonatomic, readwrite) VMPProfileModel *currentProfile;

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

		if ([model containsString:@"NVIDIA Jetson"]) {
			return [VMPProfileManager managerWithPath:path
									  runtimePlatform:VMPProfilePlatformDeepstream6
												error:error];
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
		return NO;
	}
	found = [NSMutableArray arrayWithCapacity:[contents count]];

	VMPProfileModel *profile;
	for (NSString *cur in contents) {
		if ([mgr isReadableFileAtPath:cur]) {
			NSDictionary *propertyList;

			propertyList = [NSDictionary dictionaryWithContentsOfFile:cur];
			if (!propertyList) {
				VMP_FAST_ERROR(error, VMPErrorCodePropertyListError,
							   @"Failed to read plist at path '%@'", cur);
				return NO;
			}

			// Create profile object from property list representation
			profile = [[VMPProfileModel alloc] initWithPropertyList:propertyList error:error];
			if (!profile) {
				return NO;
			}

			VMPDebug(@"Found profile: %@", [profile name]);
			[found addObject:profile];
		}
	}

	VMPDebug(@"Loaded %lu profiles", [found count]);
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

	return YES;
}

@end