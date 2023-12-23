/* CalendarKit - An RFC 5545-compliant calendar library for Objective-C
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import <CalendarKit/ICALComponent.h>

NS_ASSUME_NONNULL_BEGIN

@interface ICALParser : NSObject

- (nullable ICALComponent *)parseData:(NSData *)data error:(NSError **)error;

@end

// Methods exposed for testing
@interface ICALParser (Testing)

+ (NSArray<NSData *> *)_unfoldData:(NSData *)data;

@end

NS_ASSUME_NONNULL_END
