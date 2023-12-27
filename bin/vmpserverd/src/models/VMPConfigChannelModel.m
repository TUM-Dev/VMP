/* vmp-server - A virtual multimedia processor
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import "VMPConfigChannelModel.h"
#import "VMPErrors.h"
#import "VMPJournal.h"
#import "VMPModelCommon.h"

NSString *const VMPConfigChannelTypeV4L2 = @"v4l2";
NSString *const VMPConfigChannelTypeVideoTest = @"videoTest";
NSString *const VMPConfigChannelTypeAudioTest = @"audioTest";
NSString *const VMPConfigChannelTypePulseAudio = @"pulse";

NSString *const VMPChannelPropertiesDeviceKey = @"device";

@implementation VMPConfigChannelModel

- (id)initWithPropertyList:(id)propertyList error:(NSError **)error {
	VMP_ASSERT([propertyList isKindOfClass:[NSDictionary class]],
			   @"propertyList is not a dictionary");

	self = [super init];
	if (self) {
		SET_PROPERTY(_name, @"name");
		SET_PROPERTY(_type, @"type");
		SET_PROPERTY(_properties, @"properties");
	}

	return self;
}

- (id)propertyList {
	VMP_ASSERT(_name, @"name is nil");
	VMP_ASSERT(_type, @"type is nil");
	VMP_ASSERT(_properties, @"properties is nil");

	return @{@"name" : _name, @"type" : _type, @"properties" : _properties};
}

@end