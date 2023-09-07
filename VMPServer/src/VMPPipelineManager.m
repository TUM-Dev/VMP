/* vmp-server - A virtual multimedia processor
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import "VMPPipelineManager.h"
#import "VMPErrors.h"

// For V4L2 device detection
#include <fcntl.h>
#include <linux/videodev2.h>
#include <sys/ioctl.h>
#include <unistd.h>

// For ALSA device detection
#include <sound/asound.h>

NSString *const kVMPStateIdle = @"idle";
NSString *const kVMPStateDeviceConnected = @"device_connected";
NSString *const kVMPStateDeviceDisconnected = @"device_disconnected";
NSString *const kVMPStateDeviceError = @"device_error";
NSString *const kVMPStatePlaying = @"playing";

#define PRINT_ERROR(error)                                                                                             \
	if (error != nil) {                                                                                                \
		NSLog(@"Error: %@", error);                                                                                    \
	}

static gboolean gstreamer_bus_cb(GstBus *bus, GstMessage *message, VMPPipelineManager *mgr) { return TRUE; }

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
}

+ (instancetype)managerWithLaunchArgs:(NSString *)args
							  Channel:(NSString *)channel
							 Delegate:(id<VMPPipelineManagerDelegate>)delegate {
	return [[VMPPipelineManager alloc] initWithLaunchArgs:args Channel:channel Delegate:delegate];
}

- (instancetype)initWithLaunchArgs:(NSString *)args
						   Channel:(NSString *)channel
						  Delegate:(id<VMPPipelineManagerDelegate>)delegate {
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
			[[self delegate] onStateChanged:kVMPStateDeviceError];
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
	GstElement *pipeline;
	GstBus *bus;
	GstStateChangeReturn ret;
	GError *gerror = NULL;

	if (_pipelineCreated) {
		return NO;
	}

	_pipelineCreated = YES;

	// Transfer: Full
	pipeline = gst_parse_launch([_launchArgs UTF8String], &gerror);
	if (pipeline == NULL) {
		NSLog(@"Failed to create pipeline");
		if (gerror != NULL) {
			NSLog(@"GStreamer error: %s", gerror->message);

			if (error != NULL) {
				NSDictionary *userInfo = @{NSLocalizedDescriptionKey : [NSString stringWithUTF8String:gerror->message]};

				*error = [NSError errorWithDomain:VMPErrorDomain
											 code:VMPErrorCodeGStreamerParseError
										 userInfo:userInfo];
			}
		}
		return NO;
	}

	NSDebugLog(@"Created pipeline with launch args: %@", _launchArgs);

	// Set pipeline state to playing
	ret = gst_element_set_state(pipeline, GST_STATE_PLAYING);
	if (ret == GST_STATE_CHANGE_FAILURE) {
		NSLog(@"Failed to start pipeline");
		if (error != NULL) {
			NSDictionary *userInfo = @{NSLocalizedDescriptionKey : @"Failed to start pipeline"};

			*error = [NSError errorWithDomain:VMPErrorDomain
										 code:VMPErrorCodeGStreamerStateChangeError
									 userInfo:userInfo];
		}
		return NO;
	}

	// Transfer: Full
	bus = gst_element_get_bus(pipeline);
	if (bus != NULL) {
		// Bridge object pointer without touching reference count
		gst_bus_add_watch(bus, (GstBusFunc) gstreamer_bus_cb, (__bridge gpointer) self);
		gst_object_unref(bus);
	}

	[self setPipeline:pipeline];
	return YES;
}

- (BOOL)_resumePipelineWithError:(NSError **)error {
	GstStateChangeReturn ret;

	if ([self pipeline] == NULL) {
		return NO;
	}

	ret = gst_element_set_state([self pipeline], GST_STATE_PLAYING);
	if (ret == GST_STATE_CHANGE_FAILURE) {
		NSLog(@"Failed to resume pipeline");
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

- (void)dealloc {
	gst_object_unref([self pipeline]);
}

@end

@implementation VMPV4L2PipelineManager {
  @private
	VMPUdevClient *_udevClient;
}

+ (instancetype)managerWithDevice:(NSString *)device
						  channel:(NSString *)channel
						 Delegate:(id<VMPPipelineManagerDelegate>)delegate {
	return [[VMPV4L2PipelineManager alloc] initWithDevice:device channel:channel Delegate:delegate];
}

- (instancetype)initWithDevice:(NSString *)device
					   channel:(NSString *)channel
					  Delegate:(id<VMPPipelineManagerDelegate>)delegate {
	NSAssert(device, @"Device cannot be nil");
	NSAssert(channel, @"Channel cannot be nil");

	NSString *args =
		[NSString stringWithFormat:@"v4l2src device=%@ ! queue ! videoconvert ! queue ! intervideosink channel=%@",
								   device, channel];

	self = [super initWithLaunchArgs:args Channel:channel Delegate:delegate];
	if (self) {
		_device = device;
		_udevClient = [VMPUdevClient clientWithSubsystems:@[ @"video4linux" ] Delegate:self];
	}
	return self;
}

#pragma mark - VMPUdevClientDelegate methods

- (void)onDeviceAdded:(NSString *)device {
	if ([device isEqualToString:_device]) {
		NSError *error = nil;
		[self setState:kVMPStateDeviceConnected];
		[[self delegate] onStateChanged:kVMPStateDeviceConnected];

		if (!_pipelineCreated) {
			if (![self _createPipelineWithError:&error]) {
				PRINT_ERROR(error);
				[self setState:kVMPStateDeviceError];
				[[self delegate] onStateChanged:kVMPStateDeviceError];
			} else {
				[self setState:kVMPStatePlaying];
				[[self delegate] onStateChanged:kVMPStatePlaying];
			}
		} else { // Resume pipeline
			if (![self _resumePipelineWithError:&error]) {
				PRINT_ERROR(error);
				[self setState:kVMPStateDeviceError];
				[[self delegate] onStateChanged:kVMPStateDeviceError];
			} else {
				[self setState:kVMPStatePlaying];
				[[self delegate] onStateChanged:kVMPStatePlaying];
			}
		}
	}
}

- (void)onDeviceRemoved:(NSString *)device {
	if ([device isEqualToString:_device]) {
		[self setState:kVMPStateDeviceDisconnected];
		[[self delegate] onStateChanged:kVMPStateDeviceDisconnected];

		[self _resetPipeline];
	}
}

// Check if the device exists, and is a V4L2 device with the required
// capabilities
- (BOOL)_checkV4L2DeviceWithError:(NSError **)error {
	errno = 0;

	int fd = open([_device UTF8String], O_RDWR);
	if (fd == -1) {
		NSLog(@"Failed to open device %@: %s", _device, strerror(errno));

		if (error != NULL) {
			NSDictionary *userInfo = @{NSLocalizedDescriptionKey : [NSString stringWithUTF8String:strerror(errno)]};
			*error = [NSError errorWithDomain:VMPErrorDomain code:VMPErrorCodeDeviceNotFound userInfo:userInfo];
		}
		close(fd);
		return NO;
	}

	struct v4l2_capability cap;
	// V4L2 devices support VIDIOC_QUERYCAP to optain information about the
	// device
	if (ioctl(fd, VIDIOC_QUERYCAP, &cap) == -1) {
		NSLog(@"Failed to query device %@: %s", _device, strerror(errno));

		if (error != NULL) {
			NSDictionary *userInfo = @{NSLocalizedDescriptionKey : [NSString stringWithUTF8String:strerror(errno)]};
			*error = [NSError errorWithDomain:VMPErrorDomain code:VMPErrorV4L2DeviceCapabilities userInfo:userInfo];
		}
		close(fd);
		return NO;
	}

	close(fd);
	return YES;
}

- (BOOL)start {
	NSError *error = nil;

	// Start pipeline immediately if the device exists, and is a valid V4L2 device
	if (![self _checkV4L2DeviceWithError:&error]) {
		if (error != nil && [error code] == VMPErrorCodeDeviceNotFound) {
			[self setState:kVMPStateDeviceDisconnected];
			[[self delegate] onStateChanged:kVMPStateDeviceDisconnected];
		} else {
			[self setState:kVMPStateDeviceError];
			[[self delegate] onStateChanged:kVMPStateDeviceError];
		}
	} else { // Start pipeline immediately
		[self setState:kVMPStateDeviceConnected];
		[[self delegate] onStateChanged:kVMPStateDeviceConnected];

		if (![self _createPipelineWithError:&error]) {
			if (error != nil && [error code] == VMPErrorCodeGStreamerParseError) {
				[self setState:kVMPStateDeviceError];
				[[self delegate] onStateChanged:kVMPStateDeviceError];
			}
		}
	}

	if (![_udevClient startMonitorWithError:&error]) {
		NSLog(@"Failed to start udev client: %@", error);
		[self setState:kVMPStateDeviceError];
		return NO;
	}

	return YES;
}

- (void)stop {
	[self _resetPipeline];
	[_udevClient stopMonitor];
}

@end

@implementation VMPALSAPipelineManager {
  @private
	VMPUdevClient *_udevClient;
}
+ (instancetype)managerWithDevice:(NSString *)device
						  channel:(NSString *)channel
						 Delegate:(id<VMPPipelineManagerDelegate>)delegate {
	return [[VMPALSAPipelineManager alloc] initWithDevice:device channel:channel Delegate:delegate];
}

- (instancetype)initWithDevice:(NSString *)device
					   channel:(NSString *)channel
					  Delegate:(id<VMPPipelineManagerDelegate>)delegate {
	NSAssert(device, @"Device cannot be nil");
	NSAssert(channel, @"Channel cannot be nil");

	// TODO: Enforce S16LE right after alsasrc possible?
	NSString *args =
		[NSString stringWithFormat:@"alsasrc device=%@ ! queue ! audioconvert ! capsfilter "
								   @"caps=audio/x-raw,format=S16LE,layout=interleaved,channels=2 ! audioresample ! "
								   @"queue ! interaudiosink channel=%@",
								   _device, [self channel]];

	self = [super initWithLaunchArgs:args Channel:channel Delegate:delegate];
	if (self) {
		_device = device;
		_udevClient = [VMPUdevClient clientWithSubsystems:@[ @"sound" ] Delegate:self];
	}
	return self;
}

#pragma mark - VMPUdevClientDelegate methods
- (void)onDeviceAdded:(NSString *)device {
	if ([device isEqualToString:_device]) {
		[self setState:kVMPStateDeviceConnected];
		[[self delegate] onStateChanged:kVMPStateDeviceConnected];
	}
}

- (void)onDeviceRemoved:(NSString *)device {
	if ([device isEqualToString:_device]) {
		[self setState:kVMPStateDeviceDisconnected];
		[[self delegate] onStateChanged:kVMPStateDeviceDisconnected];
	}
}

- (BOOL)_checkAlsaDeviceWithError:(NSError **)error {
	errno = 0;

	int fd = open([_device UTF8String], O_RDWR);
	if (fd == -1) {
		NSLog(@"Failed to open device %@: %s", _device, strerror(errno));

		if (error != NULL) {
			NSDictionary *userInfo = @{NSLocalizedDescriptionKey : [NSString stringWithUTF8String:strerror(errno)]};
			*error = [NSError errorWithDomain:VMPErrorDomain code:VMPErrorCodeDeviceNotFound userInfo:userInfo];
		}
		close(fd);
		return NO;
	}

	// Check if device is a sound card
	errno = 0;
	int isSoundCard = ioctl(fd, SNDRV_CTL_IOCTL_CARD_INFO, NULL);
	if (isSoundCard < 0) {
		NSLog(@"Failed to query device %@: %s", _device, strerror(errno));

		if (error != NULL) {
			NSDictionary *userInfo = @{NSLocalizedDescriptionKey : [NSString stringWithUTF8String:strerror(errno)]};
			*error = [NSError errorWithDomain:VMPErrorDomain code:VMPErrorALSADeviceCapabilities userInfo:userInfo];
		}
		close(fd);
		return NO;
	}

	close(fd);
	return YES;
}

- (BOOL)start {
	NSError *error = nil;

	// Start pipeline immediately if the device exists, and is a valid ALSA device
	if (![self _checkAlsaDeviceWithError:&error]) {
		if (error != nil && [error code] == VMPErrorCodeDeviceNotFound) {
			[self setState:kVMPStateDeviceDisconnected];
			[[self delegate] onStateChanged:kVMPStateDeviceDisconnected];
		} else {
			[self setState:kVMPStateDeviceError];
			[[self delegate] onStateChanged:kVMPStateDeviceError];
		}
	} else { // Start pipeline immediately
		[self setState:kVMPStateDeviceConnected];
		[[self delegate] onStateChanged:kVMPStateDeviceConnected];

		if (![self _createPipelineWithError:&error]) {
			PRINT_ERROR(error);

			if (error != nil && [error code] == VMPErrorCodeGStreamerParseError) {
				[self setState:kVMPStateDeviceError];
				[[self delegate] onStateChanged:kVMPStateDeviceError];
			}
		}
	}

	if (![_udevClient startMonitorWithError:&error]) {
		NSLog(@"Failed to start udev client: %@", error);
		[self setState:kVMPStateDeviceError];
		return NO;
	}

	return YES;
}

- (void)stop {
	[self _resetPipeline];
	[_udevClient stopMonitor];
}

@end