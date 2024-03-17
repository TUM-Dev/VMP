/* MicroHTTPKit - A small libmicrohttpd wrapper
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern const NSString *HKConnectionClientIPKey;
extern const NSString *HKConnectionClientIPVerKey;

@interface HKHTTPRequest : NSObject {
  @private
	NSData *_HTTPBody;
}

@property (copy) NSString *method;
@property (copy) NSURL *URL;
@property (copy) NSDictionary<NSString *, NSString *> *headers;
@property (copy) NSDictionary<NSString *, NSString *> *queryParameters;
@property (copy) NSDictionary *connectionDetails;

/**
 * @brief The user info dictionary for the request.
 *
 * This property is initialized to an empty dictionary, which you can then use to store
 * app-specific information. For example, you might use it during the processing of the
 * request to store processing-related data in the middleware.
 */
@property (copy) NSDictionary *userInfo;

- (instancetype)initWithMethod:(NSString *)method
						   URL:(NSURL *)URL
					   headers:(NSDictionary<NSString *, NSString *> *)headers;

- (instancetype)initWithMethod:(NSString *)method
						   URL:(NSURL *)URL
					   headers:(NSDictionary<NSString *, NSString *> *)headers
			   queryParameters:(NSDictionary<NSString *, NSString *> *)queryParameters;

- (NSData *)HTTPBody;

@end

NS_ASSUME_NONNULL_END
