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
extern NSString *const kVMPServerMountPointsKey;
extern NSString *const kVMPServerProfileConfigDirKey;
extern NSString *const kVMPServerRTSPPortKey;
extern NSString *const kVMPServerRTSPAddressKey;

extern NSString *const kVMPServerMountPointsPathKey;
extern NSString *const kVMPServerMountPointsTypeKey;
extern NSString *const kVMPServerMountPointsNameKey;

extern NSString *const kVMPServerMountpointTypeSingle;
extern NSString *const kVMPServerMountpointTypeCombined;

// This is the second channel for the combined view (e.g. the camera channel)
extern NSString *const kVMPServerMountpointSecondaryVideoChannelKey;

extern NSString *const kVMPServerMountpointVideoChannelKey;
extern NSString *const kVMPServerMountpointAudioChannelKey;

extern NSString *const kVMPServerChannelConfigurationKey;
extern NSString *const kVMPServerChannelTypeKey;
extern NSString *const kVMPServerChannelNameKey;
extern NSString *const kVMPServerChannelPropertiesKey;

extern NSString *const kVMPServerChannelTypeVideoTest;
extern NSString *const kVMPServerChannelTypeAudioTest;
extern NSString *const kVMPServerChannelTypePulse;
extern NSString *const kVMPServerChannelTypeV4L2;

/**
	@brief Server configuration class

	Configuration values can be be set manually, or by
	reading a property list file.
*/
@interface VMPServerConfiguration : NSObject

/**
	@brief Path to the profile configuration directory
*/
@property (nonatomic, strong) NSString *profileConfigDir;

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
	Configuration independent of the RTSP server is done here.
*/
@interface VMPServerMain : NSObject

@property (nonatomic, readonly) VMPServerConfiguration *configuration;

+ (instancetype)serverWithConfiguration:(VMPServerConfiguration *)configuration
								  error:(NSError **)error;

- (instancetype)initWithConfiguration:(VMPServerConfiguration *)configuration
								error:(NSError **)error;

/**
	@brief Start the server
*/
- (BOOL)runWithError:(NSError **)error;

@end