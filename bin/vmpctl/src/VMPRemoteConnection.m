/* vmpctl - A configuration utility for vmpserverd
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import "VMPRemoteConnection.h"
#include <Foundation/NSURL.h>

@interface NSURL (QueryAdditions)

- (NSURL *)URLByAppendingPathComponent:(NSString *)pathComponent
							queryItems:(NSArray<NSURLQueryItem *> *)queryItems;

@end

@implementation NSURL (QueryAdditions)

- (NSURL *)URLByAppendingPathComponent:(NSString *)pathComponent
							queryItems:(NSArray<NSURLQueryItem *> *)queryItems {
	NSURLComponents *components;
	NSString *path;

	components = [NSURLComponents componentsWithURL:self resolvingAgainstBaseURL:NO];
	path = [components path];

	[components setPath:[path stringByAppendingPathComponent:pathComponent]];
	[components setQueryItems:queryItems];
	return [components URL];
}

@end

@implementation VMPRemoteConnection {
	NSURL *_address;
}

NSString *const VMPAPIPath = @"api/v1";

+ (instancetype)connectionWithAddress:(NSURL *)address
							 username:(NSString *)username
							 password:(NSString *)password {
	return [[self alloc] initWithAddress:address username:username password:password];
}

- (instancetype)initWithAddress:(NSURL *)address
					   username:(NSString *)username
					   password:(NSString *)password {
	self = [super init];

	if (self) {
		// TODO: As we have yet to implement HTTP basic auth in vmpserverd, we
		// will skip setting up the authentication handler for now.
		_address = [address URLByAppendingPathComponent:VMPAPIPath];
	}

	return self;
}

// Helper method to send a request to the server.
- (NSData *)_sendRequest:(NSURL *)url error:(NSError **)error {
	NSURLRequest *request;
	NSURLResponse *response;
	NSData *data;

	request = [NSURLRequest requestWithURL:url];

	data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:error];
	if (!data) {
		NSLog(@"Failed to send request to %@ with error %@", url, [*error localizedDescription]);
		return nil;
	}

	if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
		NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *) response;

		NSLog(@"HTTP response status code: %ld", (long) [httpResponse statusCode]);
	}

	return data;
}

- (NSDictionary *)configuration:(NSError **)error {
	NSURL *url;
	NSData *data;

	url = [_address URLByAppendingPathComponent:@"config"];
	data = [self _sendRequest:url error:error];
	if (!data) {
		return nil;
	}

	return [NSJSONSerialization JSONObjectWithData:data options:0 error:error];
}

- (NSDictionary *)status:(NSError **)error {
	NSURL *url;
	NSData *data;

	url = [_address URLByAppendingPathComponent:@"status"];
	data = [self _sendRequest:url error:error];
	if (!data) {
		return nil;
	}

	return [NSJSONSerialization JSONObjectWithData:data options:0 error:error];
}

- (NSData *)graphForChannel:(NSString *)channel error:(NSError **)error {
	NSURL *url;
	NSURLQueryItem *queryItem;

	queryItem = [NSURLQueryItem queryItemWithName:@"channel" value:channel];
	url = [_address URLByAppendingPathComponent:@"channel/graph" queryItems:@[ queryItem ]];

	return [self _sendRequest:url error:error];
}

- (NSData *)graphForMountpoint:(NSString *)mountpoint error:(NSError **)error {
	NSURL *url;
	NSURLQueryItem *queryItem;

	queryItem = [NSURLQueryItem queryItemWithName:@"mountpoint" value:mountpoint];
	url = [_address URLByAppendingPathComponent:@"mountpoint/graph" queryItems:@[ queryItem ]];

	return [self _sendRequest:url error:error];
}

@end