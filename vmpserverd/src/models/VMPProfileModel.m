/* vmp-server - A virtual multimedia processor
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import "VMPProfileModel.h"
#import "VMPErrors.h"
#import "VMPJournal.h"
#import "VMPModelCommon.h"

@implementation VMPProfileModel
- (id)initWithPropertyList:(id)propertyList error:(NSError **)error {
	VMP_ASSERT([propertyList isKindOfClass:[NSDictionary class]],
			   @"propertyList is not a dictionary");

	self = [super init];
	if (self) {
		SET_PROPERTY(_name, @"name");
		SET_PROPERTY(_identifier, @"identifier");
		SET_PROPERTY(_version, @"version");
		SET_PROPERTY(_description, @"description");
		SET_PROPERTY(_supportedPlatforms, @"supportedPlatforms");
		SET_PROPERTY(_mountpoints, @"mountpoints");
		SET_PROPERTY(_audioProviders, @"audioProviders");
		SET_PROPERTY(_channels, @"channels");
	}

	return self;
}
- (id)propertyList {
	// Check if all properties are set, to avoid returning a partial property list
	VMP_ASSERT(_name, @"name is nil");
	VMP_ASSERT(_identifier, @"identifier is nil");
	VMP_ASSERT(_version, @"version is nil");
	VMP_ASSERT(_description, @"description is nil");
	VMP_ASSERT(_supportedPlatforms, @"supportedPlatforms is nil");
	VMP_ASSERT(_mountpoints, @"mountpoints is nil");
	VMP_ASSERT(_audioProviders, @"audioProviders is nil");
	VMP_ASSERT(_channels, @"channels is nil");

	return @{
		@"name" : _name,
		@"identifier" : _identifier,
		@"version" : _version,
		@"description" : _description,
		@"supportedPlatforms" : _supportedPlatforms,
		@"mountpoints" : _mountpoints,
		@"audioProviders" : _audioProviders,
		@"channels" : _channels
	};
}
@end