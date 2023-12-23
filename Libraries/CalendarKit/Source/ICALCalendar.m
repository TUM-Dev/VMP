/* CalendarKit - An RFC 5545-compliant calendar library for Objective-C
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import <CalendarKit/ICALCalendar.h>

NS_ASSUME_NONNULL_BEGIN

@implementation ICALCalendar : ICALComponent

+ (instancetype)calendarFromData:(NSData *)data error:(NSError **)error {
	return [[self alloc] initWithData:data error:error];
}

- (instancetype)initWithData:(NSData *)data error:(NSError **)error {
	if (self = [super init]) {
	}
	return self;
}

@end

NS_ASSUME_NONNULL_END
