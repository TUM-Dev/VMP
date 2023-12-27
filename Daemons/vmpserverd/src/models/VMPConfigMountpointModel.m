/* vmp-server - A virtual multimedia processor
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import "VMPConfigMountpointModel.h"
#import "VMPErrors.h"
#import "VMPJournal.h"
#import "VMPModelCommon.h"

NSString *const VMPConfigMountpointTypeSingle = @"single";
NSString *const VMPConfigMountpointTypeCombined = @"combined";

@implementation VMPConfigMountpointModel

- (id)initWithPropertyList:(id)propertyList error:(NSError **)error {
	VMP_ASSERT([propertyList isKindOfClass:[NSDictionary class]],
			   @"propertyList is not a dictionary");

	self = [super init];
	if (self) {
		SET_PROPERTY(_name, @"name");
		SET_PROPERTY(_path, @"path");
		SET_PROPERTY(_type, @"type");
		SET_PROPERTY(_properties, @"properties");
	}

	return self;
}

- (id)propertyList {
	VMP_ASSERT(_name, @"name is nil");
	VMP_ASSERT(_path, @"path is nil");
	VMP_ASSERT(_type, @"type is nil");
	VMP_ASSERT(_properties, @"properties is nil");

	return @{@"name" : _name, @"path" : _path, @"type" : _type, @"properties" : _properties};
}

@end