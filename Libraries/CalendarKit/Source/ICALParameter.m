/* CalendarKit - An ObjC wrapper around libical
 * Copyright (C) 2024 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#include "libical/ical.h"
#import <CalendarKit/ICALParameter.h>

#import "ICALParameter+Private.h"

@implementation ICALParameter (Private)

- (instancetype)initWithHandle:(icalparameter *)handle {
	self = [super init];

	if (self) {
		_handle = icalparameter_new_clone(handle);
	}

	return self;
}

@end

@implementation ICALParameter

- (NSString *)ianaName {
	const char *name = icalparameter_get_iana_name(_handle);
	if (!name) {
		return nil;
	}
	return [NSString stringWithUTF8String:name];
}
- (NSString *)ianaValue {
	const char *value = icalparameter_get_iana_value(_handle);
	if (!value) {
		return nil;
	}
	return [NSString stringWithUTF8String:value];
}

- (NSString *)icalString {
	const char *raw = icalparameter_as_ical_string(_handle);
	return [NSString stringWithUTF8String:raw];
}

- (void)dealloc {
	icalparameter_free(_handle);
}

@end