/* vmp-server - A virtual multimedia processor
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import <glib.h>
#import <gst/rtsp-server/rtsp-server.h>

#import "NSString+substituteVariables.h"

#import "VMPConfigChannelModel.h"
#import "VMPConfigModel.h"
#import "VMPConfigMountpointModel.h"

#import "VMPJournal.h"
#import "VMPRTSPServer.h"

// Generated project configuration
#include "../build/config.h"

#define CONFIG_ERROR(error, description)                                                           \
	VMPError(description);                                                                         \
	if (error) {                                                                                   \
		NSDictionary *userInfo = @{NSLocalizedDescriptionKey : description};                       \
		*error = [NSError errorWithDomain:VMPErrorDomain                                           \
									 code:VMPErrorCodeConfigurationError                           \
								 userInfo:userInfo];                                               \
	}

#ifdef NV_JETSON
// TODO: Make explicit width and height argument configurable. As we only need to set this
// explicitly for the Jetson, we need to preformat the launch string.
#define LAUNCH_VIDEO                                                                               \
	@"intervideosrc channel=%@ ! queue ! nvvidconv ! video/x-raw(memory:NVMM), width=(int)1920, "  \
	@"height=(int)1080 ! "                                                                         \
	@"nvv4l2h264enc maxperf-enable=1 bitrate=2500000 ! rtph264pay name=pay0 pt=96"
#else
// x264enc uses kbit/s not bit/s
#define LAUNCH_VIDEO                                                                               \
	@"intervideosrc channel=%@ ! video/x-raw, width=(int)1920, height=(int)1080 ! queue ! "        \
	@"videoconvert ! x264enc "                                                                     \
	@"bitrate=2500 ! "                                                                             \
	@"rtph264pay name=pay0 pt=96"
#endif

#define LAUNCH_COMB                                                                                \
	@"nvcompositor name=comp "                                                                     \
	@"sink_0::xpos=0 sink_0::ypos=0 sink_0::width=1440 sink_0::height=810 "                        \
	@"sink_1::xpos=1440 sink_1::ypos=0 sink_1::width=480 sink_1::height=270 ! "                    \
	@"video/x-raw(memory:NVMM),width=1920,height=1080 ! nvvidconv ! "                              \
	@"nvv4l2h264enc maxperf-enable=1 bitrate=2500000 ! rtph264pay name=pay0 pt=96 "                \
	@"intervideosrc channel=%@ ! nvvidconv ! comp.sink_0 "                                         \
	@"intervideosrc channel=%@ ! nvvidconv ! comp.sink_1 "

/* We added an audioresample element audioresample element to ensure that any input audio is
 * resampled to match the output rate properly, which is essential for maintaining AV sync and good
 * quality over the RTSP stream.
 *
 * NOTE: This needs to be tested, and removed it produces to much overhead.
 *
 * We encode the audio stream into AAC-LC (default profile of avenc_aac) with a bitrate of 128kbps,
 * which should be enough for our use case.
 */
#define LAUNCH_AUDIO                                                                               \
	@"interaudiosrc channel=%@ ! voaacenc bitrate=96000 ! rtpmp4apay "                             \
	@"name=pay1 pt=97"

// Combine the video and audio launch strings (separated by a space)
#define LAUNCH_COMBINED LAUNCH_VIDEO @" " LAUNCH_AUDIO

// Redeclare properties as readwrite
@interface VMPRTSPServer ()
@property (nonatomic, readwrite) VMPProfileModel *currentProfile;
@end

@implementation VMPRTSPServer {
	GstRTSPServer *_server;
	GstRTSPMountPoints *_mountPoints;

	NSMutableArray<VMPPipelineManager *> *_managedPipelines;
}
+ (instancetype)serverWithConfiguration:(VMPConfigModel *)configuration
								profile:(VMPProfileModel *)profile {
	return [[VMPRTSPServer alloc] initWithConfiguration:configuration profile:profile];
}

- (instancetype)initWithConfiguration:(VMPConfigModel *)configuration
							  profile:(VMPProfileModel *)profile {
	VMP_ASSERT(configuration, @"Configuration cannot be nil");
	VMP_ASSERT(profile, @"Profile cannot be nil");

	self = [super init];
	if (self) {
		_configuration = configuration;
		_server = gst_rtsp_server_new();
		_mountPoints = gst_rtsp_server_get_mount_points(_server);
		_currentProfile = profile;

		NSUInteger channelCount = [[_configuration channels] count];
		_managedPipelines = [NSMutableArray arrayWithCapacity:channelCount];

		g_object_set(_server, "service", (const gchar *) [[_configuration rtspPort] UTF8String],
					 NULL);
		g_object_set(_server, "address", (const gchar *) [[_configuration rtspAddress] UTF8String],
					 NULL);
	}
	return self;
}

// FIXME: This is bad. We should not have multiple pipelines with the same delegate
#pragma mark - VMPPipelineManagerDelegate

- (void)onStateChanged:(NSString *)state {
	VMPInfo(@"Pipeline state changed: %@", state);
}

#pragma mark - Private methods

// Iterate over the channelConfiguration array, create all pipeline managers acordingly, and start
// them.
- (BOOL)_startChannelPipelinesWithError:(NSError **)error {
	NSArray *channels;
	VMPInfo(@"Starting channel pipelines");

	channels = [_configuration channels];

	for (VMPConfigChannelModel *channel in channels) {
		NSString *type, *name;
		NSDictionary<NSString *, id> *properties;

		type = [channel type];
		name = [channel name];
		properties = [channel properties];
		VMPInfo(@"Starting channel %@ of type %@", name, type);

		if ([type isEqualToString:VMPConfigChannelTypeV4L2]) {
			NSString *device, *pipeline;
			NSDictionary *vars;
			VMPPipelineManager *manager;

			device = properties[@"device"];
			if (!device) {
				CONFIG_ERROR(error, @"V4L2 channel is missing 'device' property")
				return NO;
			}

			vars = @{@"V4L2DEV" : device, @"VIDEOCHANNEL.0" : name};

			pipeline = [_currentProfile pipelineForChannelType:type variables:vars error:error];
			if (!pipeline) {
				return NO;
			}

			manager = [VMPPipelineManager managerWithLaunchArgs:pipeline
														channel:name
													   delegate:self];
			if (![manager start]) {
				CONFIG_ERROR(error, @"Failed to start V4L2 pipeline")
				return NO;
			}

			[_managedPipelines addObject:manager];

			VMPInfo(@"V4L2 pipeline for channel %@ started successfully", name);
		} else if ([type isEqualToString:VMPConfigChannelTypeVideoTest]) {
			NSNumber *width, *height;
			NSString *pipeline;
			NSDictionary *vars;
			VMPPipelineManager *manager;

			width = properties[@"width"];
			height = properties[@"height"];
			if (!width || !height) {
				CONFIG_ERROR(error, @"Video test channel is missing width or height property")
				return NO;
			}

			// Substitution dictionary for pipeline template
			vars = @{
				@"VIDEOCHANNEL.0" : name,
				@"WIDTH" : [width stringValue],
				@"HEIGHT" : [height stringValue]
			};
			VMPDebug(@"Substitution dictionary for video test pipeline: %@", vars);

			// Substitute variables in pipeline template
			pipeline = [_currentProfile pipelineForChannelType:type variables:vars error:error];
			if (!pipeline) {
				return NO;
			}

			VMPInfo(@"Creating video test pipeline manager with width %@ and height %@", width,
					height);

			manager = [VMPPipelineManager managerWithLaunchArgs:pipeline
														channel:name
													   delegate:self];
			if (![manager start]) {
				CONFIG_ERROR(error, @"Failed to start video test pipeline")
				return NO;
			}
			[_managedPipelines addObject:manager];

			VMPInfo(@"Video test pipeline for channel %@ started successfully", name);
		} else {
			CONFIG_ERROR(error, @"Unknown channel type")
			return NO;
		}
	}

	VMPDebug(@"Finished starting channel pipelines");
	return YES;
}

/*
	We use intervideo{src,sink} for separating source, and pipelines managed by the GStreamer RTSP
   server. Separating audio pipelines is much more difficult, and as of writing this, there is a
   major bug in the interaudio{src,sink}, which makes multiple listening clients impossible
   (see: https://gitlab.freedesktop.org/gstreamer/gst-plugins-bad/-/issues/1788)

   Instead, we use the concept of channels for configuration, but use sub-pipelines for audio
   processing for each mountpoint.

   This method converts the channel description to a sub-pipeline.
*/

- (BOOL)_createMountpointsWithError:(NSError **)error {
	VMPDebug(@"Creating mountpoints");
	NSArray *mountpoints = [_configuration mountpoints];

	for (VMPConfigMountpointModel *mountpoint in mountpoints) {
		NSString *type, *path;
		NSDictionary<NSString *, id> *properties;

		type = [mountpoint type];
		path = [mountpoint path];
		properties = [mountpoint properties];

		/* Set up a combined mountpoint with two video channels, and one audio channel.
		 * The secondary video channel can be used for a camera.
		 */
		if ([type isEqualToString:VMPConfigMountpointTypeCombined]) {
			GstRTSPMediaFactory *factory;
			NSString *presentationChannel, *cameraChannel, *audioChannel;
			NSString *pipeline;
			NSDictionary<NSString *, NSString *> *vars;

			presentationChannel = properties[@"presentationChannel"];
			cameraChannel = properties[@"cameraChannel"];
			audioChannel = properties[@"audioChannel"];
			if (!presentationChannel || !cameraChannel || !audioChannel) {
				CONFIG_ERROR(error, @"Combined mountpoint is missing a channel "
									@"('presentationChannel', 'cameraChannel', or 'audioChannel')")
				return NO;
			}

			vars = @{
				@"VIDEOCHANNEL.0" : presentationChannel,
				@"VIDEOCHANNEL.1" : cameraChannel,
			};

			pipeline = [_currentProfile pipelineForMountpointType:type variables:vars error:error];
			if (!pipeline) {
				return NO;
			}

			// Setup a new GStreamer RTSP media factory
			factory = gst_rtsp_media_factory_new();
			// Only create one pipeline and share it with other clients
			gst_rtsp_media_factory_set_shared(factory, TRUE);

			gst_rtsp_media_factory_set_launch(factory, (const gchar *) [pipeline UTF8String]);
			gst_rtsp_mount_points_add_factory(_mountPoints, (const gchar *) [path UTF8String],
											  factory);
		} else if ([type isEqualToString:VMPConfigMountpointTypeSingle]) {
			GstRTSPMediaFactory *factory;
			NSString *videoChannel, *audioChannel;
			NSString *pipeline;
			NSDictionary<NSString *, NSString *> *vars;

			videoChannel = properties[@"videoChannel"];
			audioChannel = properties[@"audioChannel"];
			if (!videoChannel || !audioChannel) {
				CONFIG_ERROR(error, @"Combined mountpoint is missing a channel "
									@"('videoChannel',  or 'audioChannel')")
				return NO;
			}

			factory = gst_rtsp_media_factory_new();
			// Only create one pipeline and share it with other clients
			gst_rtsp_media_factory_set_shared(factory, TRUE);

			vars = @{
				@"VIDEOCHANNEL.0" : videoChannel,
			};

			pipeline = [_currentProfile pipelineForMountpointType:type variables:vars error:error];
			if (!pipeline) {
				return NO;
			}

			gst_rtsp_media_factory_set_launch(factory, (const gchar *) [pipeline UTF8String]);

			gst_rtsp_mount_points_add_factory(_mountPoints, (const gchar *) [path UTF8String],
											  factory);
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