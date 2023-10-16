/* vmp-server - A virtual multimedia processor
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import <Foundation/Foundation.h>

@class VMPProfile;

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

@property (nonatomic, readonly) NSString *runtimePlatform;
@property (nonatomic, readonly) VMPProfile *currentProfile;
@property (nonatomic, strong) NSArray<VMPProfile *> *availableProfiles;

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

/**
	@brief Class holding information about a profile

	Profiles define the GStreamer pipelines for
	mountpoints and channels for an array of supported
	platforms.
*/
@interface VMPProfile : NSObject

/**
	@brief The title of the profile
*/
@property (nonatomic, strong) NSString *title;

/**
	@brief The reverse-domain identifier of the profile
*/
@property (nonatomic, strong) NSString *identifier;

/**
	@brief The version of the profile
*/
@property (nonatomic, strong) NSString *version;

/**
	@brief A human-readable description of the profile
*/
@property (nonatomic, strong) NSString *description;

/**
	@brief An array of supported platforms

	Every profile has a compatibility score which
	is used to select the best profile for the
	current platform.

	Currently, the following platforms are supported:
	- "all" - Most generic profile. Matches with all platforms.
	- "deepstream-6" - Platform supporting Nvidia Deepstream

	Nvidia Deepstream is a multimedia framework that supplies
	GStreamer elements making use of Nvidia technologies,
	including NVENC, NVDEC, and CUDA.
*/
@property (nonatomic, strong) NSArray<NSString *> *supportedPlatforms;

/**
	@brief Pipeline configuration for supported mountpoints

	Currently, the following mountpoints are implemented and
	MUST be supported by a profile:
	- "single" - A single video rtp stream
	- "combined" - A combined video rtp stream with two video inputs

	The following variables are allowed in the pipelines:
	- {VIDEOCHANNEL.%u} - The video channel name. Enumerated with unsigned
	  integers, starting at 0
	- {PADEV} - Pulse Audio (PA) Device for audio pipelines
*/
@property (nonatomic, strong) NSDictionary<NSString *, NSDictionary *> *mountpoints;

/**
	@brief Pipeline configuration for video channels

	The following channel types are implemented and MUST be
	supported by a profile:
	- "v4l2" - Video 4 Linux 2 (V4L2) video device source
	- "videoTest" - Reproducable video test source

	Allowed variables:
	- {V4L2DEV} - V4L2 device path (e.g. /dev/video0)
	- {VIDEOCHANNEL.%u}
*/
@property (nonatomic, strong) NSDictionary<NSString *, NSString *> *channels;

/**
	@brief Load a profile from a plist located at plistPath.

	@param plistPath The path to the profile plist

	@return A initialised VMPProfile object
*/
+ (instancetype)profileWithPlist:(NSString *)plistPath error:(NSError **)error;

- (instancetype)initWithPlist:(NSString *)plistPath error:(NSError **)error;

/**
	@brief Compatiblity score of profile (higher is better)

	@parm platform The platform to calculate the score for

	Profiles have an array of supported platforms.
	If no platform in the array matches with the runtime
	platform, the compatiblity score is -1.

	Otherwise it is a non-negative integer. The optimal
	profile for the runtime platform has the highest score.
*/
- (NSInteger)compatiblityScoreForPlatform:(NSString *)platform;

- (NSString *)parsePipeline:(NSString *)pipeline
					   vars:(NSDictionary<NSString *, NSString *> *)varDict
					  error:(NSError **)error;
@end