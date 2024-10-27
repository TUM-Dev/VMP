/* CalendarKit - An ObjC wrapper around libical
 * Copyright (C) 2024 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import <libical/icalproperty.h>

#import "CalendarKit/ICALProperty.h"
#import "ICALComponent+Private.h"
#import "ICALParameter+Private.h"
#import "ICALProperty+Private.h"

@implementation ICALProperty

- (NSString *)name {
	const char *propName = icalproperty_get_property_name(_handle);
	return [NSString stringWithUTF8String:propName];
}
- (NSString *)value {
	const char *value = icalproperty_get_value_as_string(_handle);
	return [NSString stringWithUTF8String:value];
}

- (NSInteger)numberOfParameters {
	return icalproperty_count_parameters(_handle);
}

- (void)enumerateParametersUsingBlock:(void (^)(ICALParameter *parameter, BOOL *stop))block {
	icalparameter *cur = icalproperty_get_first_parameter(_handle, ICAL_ANY_PARAMETER);

	BOOL stop = NO;
	while (cur != 0 && stop == NO) {
		ICALParameter *obj = [[ICALParameter alloc] initWithHandle:cur];
		block(obj, &stop);
		cur = icalproperty_get_next_parameter(_handle, ICAL_ANY_PARAMETER);
	}
}

@end

@implementation ICALProperty (Private)

- (instancetype)initWithHandle:(icalproperty *)handle owner:(ICALComponent *)owner {
	self = [super init];

	if (self) {
		_owner = owner;
		_handle = handle;
	}

	return self;
}

@end
