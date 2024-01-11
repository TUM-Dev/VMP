/* MicroHTTPKit - A small libmicrohttpd wrapper
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import <MicroHTTPKit/MicroHTTPKit.h>
#import <XCTest/XCTest.h>

#import "main.h"

static const NSString *REQUEST_BODY_STRING = @"Hello, World!";
static const NSString *RESPONSE_STRING = @"Received!";

@interface Routing : XCTestCase
+ (NSData *)_sendRequest:(NSURL *)url response:(NSHTTPURLResponse **)resp error:(NSError **)error;
@end

@implementation Routing

+ (NSData *)_sendRequest:(NSURL *)url response:(NSHTTPURLResponse **)resp error:(NSError **)error {
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
		*resp = httpResponse;

		NSLog(@"HTTP response status code: %ld", (long) [httpResponse statusCode]);
	}

	return data;
}

- (void)testRouteGET {
	HKHTTPServer *server;
	HKRoute *route;
	NSError *error = NULL;
	NSURL *url;
	NSData *data;
	NSHTTPURLResponse *responseObj = nil;

	server = [[HKHTTPServer alloc] initWithPort:8080];
	XCTAssertNotNil(server, @"Server is valid");

	route = [HKRoute
		routeWithPath:@"/test"
			   method:HKHTTPMethodGET
			  handler:^(HKHTTPRequest *request) {
				  XCTAssertNotNil(request, @"Handler called with valid HKHTTPRequest");
				  XCTAssertNotNil([request method], @"Method property in request is valid");
				  XCTAssertNotNil([request URL], @"URL property in request is valid");

				  XCTAssertEqualObjects([request method], HKHTTPMethodGET, @"Is a GET request");

				  return [HKHTTPResponse
					  responseWithData:[RESPONSE_STRING dataUsingEncoding:NSUTF8StringEncoding]
								status:200];
			  }];
	XCTAssertNotNil(route, @"route is valid");

	[[server router] registerRoute:route];

	NSArray *routes = [[server router] routes];
	XCTAssertNotNil(routes, @"Routes are valid");
	XCTAssertEqual([routes count], 1, @"Routes count is 1");
	XCTAssertEqualObjects([routes objectAtIndex:0], route, @"Routes are equal");

	XCTAssertTrue([server startWithError:&error], @"Server started successfully");
	XCTAssert(!error, @"Server started without error");

	// Simple GET request
	url = [NSURL URLWithString:@"http://localhost:8080/test"];
	data = [Routing _sendRequest:url response:&responseObj error:&error];
	XCTAssertNotNil(data, @"Response data is valid");
	XCTAssert(!error, @"Request sent without error");
	XCTAssertNotNil(responseObj, @"Response object is valid");
	XCTAssertEqual([responseObj statusCode], 200, @"HTTP status code is 200");

	NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	XCTAssertEqualObjects(str, RESPONSE_STRING, @"Response data is valid");

	// Testing the default not-found handler
	url = [NSURL URLWithString:@"http://localhost:8080/invalid"];
	data = [Routing _sendRequest:url response:&responseObj error:&error];
	XCTAssertNotNil(data, @"Response data is valid");
	XCTAssert(!error, @"Request sent without error");
	XCTAssertNotNil(responseObj, @"Response object is valid");
	XCTAssertEqual([responseObj statusCode], 404, @"HTTP status code is 404");

	[server stop];
}

- (void)testPOST {
	HKHTTPServer *server;
	HKRoute *route;
	NSError *error = NULL;
	NSURL *url;
	NSData *data;
	NSHTTPURLResponse *responseObj = nil;

	server = [[HKHTTPServer alloc] initWithPort:8080];
	XCTAssertNotNil(server, @"Server is valid");

	route = [HKRoute
		routeWithPath:@"/test"
			   method:HKHTTPMethodPOST
			  handler:^(HKHTTPRequest *request) {
				  XCTAssertNotNil(request, @"Handler called with valid HKHTTPRequest");
				  XCTAssertNotNil([request method], @"Method property in request is valid");
				  XCTAssertNotNil([request URL], @"URL property in request is valid");

				  XCTAssertEqualObjects([request method], HKHTTPMethodPOST, @"Is a POST request");

				  NSData *data = [request HTTPBody];
				  NSString *body = [[NSString alloc] initWithData:data
														 encoding:NSUTF8StringEncoding];

				  XCTAssertNotNil(data, @"Body data is valid");
				  // FIXME: We need to implement a post-processor in HKHTTPServer.m for the body
				  // data to be correctly passed

				  return [HKHTTPResponse
					  responseWithData:[RESPONSE_STRING dataUsingEncoding:NSUTF8StringEncoding]
								status:200];
			  }];
	XCTAssertNotNil(route, @"route is valid");

	[[server router] registerRoute:route];

	NSArray *routes = [[server router] routes];
	XCTAssertNotNil(routes, @"Routes are valid");
	XCTAssertEqual([routes count], 1, @"Routes count is 1");
	XCTAssertEqualObjects([routes objectAtIndex:0], route, @"Routes are equal");

	XCTAssertTrue([server startWithError:&error], @"Server started successfully");
	XCTAssert(!error, @"Server started without error");

	// Simple POST request
	url = [NSURL URLWithString:@"http://localhost:8080/test"];
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
	[request setHTTPMethod:@"POST"];
	[request setHTTPBody:[REQUEST_BODY_STRING dataUsingEncoding:NSUTF8StringEncoding]];

	data = [NSURLConnection sendSynchronousRequest:request
								 returningResponse:&responseObj
											 error:&error];
	XCTAssertNotNil(data, @"Response data is valid");
	XCTAssert(!error, @"Request sent without error");
	XCTAssertNotNil(responseObj, @"Response object is valid");
	XCTAssertEqual([responseObj statusCode], 200, @"HTTP status code is 200");

	NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	XCTAssertNotNil(str, @"String from response data is valid");
	XCTAssertEqualObjects(str, RESPONSE_STRING, @"Response data is valid");
}

- (void)testMiddleware {
	HKHTTPServer *server;
	NSHTTPURLResponse *responseObj;
	NSError *error = NULL;

	server = [[HKHTTPServer alloc] initWithPort:8081];
	XCTAssertNotNil(server, @"Server is valid");

	[[server router] setMiddleware:^HKHTTPResponse *(HKHTTPRequest *request) {
		NSDictionary *response;
		NSError *error = NULL;
		HKHTTPJSONResponse *responseObj;
		XCTAssertNotNil(request, @"Request to middleware is valid");

		response = @{
			@"method" : [request method],
			@"url" : [[request URL] absoluteString],
			@"headers" : [request headers],
			@"queryParameters" : [request queryParameters]
		};

		responseObj = [HKHTTPJSONResponse responseWithJSONObject:response status:200 error:&error];
		XCTAssertNotNil(responseObj, @"Response object is valid");
		XCTAssert(!error, @"Response object created without error");

		return responseObj;
	}];

	XCTAssertTrue([server startWithError:NULL], @"Server started successfully");

	// Simple GET request
	NSURL *url = [NSURL URLWithString:@"http://localhost:8081/middlewareTest"];
	NSData *data = [Routing _sendRequest:url response:&responseObj error:&error];
	XCTAssertNotNil(data, @"Response data is valid");
	XCTAssert(!error, @"Request sent without error");

	NSDictionary *response = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
	XCTAssertNotNil(response, @"Response data is valid");
	XCTAssert(!error, @"Response data is valid");

	XCTAssertEqual([responseObj statusCode], 200, @"HTTP status code is 200");
	XCTAssertEqualObjects([response objectForKey:@"method"], @"GET", @"Method is GET");
	XCTAssertEqualObjects([response objectForKey:@"url"], @"/middlewareTest",
						  @"URL is /middlewareTest");
	XCTAssertEqualObjects([response objectForKey:@"queryParameters"], @{},
						  @"Query parameters are empty");

	// Simple GET Request with additional headers and query parameters

	NSURLResponse *rawURLResponse;

	url = [NSURL URLWithString:@"http://localhost:8081/middlewareTest?foo=bar"];
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
	[request setValue:@"application/json" forHTTPHeaderField:@"Accept"];

	data = [NSURLConnection sendSynchronousRequest:request
								 returningResponse:&rawURLResponse
											 error:&error];
	XCTAssertNotNil(data, @"Response data is valid");
	XCTAssert(!error, @"Request sent without error");

	response = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
	XCTAssertNotNil(response, @"Response data is valid");
	XCTAssert(!error, @"Response data is valid");

	XCTAssertEqual([responseObj statusCode], 200, @"HTTP status code is 200");
	XCTAssertEqualObjects([response objectForKey:@"method"], @"GET", @"Method is GET");
	XCTAssertEqualObjects([response objectForKey:@"url"], @"/middlewareTest",
						  @"URL is /middlewareTest");
	XCTAssertEqualObjects([response objectForKey:@"queryParameters"], @{@"foo" : @"bar"},
						  @"Query parameters are foo=bar");
	XCTAssertGreaterThan([[response objectForKey:@"headers"] count], 0, @"Headers are not empty");
	XCTAssertEqualObjects([[response objectForKey:@"headers"] objectForKey:@"Accept"],
						  @"application/json", @"Accept header is application/json");

	[server stop];
}

@end
