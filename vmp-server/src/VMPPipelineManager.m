/* vmp-server - A virtual multimedia processor
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import "VMPPipelineManager.h"

// For V4L2 device detection
#include <fcntl.h>
#include <linux/videodev2.h>
#include <sys/ioctl.h>
#include <unistd.h>

NSString *const kVMPStateIdle = @"idle";
NSString *const kVMPStateDeviceConnected = @"device_connected";
NSString *const kVMPStateDeviceDisconnected = @"device_disconnected";
NSString *const kVMPStateDeviceError = @"device_error";
NSString *const kVMPStatePlaying = @"playing";

@implementation VMPPipelineManager
- (instancetype)initWithChannel:(NSString *)channel Delegate:(id<VMPPipelineManagerDelegate>)delegate {
    self = [super init];
    if (self) {
	_channel = channel;
	_delegate = delegate;
    }
    return self;
}

- (BOOL)start {
    NSAssert(NO, @"This method should be overriden and not called directly!");
    return NO;
}
@end

@implementation VMPV4L2PipelineManager
+ (instancetype)managerWithDevice:(NSString *)device
			  channel:(NSString *)channel
			 Delegate:(id<VMPPipelineManagerDelegate>)delegate {
    return [[VMPV4L2PipelineManager alloc] initWithDevice:device channel:channel Delegate:delegate];
}

// Check if the device exists, and is a V4L2 device with the required
// capabilities
- (BOOL)_checkV4L2DeviceWithError:(NSError **)error {
    errno = 0;

    int fd = open([_device UTF8String], O_RDWR);
    if (fd == -1) {
	NSLog(@"Failed to open device %@: %s", _device, strerror(errno));

	if (error != NULL)
	    *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
	close(fd);
	return NO;
    }

    struct v4l2_capability cap;
    // V4L2 devices support VIDIOC_QUERYCAP to optain information about the
    // device
    if (ioctl(fd, VIDIOC_QUERYCAP, &cap) == -1) {
	NSLog(@"Failed to query device %@: %s", _device, strerror(errno));

	if (error != NULL)
	    *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
	close(fd);
	return NO;
    }

    close(fd);
    return YES;
}

- (instancetype)initWithDevice:(NSString *)device
		       channel:(NSString *)channel
		      Delegate:(id<VMPPipelineManagerDelegate>)delegate {
    self = [super initWithChannel:channel Delegate:delegate];
    if (self) {
	_device = device;
    }
    return self;
}

@end

@implementation VMPAlsaPipelineManager
+ (instancetype)managerWithDevice:(NSString *)device
			  channel:(NSString *)channel
			 Delegate:(id<VMPPipelineManagerDelegate>)delegate {
    return [[VMPAlsaPipelineManager alloc] initWithDevice:device channel:channel Delegate:delegate];
}

- (instancetype)initWithDevice:(NSString *)device
		       channel:(NSString *)channel
		      Delegate:(id<VMPPipelineManagerDelegate>)delegate {
    self = [super initWithChannel:channel Delegate:delegate];
    if (self) {
	_device = device;
    }
    return self;
}
@end