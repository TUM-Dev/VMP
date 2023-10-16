/* vmp-server - A virtual multimedia processor
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import "VMPConfigModel.h"
#import "VMPJournal.h"
#import "VMPModelCommon.h"

@implementation VMPConfigModel

- (id)initWithPropertyList:(id)propertyList error:(NSError **)error {
	VMP_ASSERT([propertyList isKindOfClass:[NSDictionary class]],
			   @"propertyList is not a dictionary");

	self = [super init];
	if (self) {
		SET_PROPERTY(_name, @"name");
		SET_PROPERTY(_profileDirectory, @"profileDirectory");
		SET_PROPERTY(_rtspAddress, @"rtspAddress");
		SET_PROPERTY(_rtspPort, @"rtspPort");
		SET_PROPERTY(_mountpoints, @"mountpoints");
		SET_PROPERTY(_channels, @"channels");
	}

	return self;
}

- (id)propertyList {
	VMP_ASSERT(_name, @"name is nil");
	VMP_ASSERT(_profileDirectory, @"profileDirectory is nil");
	VMP_ASSERT(_rtspAddress, @"rtspAddress is nil");
	VMP_ASSERT(_rtspPort, @"rtspPort is nil");
	VMP_ASSERT(_mountpoints, @"mountpoints is nil");
	VMP_ASSERT(_channels, @"channels is nil");

	return @{
		@"name" : _name,
		@"profileDirectory" : _profileDirectory,
		@"rtspAddress" : _rtspAddress,
		@"rtspPort" : _rtspPort,
		@"mountpoints" : _mountpoints,
		@"channels" : _channels
	};
}

@end