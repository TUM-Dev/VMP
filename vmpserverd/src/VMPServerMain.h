/* vmp-server - A virtual multimedia processor
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import <Foundation/Foundation.h>

#import "VMPErrors.h"

/**
	Keys for the configuration property list
 */
extern NSString *kVMPServerMountPointsKey;
extern NSString *kVMPServerRTSPPortKey;
extern NSString *kVMPServerRTSPAddressKey;

extern NSString *kVMPServerMountPointsPathKey;
extern NSString *kVMPServerMountPointsTypeKey;
extern NSString *kVMPServerMountPointsNameKey;

extern NSString *kVMPServerMountpointTypeSingle;
extern NSString *kVMPServerMountpointTypeCombined;

// This is the second channel for the combined view (e.g. the camera channel)
extern NSString *kVMPServerMountpointSecondaryVideoChannelKey;

extern NSString *kVMPServerMountpointVideoChannelKey;
extern NSString *kVMPServerMountpointAudioChannelKey;

extern NSString *kVMPServerChannelConfigurationKey;
extern NSString *kVMPServerChannelTypeKey;
extern NSString *kVMPServerChannelNameKey;
extern NSString *kVMPServerChannelPropertiesKey;

extern NSString *kVMPServerChannelTypeVideoTest;
extern NSString *kVMPServerChannelTypeAudioTest;
extern NSString *kVMPServerChannelTypeV4L2;
extern NSString *kVMPServerChannelTypeALSA;
extern NSString *kVMPServerChannelTypeCustom;

/**
	@brief Server configuration class

	Configuration values can be be set manually, or by
	reading a property list file.
*/
@interface VMPServerConfiguration : NSObject
/**
	@brief Path to the PropertyList configuration file
*/
@property (nonatomic, strong) NSString *configurationPath;

/**
	@brief RTSP server port
*/
@property (nonatomic, strong) NSString *rtspPort;

/**
	@brief RTSP server address

	Configure the RTSP server to accept connections on the given address.
	This is typically either 0.0.0.0 (for allowing external connections), or
	127.0.0.1 (for allowing only local connections).
*/
@property (nonatomic, strong) NSString *rtspAddress;

/**
	@brief RTSP server mountpoints

	Configure the RTSP server to serve the given mountpoints.
	Each mountpoint is a key-value pair, where the key is the mountpoint
	path, and the value is the pipeline channel name.
*/
@property (nonatomic, strong) NSArray *rtspMountpoints;

/**
	@brief Pipeline channel configuration

	Specify the type, name, and properties of each pipeline channel.
*/
@property (nonatomic, strong) NSArray *channelConfiguration;

/**
	@brief Creates a configuration from the property list

	@return A configuration object if parsing was successful. Check for
	the return value and the error object.
*/
+ (instancetype)configurationWithPlist:(NSString *)path withError:(NSError **)error;

- (instancetype)initWithPlist:(NSString *)path withError:(NSError **)error;

@end

/**
	@brief Configures the RTSP server, and HTTP server.

	This class is the main entry point for the server.
*/
@interface VMPServerMain : NSObject

@property (nonatomic, readonly) VMPServerConfiguration *configuration;

+ (instancetype)serverWithConfiguration:(VMPServerConfiguration *)configuration;

- (instancetype)initWithConfiguration:(VMPServerConfiguration *)configuration;

/**
	@brief Start the server
*/
- (BOOL)runWithError:(NSError **)error;

@end