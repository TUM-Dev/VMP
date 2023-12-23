/* CalendarKit - An RFC 5545-compliant calendar library for Objective-C
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import <XCTest/GSXCTestRunner.h>
#import <XCTest/XCTest.h>

#import "Source/ICALParser.h"

#define STR_DATA(str) [str dataUsingEncoding:NSUTF8StringEncoding]

@interface LineUnfoldingTests : XCTestCase
@end

@implementation LineUnfoldingTests {
	NSData *_inputWithoutFolding;
	NSData *_inputWithTABFolding;
	NSData *_inputWithMultiByteFolding;
	NSArray<NSData *> *_expectedWithoutFolding;
	NSArray<NSData *> *_expectedWithTABFolding;
	NSArray<NSData *> *_expectedWithMultiByteFolding;
}

- (void)setUp {
	_inputWithoutFolding = STR_DATA(@"Test\r\nWithout\r\nFolding");
	_expectedWithoutFolding = @[ STR_DATA(@"Test"), STR_DATA(@"Without"), STR_DATA(@"Folding") ];

	_inputWithTABFolding = STR_DATA(@"Test\r\nWith\r\n\t Folding\r\n\r\n");
	_expectedWithTABFolding = @[ STR_DATA(@"Test"), STR_DATA(@"With Folding") ];

	// Earth Globe Europe-Africa U+1F30D with continuation line in-between
	const char byteSeq[] = {0xF0, 0x9F, '\r', '\n', ' ', 0x8C, 0x8D};
	_inputWithMultiByteFolding = [NSData dataWithBytes:byteSeq length:sizeof(byteSeq)];
	_expectedWithMultiByteFolding = @[ STR_DATA(@"🌍") ];
}

- (void)testNoContinuationLines {
	NSArray<NSData *> *unfoldedData;
	unfoldedData = [ICALParser _unfoldData:_inputWithoutFolding];

	XCTAssertNotNil(unfoldedData, @"Returned array is valid");
	XCTAssertEqual([unfoldedData count], 3, @"Count of unfolded lines is correct.");
	XCTAssertEqualObjects(unfoldedData, _expectedWithoutFolding,
						  @"Array of unfolded lines is correct");
}

- (void)testWithTABContinuationLines {
	NSArray<NSData *> *unfoldedData;

	unfoldedData = [ICALParser _unfoldData:_inputWithTABFolding];

	XCTAssertNotNil(unfoldedData, @"Returned array is valid");
	XCTAssertEqual([unfoldedData count], 2, @"Count of unfolded lines is correct.");

	XCTAssertEqualObjects(unfoldedData, _expectedWithTABFolding,
						  @"Array of unfolded lines is correct");
}

- (void)testWithMultiByteContinuationLines {
	NSArray<NSData *> *unfoldedData;

	unfoldedData = [ICALParser _unfoldData:_inputWithMultiByteFolding];

	XCTAssertNotNil(unfoldedData, @"Returned array is valid");
	XCTAssertEqual([unfoldedData count], 1, @"Count of lines is correct.");
	XCTAssertEqual([unfoldedData[0] length], [_expectedWithMultiByteFolding[0] length],
				   @"Lengths are equal.");
	XCTAssertEqualObjects(unfoldedData[0], _expectedWithMultiByteFolding[0], @"Values are equal.");
}

@end

int main(void) {
	BOOL res;
	@autoreleasepool {
		res = [[GSXCTestRunner sharedRunner] runAll];
	}

	return res == YES ? 0 : 1;
}
