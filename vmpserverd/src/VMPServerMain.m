/* vmp-server - A virtual multimedia processor
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import "VMPServerMain.h"
#import "VMPJournal.h"
#import "VMPProfile.h"
#import "VMPRTSPServer.h"

#import <glib.h>

/**
	Keys for the configuration plist

	You can see an example of the configuration file in the
	vmpserverd project directory.
 */
NSString *const kVMPServerMountPointsKey = @"mountpoints";
NSString *const kVMPServerProfileConfigDirKey = @"profileConfigDir";
NSString *const kVMPServerRTSPPortKey = @"rtspPort";
NSString *const kVMPServerRTSPAddressKey = @"rtspAddress";

NSString *const kVMPServerMountPointsPathKey = @"path";
NSString *const kVMPServerMountPointsTypeKey = @"type";
NSString *const kVMPServerMountPointsNameKey = @"name";

NSString *const kVMPServerMountpointTypeSingle = @"single";
NSString *const kVMPServerMountpointTypeCombined = @"combined";

NSString *const kVMPServerMountpointVideoChannelKey = @"videoChannel";
NSString *const kVMPServerMountpointSecondaryVideoChannelKey = @"secondaryVideoChannel";
NSString *const kVMPServerMountpointAudioChannelKey = @"audioChannel";

NSString *const kVMPServerChannelConfigurationKey = @"channelConfiguration";
NSString *const kVMPServerChannelTypeKey = @"type";
NSString *const kVMPServerChannelNameKey = @"name";
NSString *const kVMPServerChannelPropertiesKey = @"properties";

NSString *const kVMPServerChannelTypeVideoTest = @"videoTest";
NSString *const kVMPServerChannelTypeAudioTest = @"audioTest";
NSString *const kVMPServerChannelTypePulse = @"pulse";
NSString *const kVMPServerChannelTypeV4L2 = @"v4l2";

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
				*error = [NSError errorWithDomain:VMPErrorDomain
											 code:VMPErrorCodeConfigurationError
										 userInfo:nil];
			}
			return nil;
		}

		_profileConfigDir = plist[kVMPServerProfileConfigDirKey];
		_rtspPort = plist[kVMPServerRTSPPortKey];
		_rtspAddress = plist[kVMPServerRTSPAddressKey];
		_rtspMountpoints = plist[kVMPServerMountPointsKey];
		_channelConfiguration = plist[kVMPServerChannelConfigurationKey];

		if (!_profileConfigDir || !_rtspPort || !_rtspAddress || !_rtspMountpoints
			|| !_channelConfiguration) {
			if (error) {
				*error = [NSError errorWithDomain:VMPErrorDomain
											 code:VMPErrorCodeConfigurationError
										 userInfo:nil];
			}
			return nil;
		}
	}

	return self;
}

@end

@implementation VMPServerMain {
	VMPRTSPServer *_rtspServer;
	VMPProfileManager *_profileMgr;
}

+ (instancetype)serverWithConfiguration:(VMPServerConfiguration *)configuration
								  error:(NSError **)error {
	return [[VMPServerMain alloc] initWithConfiguration:configuration error:error];
}

- (instancetype)initWithConfiguration:(VMPServerConfiguration *)configuration
								error:(NSError **)error {
	VMP_ASSERT(configuration, @"Configuration cannot be nil");

	self = [super init];
	if (self) {
		_configuration = configuration;
		_profileMgr = [VMPProfileManager managerWithPath:[configuration profileConfigDir]
												   error:error];
		if (!_profileMgr) {
			return nil;
		}
		_rtspServer = [VMPRTSPServer serverWithConfiguration:configuration
													 profile:[_profileMgr currentProfile]];
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