/* MicroHTTPKit - A small libmicrohttpd wrapper
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import <Foundation/Foundation.h>

#import <MicroHTTPKit/HKHTTPRequest.h>
#import <MicroHTTPKit/HKRouter.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^HKConnectionLogger)(HKHTTPRequest *req);

// The default logger can be overwritten, by changing this global variable.
extern HKConnectionLogger logger;

@interface HKHTTPServer : NSObject

@property (nonatomic, readonly) NSUInteger port;
@property (readonly) HKRouter *router;

+ (instancetype)serverWithPort:(NSUInteger)port;

- (instancetype)initWithPort:(NSUInteger)port;

- (BOOL)startWithError:(NSError **)error;
- (void)stop;

@end

NS_ASSUME_NONNULL_END
