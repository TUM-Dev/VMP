/* CalendarKit - An ObjC wrapper around libical
 * Copyright (C) 2024 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#include "CalendarKit/ICALComponent.h"
#import <CalendarKit/CalendarKit.h>
#import <XCTest/XCTest.h>

#import "calendars.h"
#import "main.h"

static ICALComponent *parseCalendar(const char *cal) {
	NSData *data = [[NSData alloc] initWithBytes:cal length:strlen(cal)];
	NSError *err = nil;
	return [ICALComponent componentWithData:data error:&err];
}

@interface Time : XCTestCase
@end

@implementation Time

- (void)testSimpleCalendar {
	ICALComponent *component = parseCalendar(SIMPLE_TIME_CALENDAR);
	XCTAssert(component, @"Empty iCalendar was parsed without an error");
	XCTAssert([component kind] == ICALComponentKindVCALENDAR, @"Kind is VCALENDAR");

	// Get children
	__block NSMutableArray<ICALComponent *> *children = [NSMutableArray arrayWithCapacity:2];
	[component
		enumerateComponentsUsingBlock:^(ICALComponent *c, BOOL *stop __attribute__((unused))) {
			[children addObject:c];
		}];
	XCTAssert([children count] == 3, @"Component has three sub components");

	// First event in daylight savings time
	ICALComponent *event = children[1];
	// We expect 2024-10-15T17:30:00+02:00 so 1729006200 in unix time
	// Note that this is still daylight savings time
	NSDate *expected = [NSDate dateWithTimeIntervalSince1970:1729006200];
	XCTAssertEqualObjects(expected, [event startDate],
						  @"Date conversion (daylight savings time) is correct");

	// Second event in standard time
	event = children[2];
	// We expect 2024-11-15T17:30:00+01:00 so 1731688200 in unix time
	// Note that this is still daylight savings time
	expected = [NSDate dateWithTimeIntervalSince1970:1731688200];
	XCTAssertEqualObjects(expected, [event startDate],
						  @"Date conversion (standard time) is correct");
}

@end
