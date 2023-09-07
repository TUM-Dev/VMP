/* vmp-server - A virtual multimedia processor
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import <glib.h>
#import <gst/rtsp-server/rtsp-server.h>

#import "VMPRTSPServer.h"

// Combined stream
#import "VMPGMediaFactory.h"
#import "VMPGVideoConfig.h"

#define POPULATE_ERROR(error, description)                                                                             \
	if (error) {                                                                                                       \
		NSDictionary *userInfo = @{NSLocalizedDescriptionKey : description};                                           \
		*error = [NSError errorWithDomain:VMPErrorDomain code:VMPErrorCodeConfigurationError userInfo:userInfo];       \
	}

@implementation VMPRTSPServer {
	GstRTSPServer *_server;
	GstRTSPMountPoints *_mountPoints;

	NSMutableArray<VMPPipelineManager *> *_managedPipelines;
}
+ (instancetype)serverWithConfiguration:(VMPServerConfiguration *)configuration {
	return [[VMPRTSPServer alloc] initWithConfiguration:configuration];
}

- (instancetype)initWithConfiguration:(VMPServerConfiguration *)configuration {
	NSAssert(configuration, @"Configuration cannot be nil");
	self = [super init];
	if (self) {
		_configuration = configuration;
		_server = gst_rtsp_server_new();
		_mountPoints = gst_rtsp_server_get_mount_points(_server);

		NSUInteger channelCount = [[_configuration channelConfiguration] count];
		_managedPipelines = [NSMutableArray arrayWithCapacity:channelCount];

		g_object_set(_server, "service", (const gchar *) [[_configuration rtspPort] UTF8String], NULL);
		g_object_set(_server, "address", (const gchar *) [[_configuration rtspAddress] UTF8String], NULL);
	}
	return self;
}

#pragma mark - VMPPipelineManagerDelegate

- (void)onStateChanged:(NSString *)state {
	NSLog(@"Pipeline state changed: %@", state);
}

#pragma mark - Private methods

// Iterate over the channelConfiguration array, create all pipeline managers acordingly, and start them.
- (BOOL)_startChannelPipelinesWithError:(NSError **)error {
	NSArray *channelConfiguration = [_configuration channelConfiguration];

	for (NSDictionary *conf in channelConfiguration) {
		NSString *channelType = conf[kVMPServerChannelTypeKey];
		NSString *channelName = conf[kVMPServerChannelNameKey];

		if (!channelType || !channelName) {
			POPULATE_ERROR(error, @"Channel configuration is missing required keys name or type")
			return NO;
		}

		NSLog(@"Starting channel %@ of type %@", channelName, channelType);

		NSDictionary *channelProperties = conf[kVMPServerChannelPropertiesKey];
		if (!channelProperties) {
			POPULATE_ERROR(error, @"Channel configuration is missing properties")
			return NO;
		}

		NSDebugLog(@"Channel properties: %@", channelProperties);

		if ([channelType isEqualToString:kVMPServerChannelTypeV4L2]) {
			NSString *device = channelProperties[@"device"];
			if (!device) {
				POPULATE_ERROR(error, @"V4L2 channel is missing device property")
				return NO;
			}

			NSLog(@"Creating V4L2 pipeline manager for device %@", device);

			VMPV4L2PipelineManager *manager = [VMPV4L2PipelineManager managerWithDevice:device
																				channel:channelName
																			   Delegate:self];
			if (![manager start]) {
				// TODO: Get information out of manager
				POPULATE_ERROR(error, @"Failed to start V4L2 pipeline")
				return NO;
			}

			[_managedPipelines addObject:manager];
		} else if ([channelType isEqualToString:kVMPServerChannelTypeALSA]) {
			NSString *device = channelProperties[@"device"];
			if (!device) {
				POPULATE_ERROR(error, @"ALSA channel is missing device property") return NO;
			}

			NSLog(@"Creating ALSA pipeline manager for device %@", device);

			VMPALSAPipelineManager *manager = [VMPALSAPipelineManager managerWithDevice:device
																				channel:channelName
																			   Delegate:self];

			if (![manager start]) {
				// TODO: Get information out of manager
				POPULATE_ERROR(error, @"Failed to start ALSA pipeline")
				return NO;
			}

			[_managedPipelines addObject:manager];
		} else if ([channelType isEqualToString:kVMPServerChannelTypeVideoTest]) {
			POPULATE_ERROR(error, @"Video test channel not implemented")
			return NO;
		} else if ([channelType isEqualToString:kVMPServerChannelTypeAudioTest]) {
			POPULATE_ERROR(error, @"Audio test channel not implemented")
			return NO;
		} else {
			POPULATE_ERROR(error, @"Unknown channel type")
			return NO;
		}
	}
	return YES;
}

- (BOOL)_createMountpointsWithError:(NSError **)error {
	NSArray *mountpoints = [_configuration rtspMountpoints];
	for (NSDictionary *mountpoint in mountpoints) {
		NSString *path = mountpoint[kVMPServerMountPointsPathKey];
		NSString *type = mountpoint[kVMPServerMountPointsTypeKey];
		NSString *videoChannel = mountpoint[kVMPServerMountpointVideoChannelKey];
		NSString *audioChannel = mountpoint[kVMPServerMountpointAudioChannelKey];

		if (!path || !type) {
			POPULATE_ERROR(error, @"Mountpoint configuration is missing required keys")
			return NO;
		}

		if (!videoChannel && !audioChannel) {
			POPULATE_ERROR(error, @"Mountpoint configuration requires a video or audio channel")
			return NO;
		}

		if ([type isEqualToString:kVMPServerMountpointTypeCombined]) {
			NSString *secondaryVideoChannel = mountpoint[kVMPServerMountpointSecondaryVideoChannelKey];
			if (!secondaryVideoChannel) {
				POPULATE_ERROR(error, @"Combined mountpoint requires a secondary video channel")
				return NO;
			}

			VMPMediaFactory *factory;
			VMPVideoConfig *camera_config;
			VMPVideoConfig *presentation_config;
			VMPVideoConfig *output_config;
			const gchar *camera_channel;
			const gchar *presentation_channel;
			const gchar *audio_channel;

			// TODO: We should probably get these from the configuration
			camera_config = vmp_video_config_new(480, 270);
			presentation_config = vmp_video_config_new(1440, 810);
			output_config = vmp_video_config_new(1920, 1080);

			camera_channel = (const gchar *) [secondaryVideoChannel UTF8String];
			presentation_channel = (const gchar *) [videoChannel UTF8String];
			audio_channel = (const gchar *) [audioChannel UTF8String];

			// Initialise the custom rtsp media factory for managing our own pipeline
			factory = vmp_media_factory_new(camera_channel, presentation_channel, audio_channel, output_config,
											camera_config, presentation_config);
			// Set the shared property to true, so that the pipeline is shared between clients
			gst_rtsp_media_factory_set_shared(GST_RTSP_MEDIA_FACTORY(factory), TRUE);

			gst_rtsp_mount_points_add_factory(_mountPoints, (const gchar *) [path UTF8String],
											  GST_RTSP_MEDIA_FACTORY(factory));

			// Full transfer to VMPMediaFactory
			g_object_unref(camera_config);
			g_object_unref(presentation_config);
			g_object_unref(output_config);
		} else if ([type isEqualToString:kVMPServerMountpointTypeSingle]) {
			POPULATE_ERROR(error, @"Single mountpoint not implemented")
			return NO;
		}
	}

	return YES;
}

- (BOOL)startWithError:(NSError **)error {
	// Create and start all (ingress) pipelines
	if (![self _startChannelPipelinesWithError:error]) {
		return NO;
	}

	// Create all mountpoints
	if (![self _createMountpointsWithError:error]) {
		return NO;
	}

	// Start the RTSP server
	gst_rtsp_server_attach(_server, NULL);

	return YES;
}

- (void)dealloc {
	g_object_unref(_mountPoints);
	g_object_unref(_server);
}

@end