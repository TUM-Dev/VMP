/* CalendarKit - An RFC 5545-compliant calendar library for Objective-C
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import "ICALParser.h"

typedef NS_ENUM(NSUInteger, ICALParserState) { ICALParserStateNone };

NS_ASSUME_NONNULL_BEGIN

@implementation ICALParser

- (nullable ICALComponent *)parseData:(NSData *)data error:(NSError **)error {
	return nil;
}

@end

NS_ASSUME_NONNULL_END
