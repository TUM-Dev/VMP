/* vmpserverd - A virtual multimedia processor
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import <glib.h>

#import "VMPErrors.h"
#import "VMPJournal.h"
#import "VMPPipelineManager.h"

NSString *const kVMPStateCreated = @"created";
NSString *const kVMPStatePlaying = @"playing";
NSString *const kVMPStateEOS = @"eos";

NSString *const kVMPStatisticsNumberOfRestarts = @"numberOfRestarts";

/* We bridge the GStreamer bus callback mechanism with our VMPPipelineManagerDelegate.
 *
 * In order to do this, we need to annotate the cast from a void pointer to an
 * Objective-C object. This is mandatory, as we compile with ARC support.
 *
 * The object is bridged without retaining it, as the lifetime of the pipeline manager
 * is at least as long as the lifetime of the GStreamer pipeline.
 */
static gboolean gstreamer_bus_cb(GstBus *bus, GstMessage *message, void *mgr) {
	// Cast back to an Objective-C object without retaining it
	__unsafe_unretained VMPPipelineManager *localManager = (__bridge id) mgr;

	if (localManager != nil) {
		// If the delegate responds to the onBusEvent:manager: selector, call it
		if ([[localManager delegate] respondsToSelector:@selector(onBusEvent:manager:)]) {
			[[localManager delegate] onBusEvent:message manager:localManager];
		}
	}

	// We want to be notified for future bus events as well
	return TRUE;
}

// A category for (re)defining properties and declaring classes for private use
@interface VMPPipelineManager ()

@property (nonatomic, readwrite) NSString *state;
@property (nonatomic, readwrite) NSString *channel;
@property (nonatomic) GstElement *pipeline;
@property (nonatomic, readwrite) NSMutableDictionary *statistics;

// Pipeline management
- (BOOL)_createPipelineWithError:(NSError **)error;
- (BOOL)_resumePipelineWithError:(NSError **)error;

@end

@implementation VMPPipelineManager {
  @protected
	BOOL _pipelineCreated;
  @private
	NSString *_description;
	NSInteger _numberOfStarts;
}

+ (instancetype)managerWithLaunchArgs:(NSString *)args
							  channel:(NSString *)channel
							 delegate:(id<VMPPipelineManagerDelegate>)delegate {
	return [[VMPPipelineManager alloc] initWithLaunchArgs:args channel:channel delegate:delegate];
}

- (instancetype)initWithLaunchArgs:(NSString *)args
						   channel:(NSString *)channel
						  delegate:(id<VMPPipelineManagerDelegate>)delegate {
	NSDictionary *initialStatistics;

	NSAssert(args, @"Launch arguments cannot be nil");
	NSAssert(channel, @"Channel cannot be nil");
	NSAssert(delegate, @"Delegate cannot be nil");

	initialStatistics = @{kVMPStatisticsNumberOfRestarts : @0};

	self = [super init];
	if (self) {
		_channel = channel;
		_launchArgs = args;
		_delegate = delegate;
		_state = kVMPStateCreated;
		_pipeline = NULL;
		_pipelineCreated = NO;
		_statistics = [NSMutableDictionary dictionaryWithDictionary:initialStatistics];
		_description = [NSString stringWithFormat:@"<%@: %p> channel: %@, launch args: %@",
												  NSStringFromClass([self class]), self, _channel,
												  _launchArgs];
	}
	return self;
}

- (NSData *)pipelineDotGraph {
	NSData *data;
	GstBin *bin;
	gchar *dot;

	if (_pipeline == NULL || !GST_IS_BIN(_pipeline)) {
		return nil;
	}

	bin = GST_BIN(_pipeline);
	dot = gst_debug_bin_to_dot_data(bin, GST_DEBUG_GRAPH_SHOW_ALL);
	if (dot == NULL) {
		return nil;
	}

	// Transfer responsiblity for freeing buffer to object
	data = [NSData dataWithBytesNoCopy:dot length:strlen(dot) freeWhenDone:YES];

	return data;
}

- (BOOL)start {
	NSError *error = nil;

	// Do nothing if the pipeline is already created
	if (_pipelineCreated) {
		VMPInfo(@"Trying to start pipeline for channel %@, but it was already created", _channel);
		return YES;
	}

	// Update restart statistics
	_statistics[kVMPStatisticsNumberOfRestarts] = [NSNumber numberWithInteger:_numberOfStarts];
	_numberOfStarts++;

	// Start pipeline immediately
	if (![self _createPipelineWithError:&error]) {
		if (error != nil) {
			VMPError(@"%@", error);
		}

		if (error != nil && [error code] == VMPErrorCodeGStreamerParseError) {
			[self setState:kVMPStateEOS];
			[[self delegate] onStateChanged:kVMPStateEOS manager:self];
		}
		return NO;
	}
	[self setState:kVMPStatePlaying];

	return YES;
}

/* Create a pipeline and return the status.
 * Subsequent calls will return YES.
 */
- (BOOL)_createPipelineWithError:(NSError **)error {
	GstBus *bus;
	GstStateChangeReturn ret;
	GError *gerror = NULL;

	if (_pipelineCreated) {
		return YES;
	}
	_pipelineCreated = YES;

	// Transfer: Full. Deallocation (decreasing reference count) in dealloc:
	_pipeline = gst_parse_launch([_launchArgs UTF8String], &gerror);
	if (_pipeline == NULL) {
		VMPError(@"gst_parse_launch returned NULL while parsing launch args: %@", _launchArgs);

		if (gerror != NULL) {
			VMPError(@"GStreamer error: %s", gerror->message);

			if (error != NULL) {
				NSDictionary *userInfo =
					@{NSLocalizedDescriptionKey : [NSString stringWithUTF8String:gerror->message]};

				*error = [NSError errorWithDomain:VMPErrorDomain
											 code:VMPErrorCodeGStreamerParseError
										 userInfo:userInfo];
			}
		}
		return NO;
	}

	VMPDebug(@"Created pipeline with launch args: %@", _launchArgs);

	// Transfer: Full
	bus = gst_element_get_bus(_pipeline);
	if (bus != NULL) {
		// Bridge object pointer without touching reference count
		gst_bus_add_watch(bus, (GstBusFunc) gstreamer_bus_cb, (__bridge void *) self);
		gst_object_unref(bus);
	}

	// Set pipeline state to playing
	ret = gst_element_set_state(_pipeline, GST_STATE_PLAYING);
	if (ret == GST_STATE_CHANGE_FAILURE) {
		NSString *msg;

		msg = [NSString stringWithFormat:@"Failed to change pipeline state to playing for channel "
										  "'%@'",
										 _channel];
		if (error != NULL) {
			NSDictionary *userInfo = @{NSLocalizedDescriptionKey : msg};

			*error = [NSError errorWithDomain:VMPErrorDomain
										 code:VMPErrorCodeGStreamerStateChangeError
									 userInfo:userInfo];
		}
		return NO;
	}

	return YES;
}

- (BOOL)_resumePipelineWithError:(NSError **)error {
	GstStateChangeReturn ret;

	if ([self pipeline] == NULL) {
		return NO;
	}

	ret = gst_element_set_state([self pipeline], GST_STATE_PLAYING);
	if (ret == GST_STATE_CHANGE_FAILURE) {
		VMPError(@"Failed to resume pipeline");
		if (error != NULL) {
			NSDictionary *userInfo = @{NSLocalizedDescriptionKey : @"Failed to resume pipeline"};

			*error = [NSError errorWithDomain:VMPErrorDomain
										 code:VMPErrorCodeGStreamerStateChangeError
									 userInfo:userInfo];
		}
		return NO;
	}

	return YES;
}

- (void)sendEOSEvent {
	if ([self pipeline] == NULL) {
		return;
	}

	// Full Ownership transfer of eos event to function
	gst_element_send_event(_pipeline, gst_event_new_eos());
}

- (void)stop {
	if ([self pipeline] != NULL) {
		gst_element_set_state([self pipeline], GST_STATE_NULL);
		gst_object_unref(_pipeline);

		_pipeline = NULL;
		_pipelineCreated = NO;

		[self setState:kVMPStateCreated];
	}
}

- (NSString *)description {
	return _description;
}

- (void)dealloc {
	// If not already unreferenced by stop, unreference pipeline
	// gst_object_unref handles NULL pointers
	if (_pipeline != NULL) {
		gst_object_unref(_pipeline);
	}
	VMPDebug(@"Deallocating pipeline manager for channel %@", _channel);
}

@end
