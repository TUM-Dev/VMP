/* CalendarKit - An RFC 5545-compliant calendar library for Objective-C
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#include "CalendarKit/ICALError.h"
#import <XCTest/XCTest.h>

#import "Source/ICALParser.h"
#import "main.h"

const char *BEGIN = "BEGIN:VCALENDAR";
const char *PRODID = "PRODID:-//CalendarKit//Test//EN";
const char *CATEGORIES = "CATEGORIES:APPOINTMENT,EDUCATION,SOME TEXT";
const char *DTSTART = "DTSTART;TZID=America/New_York:20130802T103400";
const char *QUOTED_PARAM_VALUE = "ATTENDEE;CN=\"Doe, John\":mailto:john.doe@example.com";
const char *MULTIPLE_PARAM_VALUES =
	"ATTENDEE;ROLE=REQ-PARTICIPANT,CHAIR;RSVP=TRUE:mailto:example@example.com";

const char *INVALID_SUMMARY = "SUMMARY;LANGUAGE=de";
const char *INCORRECT_QUOTED_PARAM_VALUE = "ATTENDEE;CN=\"Doe,\" John\":mailto:doe@example.com";
const char *INCORRECT_QUOTED_PARAM_VALUE_2 = "ATTENDEE;CN=\"Doe,\"\" John\":mailto:doe@example.com";

@interface TokenizationTests : XCTestCase
@end

@implementation TokenizationTests

- (void)testEmpty {
	NSData *inputEmpty;
	NSError *error;
	ICALTokenizer *tokenizer;

	inputEmpty = [NSData dataWithBytes:"" length:0];
	tokenizer = [[ICALTokenizer alloc] initWithData:inputEmpty line:1];

	XCTAssertEqual([tokenizer nextTokenWithError:&error], ICALTokenTypeError,
				   @"Tokenizer returns error");
	XCTAssertNotNil(error, @"Error occurred");
	XCTAssertEqual([error code], ICALParserUnexpectedEndOfLineError, @"Error code is correct");
}

- (void)testBEGIN {
	NSData *inputBegin;
	NSError *error;
	ICALTokenizer *tokenizer;

	inputBegin = [NSData dataWithBytes:BEGIN length:strlen(BEGIN)];
	tokenizer = [[ICALTokenizer alloc] initWithData:inputBegin line:1];

	XCTAssertEqual([tokenizer nextTokenWithError:&error], ICALTokenTypeProperty,
				   @"First token is a property");
	XCTAssertEqualObjects([tokenizer stringValue], @"BEGIN", @"First token is BEGIN");
	XCTAssertEqual([tokenizer nextTokenWithError:&error], ICALTokenTypeValue,
				   @"Second token is a value");
	XCTAssertEqualObjects([tokenizer stringValue], @"VCALENDAR", @"Second token is VCALENDAR");
	XCTAssertEqual([tokenizer nextTokenWithError:&error], ICALTokenTypeNone,
				   @"Third token is none");
	XCTAssertNil(error, @"No error occurred");
}

- (void)testPRODID {
	NSData *inputProdId;
	NSError *error;
	ICALTokenizer *tokenizer;

	inputProdId = [NSData dataWithBytes:PRODID length:strlen(PRODID)];
	tokenizer = [[ICALTokenizer alloc] initWithData:inputProdId line:1];

	XCTAssertEqual([tokenizer nextTokenWithError:&error], ICALTokenTypeProperty,
				   @"First token is a property");
	XCTAssertEqualObjects([tokenizer stringValue], @"PRODID", @"First token is PRODID");
	XCTAssertEqual([tokenizer nextTokenWithError:&error], ICALTokenTypeValue,
				   @"Second token is a value");
	XCTAssertEqualObjects([tokenizer stringValue], @"-//CalendarKit//Test//EN",
						  @"Second token is -//CalendarKit//Test//EN");
	XCTAssertEqual([tokenizer nextTokenWithError:&error], ICALTokenTypeNone,
				   @"Third token is none");
	XCTAssertNil(error, @"No error occurred");
}

- (void)testCATEGORIES {
	NSData *inputCategories;
	NSError *error;
	ICALTokenizer *tokenizer;

	inputCategories = [NSData dataWithBytes:CATEGORIES length:strlen(CATEGORIES)];
	tokenizer = [[ICALTokenizer alloc] initWithData:inputCategories line:1];

	XCTAssertEqual([tokenizer nextTokenWithError:&error], ICALTokenTypeProperty,
				   @"First token is a property");
	XCTAssertEqualObjects([tokenizer stringValue], @"CATEGORIES", @"First token is CATEGORIES");
	XCTAssertEqual([tokenizer nextTokenWithError:&error], ICALTokenTypeValue,
				   @"Second token is a value");
	XCTAssertEqualObjects([tokenizer stringValue], @"APPOINTMENT,EDUCATION,SOME TEXT",
						  @"Second token is APPOINTMENT,EDUCATION,SOME TEXT");
	XCTAssertNil(error, @"No error occurred");
}

- (void)testDTSTART {
	NSData *inputDTSTART;
	NSError *error;
	ICALTokenizer *tokenizer;

	inputDTSTART = [NSData dataWithBytes:DTSTART length:strlen(DTSTART)];
	tokenizer = [[ICALTokenizer alloc] initWithData:inputDTSTART line:1];

	XCTAssertEqual([tokenizer nextTokenWithError:&error], ICALTokenTypeProperty,
				   @"First token is a property");
	XCTAssertEqualObjects([tokenizer stringValue], @"DTSTART", @"First token is DTSTART");
	XCTAssertEqual([tokenizer nextTokenWithError:&error], ICALTokenTypeParameter,
				   @"Second token is a parameter");
	XCTAssertEqualObjects([tokenizer stringValue], @"TZID", @"Second token is TZID");
	XCTAssertEqual([tokenizer nextTokenWithError:&error], ICALTokenTypeParameterValue,
				   @"Third token is a parameter value");
	XCTAssertEqualObjects([tokenizer stringValue], @"America/New_York",
						  @"Third token is America/New_York");
	XCTAssertEqual([tokenizer nextTokenWithError:&error], ICALTokenTypeValue,
				   @"Fourth token is a value");
	XCTAssertEqualObjects([tokenizer stringValue], @"20130802T103400",
						  @"Fourth token is 20130802T103400");
	XCTAssertNil(error, @"No error occurred");
}

- (void)testInvalidSUMMARY {
	NSData *inputInvalidSummary;
	NSError *error;
	ICALTokenizer *tokenizer;

	inputInvalidSummary = [NSData dataWithBytes:INVALID_SUMMARY length:strlen(INVALID_SUMMARY)];
	tokenizer = [[ICALTokenizer alloc] initWithData:inputInvalidSummary line:1];

	XCTAssertEqual([tokenizer nextTokenWithError:&error], ICALTokenTypeProperty,
				   @"First token is a property");
	XCTAssertEqualObjects([tokenizer stringValue], @"SUMMARY", @"First token is SUMMARY");
	XCTAssertEqual([tokenizer nextTokenWithError:&error], ICALTokenTypeParameter,
				   @"Second token is a parameter");
	XCTAssertEqualObjects([tokenizer stringValue], @"LANGUAGE", @"Second token is LANGUAGE");
	XCTAssertEqual([tokenizer nextTokenWithError:&error], ICALTokenTypeError,
				   @"Third token is an error");
	XCTAssertNotNil(error, @"Error occurred");

	// Check error
	XCTAssertEqual([error code], ICALParserUnexpectedEndOfLineError, @"Error code is correct");

	NSDictionary *userInfo = [error userInfo];

	XCTAssertEqual(userInfo[ICALParserPositionKey], @((NSUInteger) strlen(INVALID_SUMMARY) - 1),
				   @"Error position is correct");
	XCTAssertEqual(userInfo[ICALParserLineKey], @((NSUInteger) 1), @"Error line is correct");
}

- (void)testQuotedParameterValue {
	NSData *inputQuotedParamValue;
	NSError *error;
	ICALTokenizer *tokenizer;

	inputQuotedParamValue = [NSData dataWithBytes:QUOTED_PARAM_VALUE
										   length:strlen(QUOTED_PARAM_VALUE)];
	tokenizer = [[ICALTokenizer alloc] initWithData:inputQuotedParamValue line:1];

	XCTAssertEqual([tokenizer nextTokenWithError:&error], ICALTokenTypeProperty,
				   @"First token is a property");
	XCTAssertEqualObjects([tokenizer stringValue], @"ATTENDEE", @"First token is ATTENDEE");
	XCTAssertEqual([tokenizer nextTokenWithError:&error], ICALTokenTypeParameter,
				   @"Second token is a parameter");
	XCTAssertEqualObjects([tokenizer stringValue], @"CN", @"Second token is CN");
	XCTAssertEqual([tokenizer nextTokenWithError:&error], ICALTokenTypeQuotedParameterValue,
				   @"Third token is a quoted parameter value");
	XCTAssertEqualObjects([tokenizer stringValue], @"Doe, John", @"Third token is Doe, John");

	XCTAssertEqual([tokenizer nextTokenWithError:&error], ICALTokenTypeValue,
				   @"Fourth token is a value");
	XCTAssertEqualObjects([tokenizer stringValue], @"mailto:john.doe@example.com");
}

- (void)testMultipleParamValues {
	NSData *inputMultipleParamValues;
	NSError *error;
	ICALTokenizer *tokenizer;

	inputMultipleParamValues = [NSData dataWithBytes:MULTIPLE_PARAM_VALUES
											  length:strlen(MULTIPLE_PARAM_VALUES)];
	tokenizer = [[ICALTokenizer alloc] initWithData:inputMultipleParamValues line:1];

	XCTAssertEqual([tokenizer nextTokenWithError:&error], ICALTokenTypeProperty,
				   @"First token is a property");
	XCTAssertEqualObjects([tokenizer stringValue], @"ATTENDEE", @"First token is ATTENDEE");

	XCTAssertEqual([tokenizer nextTokenWithError:&error], ICALTokenTypeParameter,
				   @"Second token is a parameter");
	XCTAssertEqualObjects([tokenizer stringValue], @"ROLE", @"Second token is ROLE");

	XCTAssertEqual([tokenizer nextTokenWithError:&error], ICALTokenTypeParameterValue,
				   @"Third token is a parameter value");
	XCTAssertEqualObjects([tokenizer stringValue], @"REQ-PARTICIPANT",
						  @"Third token is REQ-PARTICIPANT");

	XCTAssertEqual([tokenizer nextTokenWithError:&error], ICALTokenTypeParameterValue,
				   @"fourth token is a parameter value");
	XCTAssertEqualObjects([tokenizer stringValue], @"CHAIR", @"Fourth token is CHAIR");

	XCTAssertEqual([tokenizer nextTokenWithError:&error], ICALTokenTypeParameter,
				   @"Fifth token is a parameter");
	XCTAssertEqualObjects([tokenizer stringValue], @"RSVP", @"Fifth token is RSVP");

	XCTAssertEqual([tokenizer nextTokenWithError:&error], ICALTokenTypeParameterValue,
				   @"Sixth token is a parameter value");
	XCTAssertEqualObjects([tokenizer stringValue], @"TRUE", @"Sixth token is TRUE");

	XCTAssertEqual([tokenizer nextTokenWithError:&error], ICALTokenTypeValue,
				   @"Seventh token is a value");
	XCTAssertEqualObjects([tokenizer stringValue], @"mailto:example@example.com",
						  @"Seventh token is mailto:example@example.com");
}

- (void)testIncorrectQuotedParameterValue {
	NSData *inputIncorrectQuotedParamValue;
	NSError *error;
	ICALTokenizer *tokenizer;

	inputIncorrectQuotedParamValue = [NSData dataWithBytes:INCORRECT_QUOTED_PARAM_VALUE
													length:strlen(INCORRECT_QUOTED_PARAM_VALUE)];
	tokenizer = [[ICALTokenizer alloc] initWithData:inputIncorrectQuotedParamValue line:1];

	XCTAssertEqual([tokenizer nextTokenWithError:&error], ICALTokenTypeProperty,
				   @"First token is a property");
	XCTAssertEqualObjects([tokenizer stringValue], @"ATTENDEE", @"First token is ATTENDEE");
	XCTAssertEqual([tokenizer nextTokenWithError:&error], ICALTokenTypeParameter,
				   @"Second token is a parameter");
	XCTAssertEqualObjects([tokenizer stringValue], @"CN", @"Second token is CN");
	XCTAssertEqual([tokenizer nextTokenWithError:&error], ICALTokenTypeError,
				   @"Third token is an error");
	XCTAssertEqual([error code], ICALParserQuotedStringError, @"Error code is correct");
}

- (void)testIncorrectQuotedParameterValue2 {
	NSData *inputIncorrectQuotedParamValue;
	NSError *error;
	ICALTokenizer *tokenizer;

	inputIncorrectQuotedParamValue = [NSData dataWithBytes:INCORRECT_QUOTED_PARAM_VALUE_2
													length:strlen(INCORRECT_QUOTED_PARAM_VALUE_2)];
	tokenizer = [[ICALTokenizer alloc] initWithData:inputIncorrectQuotedParamValue line:1];

	XCTAssertEqual([tokenizer nextTokenWithError:&error], ICALTokenTypeProperty,
				   @"First token is a property");
	XCTAssertEqualObjects([tokenizer stringValue], @"ATTENDEE", @"First token is ATTENDEE");
	XCTAssertEqual([tokenizer nextTokenWithError:&error], ICALTokenTypeParameter,
				   @"Second token is a parameter");
	XCTAssertEqualObjects([tokenizer stringValue], @"CN", @"Second token is CN");
	XCTAssertEqual([tokenizer nextTokenWithError:&error], ICALTokenTypeError,
				   @"Third token is an error");
	XCTAssertEqual([error code], ICALParserQuotedStringError, @"Error code is correct");
}

@end
