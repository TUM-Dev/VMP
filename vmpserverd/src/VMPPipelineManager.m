/* vmp-server - A virtual multimedia processor
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import "VMPPipelineManager.h"
#import "VMPErrors.h"
#import "VMPJournal.h"
#include "gst/gstdebugutils.h"
#include "gst/gstelement.h"
#include <Foundation/NSDate.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSRunLoop.h>

#include <glib.h>

NSString *const kVMPStateIdle = @"idle";
NSString *const kVMPStateDeviceConnected = @"device_connected";
NSString *const kVMPStateDeviceDisconnected = @"device_disconnected";
NSString *const kVMPStateDeviceError = @"device_error";
NSString *const kVMPStatePlaying = @"playing";
NSString *const kVMPStateError = @"error";

NSString *const kVMPStatisticsNumberOfRestarts = @"numberOfRestarts";

#define PRINT_ERROR(error)                                                                         \
	if (error != nil) {                                                                            \
		VMPError(@"Error: %@", error);                                                             \
	}

// We bridge the GStreamer bus callback mechanism with our VMPPipelineManagerDelegate
static gboolean gstreamer_bus_cb(GstBus *bus, GstMessage *message, void *mgr) {
	// Cast back to an Objective-C object
	__unsafe_unretained VMPPipelineManager *localManager = (__bridge id) mgr;

	if (localManager != nil) {
		// If the delegate responds to the onBusEvent:manager: selector, call it
		if ([[localManager delegate] respondsToSelector:@selector(onBusEvent:manager:)]) {
			[[localManager delegate] onBusEvent:message manager:localManager];
		}
	}

	return TRUE;
}

// Redefine properties for readwrite access
@interface VMPPipelineManager ()

@property (nonatomic, readwrite) NSString *state;
@property (nonatomic, readwrite) GstElement *pipeline;
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
		_state = kVMPStateIdle;
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

	data = [NSData dataWithBytesNoCopy:dot length:strlen(dot) freeWhenDone:YES];

	return data;
}

- (BOOL)start {
	NSError *error = nil;

	// Do nothing if the pipeline is already created
	if (_pipelineCreated) {
		VMPError(@"Pipeline for channel %@ already created", _channel);
		return NO;
	}

	// Update restart statistics
	_statistics[kVMPStatisticsNumberOfRestarts] = [NSNumber numberWithInteger:_numberOfStarts];
	_numberOfStarts++;

	// Start pipeline immediately
	if (![self _createPipelineWithError:&error]) {
		PRINT_ERROR(error);
		if (error != nil && [error code] == VMPErrorCodeGStreamerParseError) {
			[self setState:kVMPStateDeviceError];
			[[self delegate] onStateChanged:kVMPStateDeviceError manager:self];
		}
		return NO;
	}

	return YES;
}

/* Create a pipeline and return the status.
   This method should only be called once during the lifetime of the object.
   Subsequent calls will return NO.
*/
- (BOOL)_createPipelineWithError:(NSError **)error {
	GstBus *bus;
	GstStateChangeReturn ret;
	GError *gerror = NULL;

	if (_pipelineCreated) {
		return NO;
	}

	_pipelineCreated = YES;

	// Transfer: Full
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

- (void)stop {
	if ([self pipeline] != NULL) {
		gst_element_set_state([self pipeline], GST_STATE_NULL);
		gst_object_unref(_pipeline);

		_pipeline = NULL;
		_pipelineCreated = NO;

		[self setState:kVMPStateIdle];
	}
}

// TODO: We should use a block with performBlock: instead of a trampoline method
- (void)_startFromRunloop {
	if (![self start]) {
		// Schedule a new pipeline restart
		[self restart];
	}
}

- (void)restart {
	NSRunLoop *runloop;
	NSTimeInterval delay;

	VMPInfo(@"Schedule pipeline restart for channel '%@'", _channel);

	[self stop];

	runloop = [NSRunLoop currentRunLoop];
	delay = 1.0;

	// Schedule pipeline restart
	[runloop performSelector:@selector(_startFromRunloop) withObject:self afterDelay:delay];
}

- (NSString *)description {
	return _description;
}

- (void)dealloc {
	// If not already unreferenced by stop, unreference pipeline
	// gst_object_unref handles NULL pointers
	gst_object_unref(_pipeline);
}

@end
