/* vmp-server - A virtual multimedia processor
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#include <Foundation/NSDate.h>
#include <Foundation/NSRunLoop.h>
#import <glib.h>
#import <gst/rtsp-server/rtsp-server.h>

#import "NSString+substituteVariables.h"

#import "VMPConfigChannelModel.h"
#import "VMPConfigModel.h"
#import "VMPConfigMountpointModel.h"

#import "VMPErrors.h"
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

#pragma mark - RTSP pipeline state

// We have the problem that we cannot identify a mountpoint in the media-constructed callback.
// Therefore, we construct a state object, which contains the mountpoint name, and a pointer to the
// VMPRTSPServer instance.
//
// This is a workaround, because we are limited by the GStreamer RTSP server API.
@interface _VMPRTSPPipelineState : NSObject

@property (nonatomic) NSString *mountpointName;
@property (nonatomic) NSData *lastDotGraph;
@property (nonatomic) NSString *state;

// Pointer to the RTSP server instance
// Avoid a retain cycle by using a weak reference
@property (nonatomic, weak) VMPRTSPServer *server;

- (instancetype)initWithServer:(VMPRTSPServer *)server mountpointName:(NSString *)name;
@end

@implementation _VMPRTSPPipelineState
- (instancetype)initWithServer:(VMPRTSPServer *)server mountpointName:(NSString *)name {
	self = [super init];
	if (self) {
		_server = server;
		_mountpointName = name;
		_state = kVMPStateIdle;
	}
	return self;
}

@end

#pragma mark - RTSP Media Construction Callbacks

/* signal callback when the media is prepared for streaming. We can get the
 * session manager for each of the streams and connect to some signals. */
static void media_prepared_cb(GstRTSPMedia *media, gpointer user_data) {
	@autoreleasepool {
		guint n_streams;
		GstElement *element;
		_VMPRTSPPipelineState *state;

		state = (__bridge _VMPRTSPPipelineState *) user_data;

		element = gst_rtsp_media_get_element(media);
		n_streams = gst_rtsp_media_n_streams(media);

		VMPInfo(@"media %p is prepared for mountpoint '%@' and has %u streams", media,
				[state mountpointName], n_streams);

		if (GST_IS_BIN(element)) {
			NSData *dot_graph;
			GstBin *bin;
			gchar *dot_graph_str;

			bin = GST_BIN(element);

			dot_graph_str = gst_debug_bin_to_dot_data(bin, GST_DEBUG_GRAPH_SHOW_ALL);
			if (dot_graph_str) {
				dot_graph = [NSData dataWithBytesNoCopy:dot_graph_str
												 length:strlen(dot_graph_str)
										   freeWhenDone:YES];
				[state setLastDotGraph:dot_graph];
			}
		}

		gst_object_unref(element);
	}
}

static void media_constructed_cb(GstRTSPMediaFactory *factory, GstRTSPMedia *media,
								 gpointer user_data) {
	@autoreleasepool {
		GstElement *element;
		gchar *dot_graph_str;
		NSData *dot_graph;
		_VMPRTSPPipelineState *state;

		state = (__bridge _VMPRTSPPipelineState *) user_data;

		VMPInfo(@"Pipeline for mountpoint '%@' constructed successfully", [state mountpointName]);

		// Connect to the "prepared" signal to get more information about the streams once
		// initialisation is complete
		g_signal_connect(media, "prepared", (GCallback) media_prepared_cb, user_data);

		element = gst_rtsp_media_get_element(media);

		if (GST_IS_BIN(element)) {
			VMPDebug(@"Pipeline for mountpoint '%@' is a bin", [state mountpointName]);
			GstBin *bin;
			bin = GST_BIN(element);

			// Get first graph in case further initialisation fails in media_prepared_cb
			dot_graph_str = gst_debug_bin_to_dot_data(bin, GST_DEBUG_GRAPH_SHOW_ALL);

			if (dot_graph_str) {
				VMPDebug(@"Dot graph for mountpoint '%@' was generated successfully",
						 [state mountpointName]);
				dot_graph = [NSData dataWithBytesNoCopy:dot_graph_str
												 length:strlen(dot_graph_str)
										   freeWhenDone:YES];
			} else {
				VMPDebug(@"Dot graph for mountpoint '%@' could not be generated",
						 [state mountpointName]);
				dot_graph = nil;
			}

			// Update the state object
			[state setLastDotGraph:dot_graph];
		}

		gst_object_unref(element);
	}
}

#pragma mark - VMPRTSPServer

// Redeclare properties as readwrite
@interface VMPRTSPServer ()
@property (readwrite) VMPProfileModel *currentProfile;
@end

@implementation VMPRTSPServer {
	GstRTSPServer *_server;
	GstRTSPMountPoints *_mountPoints;

	// Registered source ID for the RTSP Server (GSource)
	guint _serverSourceId;

	NSMutableArray<VMPPipelineManager *> *_managedPipelines;
	NSMutableDictionary<NSString *, _VMPRTSPPipelineState *> *_rtspPipelineStates;
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
		_rtspPipelineStates =
			[NSMutableDictionary dictionaryWithCapacity:[[_configuration mountpoints] count]];

		NSUInteger channelCount = [[_configuration channels] count];
		_managedPipelines = [NSMutableArray arrayWithCapacity:channelCount];

		g_object_set(_server, "service", (const gchar *) [[_configuration rtspPort] UTF8String],
					 NULL);
		g_object_set(_server, "address", (const gchar *) [[_configuration rtspAddress] UTF8String],
					 NULL);
	}
	return self;
}

#pragma mark - VMPPipelineManagerDelegate

- (void)onStateChanged:(NSString *)state manager:(VMPPipelineManager *)mgr {
	VMPInfo(@"Pipeline state for manager %@ changed: %@", mgr, state);
}

/*
	This method is called when a bus event is received from the pipeline.
	We parse the GstMessage object, and log the error/warning.
*/
- (void)onBusEvent:(GstMessage *)message manager:(VMPPipelineManager *)mgr {
	NSString *channel;
	GstMessageType type;
	gchar *source;

	channel = [mgr channel];
	source = GST_OBJECT_NAME(message->src);

	VMPDebug(@"Received bus event from element %s on channel %@: %s", source, channel,
			 GST_MESSAGE_TYPE_NAME(message));

	type = GST_MESSAGE_TYPE(message);
	switch (type) {
	case GST_MESSAGE_ERROR: {
		GError *err;
		gchar *debug;

		// Transfer: FULL
		gst_message_parse_error(message, &err, &debug);

		VMPError(@"Error from element %s on channel %@: %s", source, channel, err->message);

		g_error_free(err);
		g_free(debug);
		break;
	}
	case GST_MESSAGE_WARNING: {
		GError *err;
		gchar *debug;

		// Transfer: FULL
		gst_message_parse_warning(message, &err, &debug);

		VMPWarn(@"Warning from element %s on channel %@: %s", source, channel, err->message);

		g_error_free(err);
		g_free(err);
		break;
	}
	case GST_MESSAGE_EOS: {
		VMPError(@"End of stream for channel %@", channel);

		// We should always try to restart the pipeline
		[mgr restart];
		break;
	}
	default:
		break;
	}
}

#pragma mark - Private methods

// Iterate over the channelConfiguration array, create all pipeline managers acordingly, and
// start them.
- (BOOL)_startChannelPipelinesWithError:(NSError **)error {
	NSArray *channels;
	VMPInfo(@"Starting channel pipelines");

	channels = [_configuration channels];
	VMPDebug(@"Found %lu channels in configuration", [channels count]);

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
		}
	}

	VMPDebug(@"Finished starting channel pipelines");
	return YES;
}

/*
	We use intervideo{src,sink} for separating source, and pipelines managed by the GStreamer
   RTSP server. Separating audio pipelines is much more difficult, and as of writing this, there
   is a major bug in the interaudio{src,sink}, which makes multiple listening clients impossible
   (see: https://gitlab.freedesktop.org/gstreamer/gst-plugins-bad/-/issues/1788)

   Instead, we use the concept of channels for configuration, but use sub-pipelines for audio
   processing for each mountpoint.

   This method converts the channel description to a sub-pipeline.
*/

- (BOOL)_createMountpointsWithError:(NSError **)error {
	VMPDebug(@"Creating mountpoints");
	NSArray *mountpoints = [_configuration mountpoints];

	for (VMPConfigMountpointModel *mountpoint in mountpoints) {
		NSString *name, *type, *path;
		NSDictionary<NSString *, id> *properties;
		_VMPRTSPPipelineState *state;

		name = [mountpoint name];
		type = [mountpoint type];
		path = [mountpoint path];
		properties = [mountpoint properties];

		state = [[_VMPRTSPPipelineState alloc] initWithServer:self mountpointName:name];

		// Add state object to dictionary
		_rtspPipelineStates[name] = state;

		VMPInfo(@"Creating mountpoint '%@' of type '%@' at path '%@'", name, type, path);

		/* Set up a combined mountpoint with two video channels, and one audio channel.
		 * The secondary video channel can be used for a camera.
		 */
		if ([type isEqualToString:VMPConfigMountpointTypeCombined]) {
			GstRTSPMediaFactory *factory;
			NSString *videoChannel, *secondaryVideoChannel, *audioChannel;
			NSString *pipeline, *audioPipeline;
			NSDictionary<NSString *, NSString *> *vars;

			videoChannel = properties[@"videoChannel"];
			secondaryVideoChannel = properties[@"secondaryVideoChannel"];
			audioChannel = properties[@"audioChannel"];
			if (!videoChannel || !secondaryVideoChannel || !audioChannel) {
				CONFIG_ERROR(error, @"Combined mountpoint is missing a channel "
									@"('videoChannel', 'secondaryVideoChannel', or 'audioChannel')")
				return NO;
			}

			vars = @{
				@"VIDEOCHANNEL.0" : videoChannel,
				@"VIDEOCHANNEL.1" : secondaryVideoChannel,
			};

			pipeline = [_currentProfile pipelineForMountpointType:type variables:vars error:error];
			if (!pipeline) {
				return NO;
			}

			audioPipeline = [self _pipelineFromAudioChannel:audioChannel error:error];
			if (!audioPipeline) {
				return NO;
			}

			VMPDebug(@"Video-only mountpoint pipeline: %@", pipeline);

			pipeline = [NSString stringWithFormat:@"%@ %@", pipeline, audioPipeline];

			VMPDebug(@"Combined mountpoint pipeline: %@", pipeline);

			// Setup a new GStreamer RTSP media factory
			factory = gst_rtsp_media_factory_new();
			// Only create one pipeline and share it with other clients
			gst_rtsp_media_factory_set_shared(factory, TRUE);

			gst_rtsp_media_factory_set_launch(factory, (const gchar *) [pipeline UTF8String]);
			g_signal_connect(factory, "media-constructed", (GCallback) media_constructed_cb,
							 (__bridge void *) state);
			gst_rtsp_mount_points_add_factory(_mountPoints, (const gchar *) [path UTF8String],
											  factory);
		} else if ([type isEqualToString:VMPConfigMountpointTypeSingle]) {
			GstRTSPMediaFactory *factory;
			NSString *videoChannel, *audioChannel;
			NSString *pipeline, *audioPipeline;
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

			audioPipeline = [self _pipelineFromAudioChannel:audioChannel error:error];
			if (!audioPipeline) {
				return NO;
			}

			VMPDebug(@"Video-only single mountpoint pipeline: %@", pipeline);

			pipeline = [NSString stringWithFormat:@"%@ %@", pipeline, audioPipeline];

			VMPDebug(@"Combined single mountpoint pipeline: %@", pipeline);

			gst_rtsp_media_factory_set_launch(factory, (const gchar *) [pipeline UTF8String]);

			g_signal_connect(factory, "media-constructed", (GCallback) media_constructed_cb,
							 (__bridge void *) state);

			gst_rtsp_mount_points_add_factory(_mountPoints, (const gchar *) [path UTF8String],
											  factory);
		}
	}

	VMPDebug(@"Finished creating mountpoints");
	return YES;
}

- (NSString *)_pipelineFromAudioChannel:(NSString *)channel error:(NSError **)error {
	NSArray *channels;

	channels = [_configuration channels];

	for (VMPConfigChannelModel *chan in channels) {
		NSString *name;

		name = [chan name];
		if ([name isEqualToString:channel]) {
			NSDictionary<NSString *, id> *properties;
			NSString *type;

			properties = [chan properties];
			type = [chan type];

			if ([type isEqualToString:VMPConfigChannelTypePulseAudio]) {
				NSString *device;
				NSDictionary<NSString *, NSString *> *vars;

				device = properties[@"device"];
				if (!device) {
					VMP_FAST_ERROR(error, VMPErrorCodeConfigurationError,
								   @"'device' property not found for channel '%@", channel);
					return nil;
				}

				vars = @{@"PULSEDEV" : device};

				return [_currentProfile pipelineForChannelType:type variables:vars error:error];
			} else if ([type isEqualToString:@"audioTest"]) {
				NSString *type;
				NSDictionary<NSString *, id> *vars;

				type = [chan type];
				vars = @{};

				return [_currentProfile pipelineForChannelType:type variables:vars error:error];
			} else {
				CONFIG_ERROR(error, @"Unknown audio channel type")
				return nil;
			}
		}
	}

	return nil;
}

#pragma mark - Public methods

- (NSData *)dotGraphForMountPointName:(NSString *)name {
	_VMPRTSPPipelineState *state;

	state = _rtspPipelineStates[name];
	if (!state) {
		return nil;
	}

	return [state lastDotGraph];
}

- (VMPPipelineManager *)pipelineManagerForChannel:(NSString *)channel {
	for (VMPPipelineManager *mgr in _managedPipelines) {
		if ([[mgr channel] isEqualToString:channel]) {
			return mgr;
		}
	}

	return nil;
}

- (NSArray *)channelInfo {
	NSMutableArray *info = [NSMutableArray arrayWithCapacity:[_managedPipelines count]];

	for (VMPPipelineManager *mgr in _managedPipelines) {
		NSDictionary *cur = @{
			@"name" : [mgr channel],
			@"state" : [mgr state],
		};

		[info addObject:cur];
	}

	return [NSArray arrayWithArray:info];
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
	_serverSourceId = gst_rtsp_server_attach(_server, NULL);

	VMPInfo(@"RTSP server listening on address '%@' on port '%@'", [_configuration rtspAddress],
			[_configuration rtspPort]);

	return YES;
}

- (void)stop {
	VMPInfo(@"Stopping RTSP server...");

	// Stop all pipelines
	for (VMPPipelineManager *mgr in _managedPipelines) {
		VMPInfo(@"Stopping pipeline for channel %@", [mgr channel]);
		[mgr stop];
	}

	// Stop the RTSP server
	g_source_remove(_serverSourceId);

	return;
}

- (void)dealloc {
	g_object_unref(_mountPoints);
	g_object_unref(_server);
}

@end