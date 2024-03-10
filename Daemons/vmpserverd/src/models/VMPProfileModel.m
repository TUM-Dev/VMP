/* vmp-server - A virtual multimedia processor
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import "VMPProfileModel.h"
#import "NSString+substituteVariables.h"
#include "VMPConfigChannelModel.h"
#import "VMPErrors.h"
#import "VMPJournal.h"
#import "VMPModelCommon.h"

NSString *const VMPProfilePlatformAll = @"all";
NSString *const VMPProfilePlatformDeepstream6 = @"deepstream6";
NSString *const VMPProfilePlatformVAAPI = @"vaapi";

@implementation VMPProfileModel
- (id)initWithPropertyList:(id)propertyList error:(NSError **)error {
	VMP_ASSERT([propertyList isKindOfClass:[NSDictionary class]],
			   @"propertyList is not a dictionary");

	self = [super init];
	if (self) {
		SET_PROPERTY(_name, @"name");
		SET_PROPERTY(_identifier, @"identifier");
		SET_PROPERTY(_version, @"version");
		SET_PROPERTY(_description, @"description");
		SET_PROPERTY(_supportedPlatforms, @"supportedPlatforms");
		SET_PROPERTY(_mountpoints, @"mountpoints");
		SET_PROPERTY(_audioProviders, @"audioProviders");
		SET_PROPERTY(_channels, @"channels");
		SET_PROPERTY(_recordings, @"recordings");
	}

	return self;
}
- (id)propertyList {
	// Check if all properties are set, to avoid returning a partial property list
	VMP_ASSERT(_name, @"name is nil");
	VMP_ASSERT(_identifier, @"identifier is nil");
	VMP_ASSERT(_version, @"version is nil");
	VMP_ASSERT(_description, @"description is nil");
	VMP_ASSERT(_supportedPlatforms, @"supportedPlatforms is nil");
	VMP_ASSERT(_mountpoints, @"mountpoints is nil");
	VMP_ASSERT(_audioProviders, @"audioProviders is nil");
	VMP_ASSERT(_channels, @"channels is nil");
	VMP_ASSERT(_recordings, @"recordings is nil");

	return @{
		@"name" : _name,
		@"identifier" : _identifier,
		@"version" : _version,
		@"description" : _description,
		@"supportedPlatforms" : _supportedPlatforms,
		@"mountpoints" : _mountpoints,
		@"audioProviders" : _audioProviders,
		@"channels" : _channels,
		@"recordings" : _recordings
	};
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

- (NSString *)_pipelineForType:(NSString *)type
			templateDictionary:(NSDictionary<NSString *, NSString *> *)templateDictionary
					 variables:(NSDictionary<NSString *, NSString *> *)variables
						 error:(NSError **)error {
	NSString *pipelineTemplate;
	pipelineTemplate = [templateDictionary objectForKey:type];
	if (!pipelineTemplate) {
		VMP_FAST_ERROR(error, VMPErrorCodeProfileError, @"No pipeline template for type '%@'",
					   type);
		return nil;
	}

	return [pipelineTemplate stringBySubstitutingVariables:variables error:error];
}

- (NSString *)pipelineForChannelType:(NSString *)type
						   variables:(NSDictionary *)variables
							   error:(NSError **)error {
	// Get the pipeline template from audioProviders if the type is audioTest or pulse
	if ([type isEqualToString:VMPConfigChannelTypeAudioTest] ||
		[type isEqualToString:VMPConfigChannelTypePulseAudio]) {
		return [self _pipelineForType:type
				   templateDictionary:_audioProviders
							variables:variables
								error:error];
	}

	return [self _pipelineForType:type
			   templateDictionary:_channels
						variables:variables
							error:error];
}

- (NSString *)pipelineForMountpointType:(NSString *)type
							  variables:(NSDictionary *)variables
								  error:(NSError **)error {
	return [self _pipelineForType:type
			   templateDictionary:_mountpoints
						variables:variables
							error:error];
}

@end