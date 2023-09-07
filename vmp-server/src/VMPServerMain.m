/* vmp-server - A virtual multimedia processor
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import "VMPServerMain.h"

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

@implementation VMPServerConfiguration
+ (instancetype)configurationWithPlist:(NSString *)path withError:(NSError **)error {
	return [[VMPServerConfiguration alloc] initWithPlist:path withError:error];
}

- (instancetype)initWithPlist:(NSString *)path withError:(NSError **)error {
	NSAssert(path, @"Path cannot be nil");

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
	}

	return self;
}

@implementation VMPServerMain

+ (instancetype)serverWithConfiguration:(VMPServerConfiguration *)configuration {
	return [[VMPServerMain alloc] initWithConfiguration:configuration];
}

- (instancetype)initWithConfiguration:(VMPServerConfiguration *)configuration {
	NSAssert(configuration, @"Configuration cannot be nil");

	self = [super init];
	if (self) {
		_configuration = configuration;
	}

	return self;
}

- (BOOL)run {
	return NO;
}
@end