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

#define CONFIG_ERROR(error, description)                                                                               \
	NSLog(@"Configuration error: %@", description);                                                                    \
	if (error) {                                                                                                       \
		NSDictionary *userInfo = @{NSLocalizedDescriptionKey : description};                                           \
		*error = [NSError errorWithDomain:VMPErrorDomain code:VMPErrorCodeConfigurationError userInfo:userInfo];       \
	}

#ifdef NV_JETSON
// TODO: Make explicit width and height argument configurable. As we only need to set this explicitly for the Jetson, we
// need to preformat the launch string.
#define LAUNCH_VIDEO                                                                                                   \
	@"intervideosrc channel=%@ ! queue ! nvvidconv ! video/x-raw(memory:NVMM), width=(int)1920, height=(int)1080 ! "   \
	@"nvv4l2h264enc maxperf-enable=1 bitrate=5000000 ! rtph264pay name=pay0 pt=96"
#else
#define LAUNCH_VIDEO @"intervideosrc channel=%@ ! queue ! videoconvert ! x264enc ! rtph264pay name=pay0 pt=96"
#endif

/* We added an audioresample element audioresample element to ensure that any input audio is resampled to match the
 * output rate properly, which is essential for maintaining AV sync and good quality over the RTSP stream.
 *
 * NOTE: This needs to be tested, and removed it produces to much overhead.
 *
 * We encode the audio stream into AAC-LC (default profile of avenc_aac) with a bitrate of 128kbps, which should be
 * enough for our use case.
 */
#define LAUNCH_AUDIO                                                                                                   \
	@"interaudiosrc channel=%@ ! queue ! audioconvert ! audioresample ! avenc_aac bitrate=128000 ! rtpmp4apay "        \
	@"name=pay1 pt=97"

// Combine the video and audio launch strings (separated by a space)
#define LAUNCH_COMBINED LAUNCH_VIDEO @" " LAUNCH_AUDIO

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
			CONFIG_ERROR(error, @"Channel configuration is missing required keys name or type")
			return NO;
		}

		NSLog(@"Starting channel %@ of type %@", channelName, channelType);

		NSDictionary *channelProperties = conf[kVMPServerChannelPropertiesKey];
		if (!channelProperties) {
			CONFIG_ERROR(error, @"Channel configuration is missing properties")
			return NO;
		}

		NSDebugLog(@"Channel properties: %@", channelProperties);

		if ([channelType isEqualToString:kVMPServerChannelTypeV4L2]) {
			NSString *device = channelProperties[@"device"];
			if (!device) {
				CONFIG_ERROR(error, @"V4L2 channel is missing device property")
				return NO;
			}

			NSLog(@"Creating V4L2 pipeline manager for device %@", device);

			VMPV4L2PipelineManager *manager = [VMPV4L2PipelineManager managerWithDevice:device
																				channel:channelName
																			   Delegate:self];
			if (![manager start]) {
				// TODO: Get information out of manager
				CONFIG_ERROR(error, @"Failed to start V4L2 pipeline")
				return NO;
			}

			[_managedPipelines addObject:manager];
		} else if ([channelType isEqualToString:kVMPServerChannelTypeALSA]) {
			NSString *device = channelProperties[@"device"];
			if (!device) {
				CONFIG_ERROR(error, @"ALSA channel is missing device property") return NO;
			}

			NSLog(@"Creating ALSA pipeline manager for device %@", device);

			VMPALSAPipelineManager *manager = [VMPALSAPipelineManager managerWithDevice:device
																				channel:channelName
																			   Delegate:self];

			if (![manager start]) {
				// TODO: Get information out of manager
				CONFIG_ERROR(error, @"Failed to start ALSA pipeline")
				return NO;
			}

			[_managedPipelines addObject:manager];
		} else if ([channelType isEqualToString:kVMPServerChannelTypeVideoTest]) {
			CONFIG_ERROR(error, @"Video test channel not implemented")
			return NO;
		} else if ([channelType isEqualToString:kVMPServerChannelTypeAudioTest]) {
			CONFIG_ERROR(error, @"Audio test channel not implemented")
			return NO;
		} else {
			CONFIG_ERROR(error, @"Unknown channel type")
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
			CONFIG_ERROR(error, @"Mountpoint configuration is missing required keys")
			return NO;
		}

		if (!videoChannel && !audioChannel) {
			CONFIG_ERROR(error, @"Mountpoint configuration requires a video or audio channel")
			return NO;
		}

		if ([type isEqualToString:kVMPServerMountpointTypeCombined]) {
			NSString *secondaryVideoChannel = mountpoint[kVMPServerMountpointSecondaryVideoChannelKey];
			if (!secondaryVideoChannel) {
				CONFIG_ERROR(error, @"Combined mountpoint requires a secondary video channel")
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
			GstRTSPMediaFactory *factory;
			NSString *launchCommand;

			factory = gst_rtsp_media_factory_new();
			// Only create one pipeline and share it with other clients
			gst_rtsp_media_factory_set_shared(factory, TRUE);

			if (!videoChannel) { // Audio-only channel
				launchCommand = [NSString stringWithFormat:LAUNCH_AUDIO, audioChannel];

			} else if (!audioChannel) { // Video-only channel
				launchCommand = [NSString stringWithFormat:LAUNCH_VIDEO, videoChannel];
			} else { // audio and video channel
				launchCommand = [NSString stringWithFormat:LAUNCH_COMBINED, videoChannel, audioChannel];
			}

			gst_rtsp_media_factory_set_launch(factory, (const gchar *) [launchCommand UTF8String]);

			gst_rtsp_mount_points_add_factory(_mountPoints, (const gchar *) [path UTF8String], factory);
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

	NSLog(@"RTSP server listening on address '%@' on port '%@'", [_configuration rtspAddress],
		  [_configuration rtspPort]);

	return YES;
}

- (void)dealloc {
	g_object_unref(_mountPoints);
	g_object_unref(_server);
}

@end