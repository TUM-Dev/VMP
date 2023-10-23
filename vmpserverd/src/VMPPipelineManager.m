/* vmp-server - A virtual multimedia processor
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import "VMPPipelineManager.h"
#import "VMPErrors.h"
#import "VMPJournal.h"

#include <glib.h>

NSString *const kVMPStateIdle = @"idle";
NSString *const kVMPStateDeviceConnected = @"device_connected";
NSString *const kVMPStateDeviceDisconnected = @"device_disconnected";
NSString *const kVMPStateDeviceError = @"device_error";
NSString *const kVMPStatePlaying = @"playing";

#define PRINT_ERROR(error)                                                                         \
	if (error != nil) {                                                                            \
		VMPError(@"Error: %@", error);                                                             \
	}

static gboolean gstreamer_bus_cb(GstBus *bus, GstMessage *message, void *mgr) {
	// Cast back to an Objective-C object
	__unsafe_unretained VMPPipelineManager *localManager = (__bridge id) mgr;

	VMPInfo(@"Received bus message: %s", GST_MESSAGE_TYPE_NAME(message));
	VMPInfo(@"Manager from bus: %@", localManager);
	return TRUE;
}

// Redefine properties for readwrite access
@interface VMPPipelineManager ()

@property (nonatomic, readwrite) NSString *state;
@property (nonatomic, readwrite) GstElement *pipeline;

// Pipeline management
- (BOOL)_createPipelineWithError:(NSError **)error;
- (BOOL)_resumePipelineWithError:(NSError **)error;
- (void)_resetPipeline;

@end

@implementation VMPPipelineManager {
  @protected
	BOOL _pipelineCreated;
  @private
	NSString *_description;
}

+ (instancetype)managerWithLaunchArgs:(NSString *)args
							  channel:(NSString *)channel
							 delegate:(id<VMPPipelineManagerDelegate>)delegate {
	return [[VMPPipelineManager alloc] initWithLaunchArgs:args channel:channel delegate:delegate];
}

- (instancetype)initWithLaunchArgs:(NSString *)args
						   channel:(NSString *)channel
						  delegate:(id<VMPPipelineManagerDelegate>)delegate {
	NSAssert(args, @"Launch arguments cannot be nil");
	NSAssert(channel, @"Channel cannot be nil");
	NSAssert(delegate, @"Delegate cannot be nil");

	self = [super init];
	if (self) {
		_channel = channel;
		_launchArgs = args;
		_delegate = delegate;
		_state = kVMPStateIdle;
		_pipeline = NULL;
		_pipelineCreated = NO;
		_description = [NSString stringWithFormat:@"<%@: %p> channel: %@, launch args: %@",
												  NSStringFromClass([self class]), self, _channel,
												  _launchArgs];
	}
	return self;
}

- (BOOL)start {
	NSError *error = nil;

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

- (void)stop {
	[self _resetPipeline];
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

	// Transfer: Full
	bus = gst_element_get_bus(_pipeline);
	if (bus != NULL) {
		// Bridge object pointer without touching reference count
		// TODO: figure out bridging problem
		gst_bus_add_watch(bus, (GstBusFunc) gstreamer_bus_cb, (__bridge void *) self);
		gst_object_unref(bus);
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

- (void)_resetPipeline {
	if ([self pipeline] != NULL) {
		gst_element_set_state([self pipeline], GST_STATE_NULL);
	}
}

- (NSString *)description {
	return _description;
}

- (void)dealloc {
	gst_object_unref([self pipeline]);
}

@end
