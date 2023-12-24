/* CalendarKit - An RFC 5545-compliant calendar library for Objective-C
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import "main.h"
#import <XCTest/GSXCTestRunner.h>

NSString *resourcePath = @"";

// This is the entrypoint for each unit test
int main(int argc, const char *argv[]) {
	BOOL res;
	@autoreleasepool {
		// Set resource path if provided
		if (argc == 2) {
			resourcePath = [NSString stringWithUTF8String:argv[1]];
		}

		res = [[GSXCTestRunner sharedRunner] runAll];
	}

	return res == YES ? 0 : 1;
}
