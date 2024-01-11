/* CalendarKit - An RFC 5545-compliant calendar library for Objective-C
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import <CalendarKit/ICALComponent.h>

#import "ICALComponent+Private.h"

NS_ASSUME_NONNULL_BEGIN

NSString *const ICALComponentTypeCalendar = @"VCALENDAR";
NSString *const ICALComponentTypeEvent = @"VEVENT";
NSString *const ICALComponentTypeTODO = @"VTODO";
NSString *const ICALComponentTypeJournal = @"VJOURNAL";
NSString *const ICALComponentTypeFB = @"VFREEBUSY";
NSString *const ICALComponentTypeTimeZone = @"VTIMEZONE";
NSString *const ICALComponentTypeAlarm = @"VALARM";

NSString *const ICALPropertyValueKey = @"ICALPropertyValueKey";

@implementation ICALComponent

- (instancetype)initWithProperties:(NSDictionary<NSString *, NSDictionary *> *)properties
							  type:(NSString *)type
							 error:(NSError **)error {
	self = [super init];
	if (self) {
		_type = type;
		_properties = [properties copy];
	}

	return self;
}

@end

NS_ASSUME_NONNULL_END
