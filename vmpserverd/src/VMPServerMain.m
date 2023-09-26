/* vmp-server - A virtual multimedia processor
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import "VMPServerMain.h"
#import "VMPJournal.h"
#import "VMPRTSPServer.h"

#import <glib.h>

/**
	Keys for the configuration plist

	You can see an example of the configuration file in the
	vmpserverd project directory.
 */
NSString *kVMPServerMountPointsKey = @"mountpoints";
NSString *kVMPServerRTSPPortKey = @"rtspPort";
NSString *kVMPServerRTSPAddressKey = @"rtspAddress";

NSString *kVMPServerMountPointsPathKey = @"path";
NSString *kVMPServerMountPointsTypeKey = @"type";
NSString *kVMPServerMountPointsNameKey = @"name";

NSString *kVMPServerMountpointTypeSingle = @"single";
NSString *kVMPServerMountpointTypeCombined = @"combined";

NSString *kVMPServerMountpointVideoChannelKey = @"videoChannel";
NSString *kVMPServerMountpointSecondaryVideoChannelKey = @"secondaryVideoChannel";
NSString *kVMPServerMountpointAudioChannelKey = @"audioChannel";

NSString *kVMPServerChannelConfigurationKey = @"channelConfiguration";
NSString *kVMPServerChannelTypeKey = @"type";
NSString *kVMPServerChannelNameKey = @"name";
NSString *kVMPServerChannelPropertiesKey = @"properties";

NSString *kVMPServerChannelTypeVideoTest = @"videoTest";
NSString *kVMPServerChannelTypeAudioTest = @"audioTest";
NSString *kVMPServerChannelTypeV4L2 = @"V4L2";
NSString *kVMPServerChannelTypeALSA = @"ALSA";
NSString *kVMPServerChannelTypeCustom = @"custom";

@implementation VMPServerConfiguration
+ (instancetype)configurationWithPlist:(NSString *)path withError:(NSError **)error {
	return [[VMPServerConfiguration alloc] initWithPlist:path withError:error];
}

- (instancetype)initWithPlist:(NSString *)path withError:(NSError **)error {
	VMP_ASSERT(path, @"Path cannot be nil");

	self = [super init];
	if (self) {
		_configurationPath = path;
		NSDictionary *plist = [NSDictionary dictionaryWithContentsOfFile:path];
		if (!plist) {
			if (error) {
				*error = [NSError errorWithDomain:VMPErrorDomain code:VMPErrorCodeConfigurationError userInfo:nil];
			}
			return nil;
		}

		_rtspPort = plist[kVMPServerRTSPPortKey];
		_rtspAddress = plist[kVMPServerRTSPAddressKey];
		_rtspMountpoints = plist[kVMPServerMountPointsKey];
		_channelConfiguration = plist[kVMPServerChannelConfigurationKey];

		if (!_rtspPort || !_rtspAddress || !_rtspMountpoints || !_channelConfiguration) {
			if (error) {
				*error = [NSError errorWithDomain:VMPErrorDomain code:VMPErrorCodeConfigurationError userInfo:nil];
			}
			return nil;
		}
	}

	return self;
}

@end

@implementation VMPServerMain {
	VMPRTSPServer *_rtspServer;
}

+ (instancetype)serverWithConfiguration:(VMPServerConfiguration *)configuration {
	return [[VMPServerMain alloc] initWithConfiguration:configuration];
}

- (instancetype)initWithConfiguration:(VMPServerConfiguration *)configuration {
	VMP_ASSERT(configuration, @"Configuration cannot be nil");

	self = [super init];
	if (self) {
		_configuration = configuration;
		_rtspServer = [VMPRTSPServer serverWithConfiguration:configuration];
	}

	return self;
}

- (void)iterateMainLoop:(NSTimer *)timer {
	// One iteration of the main loop in the default context. Non-blocking.
	g_main_context_iteration(NULL, FALSE);
}

- (BOOL)runWithError:(NSError **)error {
	// Iterate glib mainloop context with NSTimer (fire every second)
	NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:1.0
													  target:self
													selector:@selector(iterateMainLoop:)
													userInfo:nil
													 repeats:YES];

	NSRunLoop *current = [NSRunLoop currentRunLoop];
	[current addTimer:timer forMode:NSDefaultRunLoopMode];

	if (![_rtspServer startWithError:error]) {
		return NO;
	}

	return YES;
}

@end