/* vmpserverd - A virtual multimedia processor
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import <Foundation/Foundation.h>

#import "VMPPropertyListProtocol.h"

/// Generic platform
extern NSString *const VMPProfilePlatformAll;
/// Nvidia Deepstream 6
extern NSString *const VMPProfilePlatformDeepstream6;
// VAAPI
extern NSString *const VMPProfilePlatformVAAPI;

/**
	@brief Class holding information about a profile

	Profiles define the GStreamer pipelines for
	mountpoints and channels for an array of supported
	platforms.
*/
@interface VMPProfileModel : NSObject <VMPPropertyListProtocol>

/**
	@brief The name of the profile
*/
@property (nonatomic, strong) NSString *name;

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
	- "vaapi" - Platform with vaapi support

	Nvidia Deepstream is a multimedia framework that supplies
	GStreamer elements making use of Nvidia technologies,
	including NVENC, NVDEC, and CUDA.
*/
@property (nonatomic, strong) NSArray<NSString *> *supportedPlatforms;

@property (nonatomic, strong) NSDictionary<NSString *, NSString *> *mountpoints;

@property (nonatomic, strong) NSDictionary<NSString *, NSString *> *audioProviders;

@property (nonatomic, strong) NSDictionary<NSString *, NSString *> *channels;

@property (nonatomic, strong) NSDictionary<NSString *, NSString *> *recordings;

/**
	@brief Load a profile from a propertyList representation.

	@param propertyList The property list representation
	@param error Error pointer

	@return A initialised VMPProfileModel object
*/
- (id)initWithPropertyList:(id)propertyList error:(NSError **)error;

/**
	@brief Convert the profile to a propertyList representation
*/
- (id)propertyList;

/**
	@brief Compatiblity score of profile (higher is better)

	@param platform The platform to calculate the score for

	Profiles have an array of supported platforms.
	If no platform in the array matches with the runtime
	platform, the compatiblity score is -1.

	Otherwise it is a non-negative integer. The optimal
	profile for the runtime platform has the highest score.
*/
- (NSInteger)compatiblityScoreForPlatform:(NSString *)platform;

/**
	@brief Process a pipeline template for a channel

	@param type The type of the channel
	@param variables A dictionary of variables to replace in the template
	@param error Error pointer

	@discussion This method processes a pipeline template with a substitution
	dictionary of variables. The variables are replaced in the template, and
	the resulting pipeline is returned.

	@return A GStreamer pipeline description
*/
- (NSString *)pipelineForChannelType:(NSString *)type
						   variables:(NSDictionary *)variables
							   error:(NSError **)error;

/**
	@brief Process a pipeline template for a mountpoint

	@param type The type of the mountpoint
	@param variables A dictionary of variables to replace in the template
	@param error Error pointer

	@discussion Similar to pipelineForChannelType:variables:error:, but for
	mountpoints.

	@return A GStreamer pipeline description
*/
- (NSString *)pipelineForMountpointType:(NSString *)type
							  variables:(NSDictionary *)variables
								  error:(NSError **)error;

@end
