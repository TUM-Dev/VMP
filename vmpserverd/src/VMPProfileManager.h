/* vmp-server - A virtual multimedia processor
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import <Foundation/Foundation.h>

#import "VMPProfileModel.h"

/**
	@brief Class for managing available profiles

	Profiles are plist files that specify GStreamer
	pipeline configurations for mountpoints and
	video channels. They can be optimised for
	specific platforms, and are scored upon start-up
	to find the best-matching profile.

	@see VMPProfile
*/
@interface VMPProfileManager : NSObject

@property (readonly) NSString *runtimePlatform;
@property (readonly) VMPProfileModel *currentProfile;
@property (strong) NSArray<VMPProfileModel *> *availableProfiles;

/**
	@brief Autodetects the runtimePlatform during initialisation

	@param path The path to the profile directory
	@param error An error pointer
*/
+ (instancetype)managerWithPath:(NSString *)path error:(NSError **)error;

+ (instancetype)managerWithPath:(NSString *)path
				runtimePlatform:(NSString *)platform
						  error:(NSError **)error;

- (instancetype)initWithPath:(NSString *)path
			 runtimePlatform:(NSString *)platform
					   error:(NSError **)error;

@end