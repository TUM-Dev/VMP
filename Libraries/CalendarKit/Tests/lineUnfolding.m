/* CalendarKit - An RFC 5545-compliant calendar library for Objective-C
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import <XCTest/GSXCTestRunner.h>
#import <XCTest/XCTest.h>

@interface MyTestCase : XCTestCase
@end

@implementation MyTestCase

- (void)testExample {
	XCTAssertEqual(1 + 1, 2, @"Basic arithmetic doesn't seem to work!");
}

@end

int main(void) {
	BOOL res;
	@autoreleasepool {
		res = [[GSXCTestRunner sharedRunner] runAll];
	}

	return res == YES ? 0 : 1;
}
