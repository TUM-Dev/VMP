/* vmp-server - A virtual multimedia processor
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import "VMPProfile.h"
#import "VMPErrors.h"
#import "VMPJournal.h"
#include <Foundation/NSArray.h>
#include <Foundation/NSFileManager.h>

#define WRITE_ERROR(err, msg)                                                                      \
	if (err) {                                                                                     \
		*err = [NSError errorWithDomain:VMPErrorDomain                                             \
								   code:VMPErrorCodeProfileError                                   \
							   userInfo:@{NSLocalizedDescriptionKey : msg}];                       \
	}

static NSString *deviceTreeModelPath = @"/proc/device-tree/model";

@implementation VMPProfile

+ (instancetype)profileWithPlist:(NSString *)plistPath error:(NSError **)error {
	return [[VMPProfile alloc] initWithPlist:plistPath error:error];
}

- (instancetype)initWithPlist:(NSString *)plistPath error:(NSError **)error {
	VMP_ASSERT(plistPath, @"plistPath cannot be nil")

	self = [super init];
	if (self) {
		NSDictionary *plist = [NSDictionary dictionaryWithContentsOfFile:plistPath];
		if (!plist) {
			if (error) {
				*error = [NSError errorWithDomain:VMPErrorDomain
											 code:VMPErrorCodeProfileError
										 userInfo:nil];
			}
			return nil;
		}

		_title = plist[@"title"];
		_version = plist[@"version"];
		_description = plist[@"description"];
		_identifier = plist[@"identifier"];
		if (!_title || !_version || !_description || !_identifier) {
			WRITE_ERROR(error, @"Not all metadata (title, identifier, version, author) was found "
							   @"in the profile plist");
			return nil;
		}

		_supportedPlatforms = plist[@"supportedPlatforms"];
		if (!_supportedPlatforms) {
			WRITE_ERROR(error, @"Missing key in profile plist: supportedPlatforms");
			return nil;
		}
		_mountpoints = plist[@"mountpoints"];
		if (!_mountpoints) {
			WRITE_ERROR(error, @"Missing key in profile plist: mountpoints");
			return nil;
		}

		_channels = plist[@"channels"];
		if (!_channels) {
			WRITE_ERROR(error, @"Missing key in profile plist: channels");
		}
	}

	return self;
}

- (NSInteger)compatiblityScoreForPlatform:(NSString *)platform {
	NSUInteger length;
	BOOL supportsAll;

	VMP_ASSERT(_supportedPlatforms,
			   @"supportedPlatforms must not be nil when calculating compatibilityScore");

	length = [_supportedPlatforms count];
	supportsAll = NO;

	for (NSString *cur in _supportedPlatforms) {
		if ([cur isEqualToString:platform]) {
			return NSIntegerMax - (NSInteger) length;
		}

		if ([cur isEqualToString:@"all"]) {
			supportsAll = YES;
		}
	}

	if (supportsAll) {
		return 1;
	}

	return -1;
}

- (NSString *)parsePipeline:(NSString *)pipeline
					   vars:(NSDictionary<NSString *, NSString *> *)varDict
					  error:(NSError **)error {
	return nil;
}

@end

// Declare runtimePlatform and currentProfile rw for internal use
@interface VMPProfileManager ()

@property (nonatomic, readwrite) NSString *runtimePlatform;
@property (nonatomic, readwrite) VMPProfile *currentProfile;

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
									  runtimePlatform:@"deepstream-6"
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
	NSMutableArray<VMPProfile *> *found;

	mgr = [NSFileManager defaultManager];
	contents = [mgr contentsOfDirectoryAtPath:path error:error];
	if (!contents) {
		return NO;
	}
	found = [NSMutableArray arrayWithCapacity:[contents count]];

	VMPProfile *pf;
	for (NSString *cur in contents) {
		if ([mgr isReadableFileAtPath:cur]) {
			pf = [VMPProfile profileWithPlist:cur error:error];
			if (!pf) {
				return NO;
			}

			VMPDebug(@"Found profile: %@", [pf title]);
			[found addObject:pf];
		}
	}

	VMPDebug(@"Loaded %lu profiles", [found count]);
	_availableProfiles = [NSArray arrayWithArray:found];

	return YES;
}

- (BOOL)_selectBestProfileWithError:(NSError **)error {
	VMP_ASSERT(_availableProfiles, @"availableProfiles property must not be nil!");

	VMPProfile *curMax;

	if ([_availableProfiles count] == 0) {
		WRITE_ERROR(error, @"No profiles found");
		return NO;
	}

	for (VMPProfile *p in _availableProfiles) {
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
				[curMax title], curMaxScore, [p title], selScore, _runtimePlatform);
			curMax = p;
		}
	}

	if (!curMax) {
		WRITE_ERROR(error, @"No profile found for runtime platform");
		return NO;
	}

	return YES;
}

@end