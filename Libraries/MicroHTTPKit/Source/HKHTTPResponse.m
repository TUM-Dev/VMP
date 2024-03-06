/* MicroHTTPKit - A small libmicrohttpd wrapper
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import <MicroHTTPKit/HKHTTPConstants.h>
#import <MicroHTTPKit/HKHTTPResponse.h>

@implementation HKHTTPResponse

+ (instancetype)responseWithStatus:(NSUInteger)status {
	return [[self alloc] initWithStatus:status];
}

+ (instancetype)responseWithData:(NSData *)data status:(NSUInteger)status {
	return [[self alloc] initWithData:data status:status];
}

- (instancetype)initWithStatus:(NSUInteger)status {
	self = [super init];

	if (self) {
		_status = status;
	}

	return self;
}

- (instancetype)initWithData:(NSData *)data status:(NSUInteger)status {
	return [self initWithData:data headers:@{} status:status];
}

- (instancetype)initWithData:(NSData *)data
					 headers:(NSDictionary<NSString *, NSString *> *)headers
					  status:(NSUInteger)status {
	self = [super init];
	if (self) {
		_data = data;
		_headers = headers;
		_status = status;
	}
	return self;
}

@end

@implementation HKHTTPJSONResponse

+ (instancetype)responseWithJSONObject:(id)JSONObject
								status:(NSUInteger)status
								 error:(NSError **)error {
	return [[self alloc] initWithJSONObject:JSONObject status:status error:error];
}

+ (instancetype)responseWithJSONObject:(id)JSONObject
								status:(NSUInteger)status
							   headers:(NSDictionary<NSString *, NSString *> *)headers
								 error:(NSError **)error {
	NSData *data;
	data = [NSJSONSerialization dataWithJSONObject:JSONObject options:0 error:error];

	return [[self alloc] initWithData:data headers:headers status:status];
}

- (instancetype)initWithJSONObject:(id)JSONObject
							status:(NSUInteger)status
							 error:(NSError **)error {
	NSData *data;
	NSDictionary *headers;

	headers = @{HKHTTPHeaderContentType : HKHTTPHeaderContentApplicationJSON};
	data = [NSJSONSerialization dataWithJSONObject:JSONObject options:0 error:error];

	return [self initWithData:data headers:headers status:status];
}

@end
