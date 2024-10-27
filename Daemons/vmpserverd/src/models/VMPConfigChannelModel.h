/* vmp-server - A virtual multimedia processor
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import <Foundation/Foundation.h>

#import "VMPPropertyListProtocol.h"

/// Channel for capturing V4L2 devices
extern NSString *const VMPConfigChannelTypeV4L2;
/// Channel for capturing from Decklinks
extern NSString *const VMPConfigChannelTypeDecklink;
/// Channel for creating a reproducible video test pattern
extern NSString *const VMPConfigChannelTypeVideoTest;
/// Channel for creating a reproducible audio test tone
extern NSString *const VMPConfigChannelTypeAudioTest;
/// Channel for capturing PulseAudio devices
extern NSString *const VMPConfigChannelTypePulseAudio;

extern NSString *const VMPChannelPropertiesDeviceKey;

/**
	@brief Representation of a single channel

	Channels are used to capture audio and video from
	external sources, and are specified in the profile
	plist files.

	Example:
	<dict>
		<key>name</key>
		<string>present0</string>
		<key>type</key>
		<string>v4l2</string>
		<key>properties</key>
		<dict>
			<key>device</key>
			<string>/dev/video0</string>
		</dict>
	</dict>
*/
@interface VMPConfigChannelModel : NSObject <VMPPropertyListProtocol>

/**
	@brief The name of the channel
*/
@property (nonatomic, strong) NSString *name;

/**
	@brief The type of the channel
*/
@property (nonatomic, strong) NSString *type;

/**
	@brief The properties of the channel

	These properties are specific to the channel type (e.g. "device" for V4L2)
*/
@property (nonatomic, strong) NSDictionary<NSString *, id> *properties;

- (id)initWithPropertyList:(id)propertyList error:(NSError **)error;

- (id)propertyList;

@end