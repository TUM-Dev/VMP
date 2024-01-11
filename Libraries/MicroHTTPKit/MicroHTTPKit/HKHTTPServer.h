/* MicroHTTPKit - A small libmicrohttpd wrapper
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import <Foundation/Foundation.h>

#import <MicroHTTPKit/HKRouter.h>

NS_ASSUME_NONNULL_BEGIN

@interface HKHTTPServer : NSObject

@property (nonatomic, readonly) NSUInteger port;
@property (readonly) HKRouter *router;

+ (instancetype)serverWithPort:(NSUInteger)port;

- (instancetype)initWithPort:(NSUInteger)port;

- (BOOL)startWithError:(NSError **)error;
- (void)stop;

@end

NS_ASSUME_NONNULL_END
