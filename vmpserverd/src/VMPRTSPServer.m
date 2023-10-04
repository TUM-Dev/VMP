/* vmp-server - A virtual multimedia processor
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import <glib.h>
#import <gst/rtsp-server/rtsp-server.h>

#import "VMPJournal.h"
#import "VMPRTSPServer.h"

// Combined stream
//#import "VMPGMediaFactory.h"
#import "VMPGVideoConfig.h"

// Generated project configuration
#include "../build/config.h"

#define CONFIG_ERROR(error, description)                                                                               \
	VMPError(description);                                                                                             \
	if (error) {                                                                                                       \
		NSDictionary *userInfo = @{NSLocalizedDescriptionKey : description};                                           \
		*error = [NSError errorWithDomain:VMPErrorDomain code:VMPErrorCodeConfigurationError userInfo:userInfo];       \
	}

#ifdef NV_JETSON
// TODO: Make explicit width and height argument configurable. As we only need to set this explicitly for the Jetson, we
// need to preformat the launch string.
#define LAUNCH_VIDEO                                                                                                   \
	@"intervideosrc channel=%@ ! queue ! nvvidconv ! video/x-raw(memory:NVMM), width=(int)1920, height=(int)1080 ! "   \
	@"nvv4l2h264enc maxperf-enable=1 bitrate=2500000 ! rtph264pay name=pay0 pt=96"
#else
#define LAUNCH_VIDEO                                                                                                   \
	@"intervideosrc channel=%@ ! video/x-raw, width=(int)1920, height=(int)1080 ! queue ! videoconvert ! x264enc bitrate=2500000 ! "   \
	@"rtph264pay name=pay0 pt=96"
#endif

#define LAUNCH_COMB \
	@"nvcompositor name=comp "          \
	@"sink_0::xpos=0 sink_0::ypos=0 sink_0::width=1440 sink_0::height=810 " \
	@"sink_1::xpos=1440 sink_1::ypos=0 sink_1::width=480 sink_1::height=270 ! " \
	@"video/x-raw(memory:NVMM),width=1920,height=1080 ! nvvidconv ! " \
	@"nvv4l2h264enc maxperf-enable=1 bitrate=2500000 ! rtph264pay name=pay0 pt=96 " \
	@"intervideosrc channel=%@ ! nvvidconv ! comp.sink_0 " \
	@"intervideosrc channel=%@ ! nvvidconv ! comp.sink_1 "

/* We added an audioresample element audioresample element to ensure that any input audio is resampled to match the
 * output rate properly, which is essential for maintaining AV sync and good quality over the RTSP stream.
 *
 * NOTE: This needs to be tested, and removed it produces to much overhead.
 *
 * We encode the audio stream into AAC-LC (default profile of avenc_aac) with a bitrate of 128kbps, which should be
 * enough for our use case.
 */
#define LAUNCH_AUDIO                                                                                                   \
	@"interaudiosrc channel=%@ ! voaacenc bitrate=96000 ! rtpmp4apay "        \
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
	VMP_ASSERT(configuration, @"Configuration cannot be nil");
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

// FIXME: This is bad. We should not have multiple pipelines with the same delegate
#pragma mark - VMPPipelineManagerDelegate

- (void)onStateChanged:(NSString *)state {
	VMPInfo(@"Pipeline state changed: %@", state);
}

#pragma mark - Private methods

// Iterate over the channelConfiguration array, create all pipeline managers acordingly, and start them.
- (BOOL)_startChannelPipelinesWithError:(NSError **)error {
	VMPDebug(@"Starting channel pipelines");

	NSArray *channelConfiguration = [_configuration channelConfiguration];

	// TODO: Too much duplication here
	for (NSDictionary *conf in channelConfiguration) {
		NSString *channelType = conf[kVMPServerChannelTypeKey];
		NSString *channelName = conf[kVMPServerChannelNameKey];

		if (!channelType || !channelName) {
			CONFIG_ERROR(error, @"Channel configuration is missing required keys name or type")
			return NO;
		}

		VMPInfo(@"Starting channel %@ of type %@", channelName, channelType);

		NSDictionary *channelProperties = conf[kVMPServerChannelPropertiesKey];
		if (!channelProperties) {
			CONFIG_ERROR(error, @"Channel configuration is missing properties")
			return NO;
		}

		VMPDebug(@"Channel properties: %@", channelProperties);

		if ([channelType isEqualToString:kVMPServerChannelTypeV4L2]) {
			NSString *device = channelProperties[@"device"];
			if (!device) {
				CONFIG_ERROR(error, @"V4L2 channel is missing device property")
				return NO;
			}

			VMPInfo(@"Creating V4L2 pipeline manager for device %@", device);

			VMPV4L2PipelineManager *manager = [VMPV4L2PipelineManager managerWithDevice:device
																				channel:channelName
																			   Delegate:self];
			if (![manager start]) {
				// TODO: Get information out of manager
				CONFIG_ERROR(error, @"Failed to start V4L2 pipeline")
				return NO;
			}

			VMPInfo(@"V4L2 pipeline for channel %@ started successfully", channelName);

			[_managedPipelines addObject:manager];
		} else if ([channelType isEqualToString:kVMPServerChannelTypeALSA]) {
			NSString *device = channelProperties[@"device"];
			if (!device) {
				CONFIG_ERROR(error, @"ALSA channel is missing device property") return NO;
			}

			VMPInfo(@"Creating ALSA pipeline manager for device %@", device);

			VMPALSAPipelineManager *manager = [VMPALSAPipelineManager managerWithDevice:device
																				channel:channelName
																			   Delegate:self];

			if (![manager start]) {
				// TODO: Get information out of manager
				CONFIG_ERROR(error, @"Failed to start ALSA pipeline")
				return NO;
			}

			VMPInfo(@"ALSA pipeline for channel %@ started successfully", channelName);

			[_managedPipelines addObject:manager];
		} else if ([channelType isEqualToString:kVMPServerChannelTypeVideoTest]) {
			NSString *launchArgs;
			NSNumber *width = channelProperties[@"width"];
			NSNumber *height = channelProperties[@"height"];

			if (!width || !height) {
				CONFIG_ERROR(error, @"Video test channel is missing width or height property")
				return NO;
			}

			VMPInfo(@"Creating video test pipeline manager with width %@ and height %@", width, height);
			launchArgs =
				[NSString stringWithFormat:@"videotestsrc is-live=1 ! video/x-raw,width=%lu,height=%lu ! "
										   @"queue ! intervideosink channel=%@",
										   [width unsignedLongValue], [height unsignedLongValue], channelName];

			VMPDebug(@"Creating pipeline manager with launch arguments: %@", launchArgs);

			VMPPipelineManager *manager = [VMPPipelineManager managerWithLaunchArgs:launchArgs
																			Channel:channelName
																		   Delegate:self];
			if (![manager start]) {
				// TODO: Get information out of manager
				CONFIG_ERROR(error, @"Failed to start video test pipeline")
				return NO;
			}

			VMPInfo(@"Video test pipeline for channel %@ started successfully", channelName);

			[_managedPipelines addObject:manager];
		} else if ([channelType isEqualToString:kVMPServerChannelTypeAudioTest]) {
			NSString *launchArgs;

			VMPInfo(@"Creating audio test pipeline manager");

			launchArgs = [NSString stringWithFormat:@"audiotestsrc is-live=1 ! capsfilter "
													@"caps=audio/x-raw,format=S16LE,layout=interleaved,channels=2 ! "
													@"queue ! interaudiosink channel=%@",
													channelName];
			VMPDebug(@"Creating pipeline manager with launch arguments: %@", launchArgs);
			VMPPipelineManager *manager = [VMPPipelineManager managerWithLaunchArgs:launchArgs
																			Channel:channelName
																		   Delegate:self];

			if (![manager start]) {
				// TODO: Get information out of manager
				CONFIG_ERROR(error, @"Failed to start audio test pipeline")
				return NO;
			}

			VMPInfo(@"Audio test pipeline for channel %@ started successfully", channelName);

			[_managedPipelines addObject:manager];
		} else if ([channelType isEqualToString:kVMPServerChannelTypeCustom]) {
			NSString *launchArgs = channelProperties[@"gstLaunchDescription"];
			if (!launchArgs) {
				CONFIG_ERROR(error, @"Custom channel is missing gstLaunchDescription property")
				return NO;
			}

			VMPInfo(@"Creating custom pipeline manager with launch arguments: %@", launchArgs);

			VMPPipelineManager *manager = [VMPPipelineManager managerWithLaunchArgs:launchArgs
																			Channel:channelName
																		   Delegate:self];
			if (![manager start]) {
				CONFIG_ERROR(error, @"Failed to start custom pipeline")
				return NO;
			}
		} else {
			CONFIG_ERROR(error, @"Unknown channel type")
			return NO;
		}
	}

	VMPDebug(@"Finished starting channel pipelines");
	return YES;
}

- (BOOL)_createMountpointsWithError:(NSError **)error {
	VMPDebug(@"Creating mountpoints");
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
			
			GstRTSPMediaFactory *factory;
			NSString *launchCommand;

			factory = gst_rtsp_media_factory_new();
			// Only create one pipeline and share it with other clients
			gst_rtsp_media_factory_set_shared(factory, TRUE);

			launchCommand = [NSString stringWithFormat:LAUNCH_COMB, videoChannel, secondaryVideoChannel];

			VMPDebug(@"Creating combined mountpoint with launch command: %@", launchCommand);

			gst_rtsp_media_factory_set_launch(factory, (const gchar *) [launchCommand UTF8String]);
			gst_rtsp_mount_points_add_factory(_mountPoints, (const gchar *) [path UTF8String], factory);

			/*
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
			*/
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

	VMPDebug(@"Finished creating mountpoints");
	return YES;
}

- (BOOL)startWithError:(NSError **)error {
	VMPInfo(@"Starting RTSP server...");
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

	VMPInfo(@"RTSP server listening on address '%@' on port '%@'", [_configuration rtspAddress],
			[_configuration rtspPort]);

	return YES;
}

- (void)dealloc {
	g_object_unref(_mountPoints);
	g_object_unref(_server);
}

@end