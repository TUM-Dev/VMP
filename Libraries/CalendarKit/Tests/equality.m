/* CalendarKit - An ObjC wrapper around libical
 * Copyright (C) 2024 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import <CalendarKit/CalendarKit.h>
#import <XCTest/XCTest.h>

#import "calendars.h"
#import "main.h"

static ICALComponent *parseCalendar(const char *cal) {
	NSData *data = [[NSData alloc] initWithBytes:cal length:strlen(cal)];
	NSError *err = nil;
	return [ICALComponent componentWithData:data error:&err];
}

@interface Equality : XCTestCase
@end

@implementation Equality

- (void)testSimpleEquality {
	ICALComponent *component = parseCalendar(SIMPLE_EQUALITY_CALENDAR);
	XCTAssert(component, @"Empty iCalendar was parsed without an error");
	XCTAssert([component kind] == ICALComponentKindVCALENDAR, @"Kind is VCALENDAR");

	// Get children
	__block NSMutableArray<ICALComponent *> *children = [NSMutableArray arrayWithCapacity:2];
	[component
		enumerateComponentsUsingBlock:^(ICALComponent *c, BOOL *stop __attribute__((unused))) {
			[children addObject:c];
		}];
	XCTAssert([children count] == 4, @"Component has three sub components");

	XCTAssertEqualObjects(children[2], children[3],
						  @"Last two events are equal (equivalent uid's)");
	XCTAssertNotEqualObjects(children[1], children[2], @"first two events are not equal");
}

@end
