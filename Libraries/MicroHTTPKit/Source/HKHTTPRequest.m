/* MicroHTTPKit - A small libmicrohttpd wrapper
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import <MicroHTTPKit/HKHTTPRequest.h>

@implementation HKHTTPRequest

- (instancetype)initWithMethod:(NSString *)method
						   URL:(NSURL *)URL
					   headers:(NSDictionary<NSString *, NSString *> *)headers {
	return [self initWithMethod:method URL:URL headers:headers HTTPBody:nil];
}

// If we don't pass a HTTPBody in the initialiser, we assume that we will append data later on.
// We thus create a mutable data object.
- (instancetype)initWithMethod:(NSString *)method
						   URL:(NSURL *)URL
					   headers:(NSDictionary<NSString *, NSString *> *)headers
			   queryParameters:(NSDictionary<NSString *, NSString *> *)queryParameters {
	self = [self initWithMethod:method URL:URL headers:headers];
	if (self) {
		_queryParameters = [queryParameters copy];
		_HTTPBody = [NSMutableData data];
	}
	return self;
}

- (instancetype)initWithMethod:(NSString *)method
						   URL:(NSURL *)URL
					   headers:(NSDictionary<NSString *, NSString *> *)headers
					  HTTPBody:(nullable NSData *)HTTPBody {
	self = [super init];
	if (self) {
		_method = [method copy];
		_URL = [URL copy];
		_headers = [headers copy];
		_HTTPBody = [HTTPBody copy];
		_userInfo = @{};
	}
	return self;
}

- (NSData *)HTTPBody {
	return [_HTTPBody copy];
}

@end
