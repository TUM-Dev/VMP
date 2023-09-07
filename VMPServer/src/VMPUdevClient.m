/* vmp-server - A virtual multimedia processor
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import "VMPUdevClient.h"
#import "VMPErrors.h"

#include <libudev.h>

@interface VMPUdevClient ()
@property (nonatomic, readonly) struct udev *udev;
@property (nonatomic, readonly) struct udev_monitor *monitor;
@property (nonatomic, readonly) BOOL running;
@property (nonatomic, readonly) NSFileHandle *fileHandle;
@end

@implementation VMPUdevClient

+ (instancetype)clientWithSubsystems:(NSArray<NSString *> *)subsystems Delegate:(id<VMPUdevClientDelegate>)delegate {
	return [[VMPUdevClient alloc] initWithSubsystems:subsystems Delegate:delegate];
}

- (instancetype)initWithSubsystems:(NSArray<NSString *> *)subsystems Delegate:(id<VMPUdevClientDelegate>)delegate {
	self = [super init];
	if (self) {
		_delegate = delegate;
		_subsystems = subsystems;
	}

	return self;
}

- (BOOL)startMonitorWithError:(NSError **)error {
	if (_running) {
		return YES;
	}

	_running = YES;
	_udev = udev_new();
	if (!_udev) {
		if (error) {
			*error = [NSError errorWithDomain:VMPErrorDomain code:VMPErrorCodeUdevError userInfo:nil];
		}
		return NO;
	}

	// Create monitor for udev events
	_monitor = udev_monitor_new_from_netlink(_udev, "udev");
	if (!_monitor) {
		if (error) {
			*error = [NSError errorWithDomain:VMPErrorDomain code:VMPErrorCodeUdevMonitorError userInfo:nil];
		}
		return NO;
	}

	// Register subsystems to udev monitor filter
	for (NSString *subsystem in _subsystems) {
		if (udev_monitor_filter_add_match_subsystem_devtype(_monitor, [subsystem UTF8String], NULL) < 0) {
			if (error) {
				*error = [NSError errorWithDomain:VMPErrorDomain code:VMPErrorCodeUdevMonitorError userInfo:nil];
			}
			return NO;
		}
	}

	// Start monitoring
	if (udev_monitor_enable_receiving(_monitor) < 0) {
		if (error) {
			*error = [NSError errorWithDomain:VMPErrorDomain code:VMPErrorCodeUdevMonitorError userInfo:nil];
		}
		return NO;
	}

	// Get file descriptor for runloop registration
	int fd = udev_monitor_get_fd(_monitor);

	_fileHandle = [[NSFileHandle alloc] initWithFileDescriptor:fd];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(udevEvent:)
												 name:NSFileHandleReadCompletionNotification
											   object:_fileHandle];

	[_fileHandle readInBackgroundAndNotify];

	return YES;
}

- (void)stopMonitor {
	if (!_running) {
		return;
	}

	_running = NO;
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[_fileHandle closeFile];
	udev_monitor_unref(_monitor);
	udev_unref(_udev);
}

- (void)udevEvent:(NSNotification *)notification {
	NSData *data = [[notification userInfo] objectForKey:NSFileHandleNotificationDataItem];
	const struct udev_device *dev = udev_monitor_receive_device(_monitor);
	if (dev) {
		NSString *action = [NSString stringWithUTF8String:udev_device_get_action(dev)];
		NSString *subsystem = [NSString stringWithUTF8String:udev_device_get_subsystem(dev)];
		NSString *device = [NSString stringWithUTF8String:udev_device_get_devnode(dev)];

		if ([action isEqualToString:@"add"]) {
			[_delegate onDeviceAdded:device];
		} else if ([action isEqualToString:@"remove"]) {
			[_delegate onDeviceRemoved:device];
		}
	}

	[_fileHandle readInBackgroundAndNotify];
}

@end
