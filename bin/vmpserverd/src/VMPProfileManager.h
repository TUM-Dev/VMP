/* vmpserverd - A virtual multimedia processor
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import <Foundation/Foundation.h>

#import "VMPProfileModel.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Class for managing available profiles
 *
 * Profiles are property lists that specify GStreamer
 * pipeline configurations for mountpoints and
 * channels. They can be optimised for
 * specific platforms, and are scored upon start-up
 * to find the best-matching profile.
 *
 * @see VMPProfileModel
 */
@interface VMPProfileManager : NSObject

@property (readonly) NSString *runtimePlatform;
@property (readonly) VMPProfileModel *currentProfile;
@property (strong) NSArray<VMPProfileModel *> *availableProfiles;

/**
 * @brief Profile manager convenience initialiser with platform auto-detection
 *
 * @param path The path to the profile directory
 * @param error An error pointer
 *
 * This convenience initialiser autodetects the runtimePlatform during
 * initialisation, using a very simple scoring system.
 *
 * The profile directory is the directories of all profile property lists.
 *
 * @returns a profile manager if no configuration error occurred. Otherwise nil
 * with a populated error.
 */
+ (nullable instancetype)managerWithPath:(NSString *)path error:(NSError **)error;

/**
 * @brief Profile manager convenience initialiser without auto-detection
 *
 * @param path The path to the profile directory
 * @param platform The runtime platform (manually specified)
 * @param error An error pointer
 *
 * @returns a profile manager, or nil
 */
+ (nullable instancetype)managerWithPath:(NSString *)path
						 runtimePlatform:(NSString *)runtimePlatform
								   error:(NSError **)error;

/*
 * @brief Profile manager initialiser without auto-detection
 *
 * @param path The path to the profile directory
 * @param platform The runtime platform (manually specified)
 * @param error An error pointer
 *
 * @returns an initialised profile manager, or nil
 */
- (nullable instancetype)initWithPath:(NSString *)path
					  runtimePlatform:(NSString *)runtimePlatform
								error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
