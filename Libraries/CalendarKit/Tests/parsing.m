/* CalendarKit - An ObjC wrapper around libical
 * Copyright (C) 2024 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import <CalendarKit/CalendarKit.h>
#import <XCTest/XCTest.h>

#import "calendars.h"
#import "main.h"

@interface Parsing : XCTestCase
@end

@implementation Parsing

- (void)testEmptyCalendar {
	NSData *data = [[NSData alloc] initWithBytes:EMPTY_CALENDAR length:strlen(EMPTY_CALENDAR)];
	NSError *err = nil;
	ICALComponent *component = [ICALComponent componentWithData:data error:&err];
	XCTAssert(component, @"Empty iCalendar was parsed without an error");
	XCTAssert(nil == err, @"Error was not populated");
	XCTAssert([component kind] == ICALComponentKindVCALENDAR, @"Kind is VCALENDAR");
	XCTAssert(nil == [component uid], @"No uid was found");
	XCTAssert(nil == [component summary], @"No summary was found");
}

- (void)testSimpleCalendar {
	NSData *data = [[NSData alloc] initWithBytes:SIMPLE_CALENDAR length:strlen(SIMPLE_CALENDAR)];
	NSError *err = nil;
	ICALComponent *component = [ICALComponent componentWithData:data error:&err];
	XCTAssert(component, @"Empty iCalendar was parsed without an error");
	XCTAssert(nil == err, @"Error was not populated");
	XCTAssert([component kind] == ICALComponentKindVCALENDAR, @"Kind is VCALENDAR");
	XCTAssertEqualObjects(@"sdfg9438wpwoskegt47817", [component uid],
						  @"Found uid from first VEVENT");
	XCTAssertEqualObjects(@"Enhance your Calm IN0420", [component summary],
						  @"Found summary from first VEVENT");

	__block NSMutableArray<ICALProperty *> *properties = [NSMutableArray arrayWithCapacity:2];
	[component enumeratePropertiesUsingBlock:^(ICALProperty *property,
											   BOOL *stop __attribute__((unused))) {
		[properties addObject:property];
	}];

	XCTAssertEqual([properties count], 2, @"VCALENDAR has two properties");
	XCTAssertEqualObjects(properties[0].name, @"PRODID", @"First property name is correct");
	XCTAssertEqualObjects(properties[1].name, @"VERSION", @"Second property name is correct");
	XCTAssertEqualObjects(properties[0].value, @"Test Calendar",
						  @"First property value is correct");
	XCTAssertEqualObjects(properties[1].value, @"2.0", @"Second property value is correct");

	__block NSMutableArray<ICALComponent *> *children = [NSMutableArray arrayWithCapacity:2];
	[component
		enumerateComponentsUsingBlock:^(ICALComponent *c, BOOL *stop __attribute__((unused))) {
			[children addObject:c];
		}];

	XCTAssert([children count] == 2, @"Component has two sub components");
	XCTAssertEqual(children[0].kind, ICALComponentKindVTIMEZONE, @"First child is VTIMEZONE");
	XCTAssertEqual(children[1].kind, ICALComponentKindVEVENT, @"Second child is VEVENT");
	XCTAssertEqualObjects(children[0].uid, nil, @"First child has no uid");
	XCTAssertEqualObjects(children[1].uid, @"sdfg9438wpwoskegt47817", @"Second child has uid");
	XCTAssertEqualObjects(children[1].summary, @"Enhance your Calm IN0420",
						  @"Second child has uid");

	// Parsing VEVENT properties
	XCTAssertEqual(children[1].numberOfProperties, 7, @"VEVENT has 7 properties");

	properties = [NSMutableArray arrayWithCapacity:7];
	[children[1] enumeratePropertiesUsingBlock:^(ICALProperty *property,
												 BOOL *stop __attribute__((unused))) {
		[properties addObject:property];
	}];
	XCTAssertEqual(properties.count, 7, @"Enumerated 7 properties from VEVENT");

	// Checking property kinds
	NSString *names[] = {@"UID",	  @"DTSTART", @"DTEND",		 @"DTSTAMP",
						 @"LOCATION", @"SUMMARY", @"DESCRIPTION"};
	NSString *values[] = {@"sdfg9438wpwoskegt47817",
						  @"20241015T173000",
						  @"20241015T190000",
						  @"20240903T102623",
						  @"FMI_HS1",
						  @"Enhance your Calm IN0420",
						  @"47817"};
	for (int i = 0; i < 7; i++) {
		XCTAssertEqualObjects(properties[i].name, names[i],
							  @"VEVENT property %ld is of correct kind", i);
		XCTAssertEqualObjects(properties[i].value, values[i],
							  @"VEVENT property %ld is of correct value", i);
	}

	// Parse property parameters
	ICALProperty *dtstart = properties[2];
	XCTAssertEqual(dtstart.numberOfParameters, 1, @"DTSTART has 1 parameter");

	__block NSMutableArray<ICALParameter *> *parameters = [NSMutableArray arrayWithCapacity:1];
	[dtstart enumerateParametersUsingBlock:^(ICALParameter *param, BOOL *stop) {
		[parameters addObject:param];
	}];
	XCTAssertEqual(parameters.count, 1, @"enumerateParametersUsingBlock returned one parameter");
	XCTAssertEqualObjects(parameters[0].icalString, @"TZID=W. Europe Standard Time",
						  @"Parameter pair is correct");
	// XCTAssertEqualObjects(parameters[0].ianaName, @"TZID", @"Parameter of DTSTART is TZID");
	XCTAssertEqualObjects(parameters[0].ianaValue, @"W. Europe Standard Time",
						  @"Parameter of DTSTART has correct value");
}

- (void)testIncompleteCalendar {
	NSData *data = [[NSData alloc] initWithBytes:INCOMPLETE_CALENDAR
										  length:strlen(INCOMPLETE_CALENDAR)];
	NSError *err = nil;
	ICALComponent *component = [ICALComponent componentWithData:data error:&err];
	XCTAssertNil(component, @"Empty iCalendar was parsed with an error");
	XCTAssert(nil != err, @"An Error occurred");
}

@end
