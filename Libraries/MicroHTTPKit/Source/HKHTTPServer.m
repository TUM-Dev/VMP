/* MicroHTTPKit - A small libmicrohttpd wrapper
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import <MicroHTTPKit/HKHTTPRequest.h>
#import <MicroHTTPKit/HKHTTPServer.h>

// Private headers
#import "HKHTTPRequest+Private.h"

#include <microhttpd.h>

// Private methods for request handling
@interface HKHTTPServer (Private)
- (enum MHD_Result)_sendResponseForRequest:(HKHTTPRequest *)request
								connection:(struct MHD_Connection *)conn
									   URL:(NSURL *)URL
									method:(NSString *)method;
@end

// Our trampoline block type for MHD_KeyValueIterator callbacks
typedef BOOL (^HKKeyValueBlock)(enum MHD_ValueKind kind, NSString *key, NSString *value);

/* A MHD_KeyValueIterator callback that acts as a trampoline to a HKKeyValueBlock,
 * and used by HKConnectionValuesFromBlock to call the HKKeyValueBlock for each key-value pair.
 */
static enum MHD_Result _keyValueTrampoline(void *blockPointer, enum MHD_ValueKind kind,
										   const char *key, const char *value) {
	@autoreleasepool {
		NSString *keyString;
		NSString *valueString;
		HKKeyValueBlock block;

		keyString = [NSString stringWithUTF8String:key];
		valueString = value ? [NSString stringWithUTF8String:value] : @"";
		block = (__bridge HKKeyValueBlock) blockPointer;

		// Call the HKKeyValueBlock
		if (block(kind, keyString, valueString)) {
			return MHD_YES;
		} else {
			return MHD_NO;
		}
	}
}

/* Wrapper around MHD_get_connection_values that calls a HKKeyValueBlock for each key-value pair.
 * Returns MHD_YES if all calls to the HKKeyValueBlock returned YES, otherwise MHD_NO.
 */
int HKConnectionValuesFromBlock(struct MHD_Connection *connection, enum MHD_ValueKind kind,
								HKKeyValueBlock block) {
	return MHD_get_connection_values(connection, kind, _keyValueTrampoline,
									 (__bridge void *) (block));
}

/* A MHD_AccessHandlerCallback to handle new incoming requests.
 * We invoke the HKHTTPServer's _handleRequestForConnection:URL:method: method to handle the
 * request.
 */
static enum MHD_Result accessHandler(void *cls, struct MHD_Connection *connection, const char *url,
									 const char *method,
									 __attribute__((unused)) const char *version,
									 const char *upload_data, size_t *upload_data_size,
									 void **con_cls) {
	@autoreleasepool {
		NSLog(@"Received request for %s %s with body size %lu", method, url, *upload_data_size);
		HKHTTPServer *server;
		HKHTTPRequest *request;

		server = (__bridge HKHTTPServer *) cls;

		if (*con_cls == NULL) {
			NSString *urlString;
			NSString *methodString;
			NSMutableDictionary *headers;
			NSMutableDictionary *queryParameters;

			// This is the first call for this request, so we need to set the connection class
			urlString = [NSString stringWithUTF8String:url];
			methodString = [NSString stringWithUTF8String:method];

			headers = [NSMutableDictionary dictionary];
			queryParameters = [NSMutableDictionary dictionary];

			// Retrieve the headers and query parameters from the connection
			HKConnectionValuesFromBlock(
				connection, MHD_HEADER_KIND,
				^(__attribute__((unused)) enum MHD_ValueKind kind, NSString *key, NSString *value) {
					[headers setObject:value forKey:key];
					return YES;
				});
			HKConnectionValuesFromBlock(
				connection, MHD_GET_ARGUMENT_KIND,
				^(__attribute__((unused)) enum MHD_ValueKind kind, NSString *key, NSString *value) {
					[queryParameters setObject:value forKey:key];
					return YES;
				});

			request = [[HKHTTPRequest alloc] initWithMethod:methodString
														URL:[NSURL URLWithString:urlString]
													headers:headers
											queryParameters:queryParameters];

			// Set the request object as the connection class
			// This is a __bridge_retained cast, so we need to release the object later on
			*con_cls = (__bridge_retained void *) (request);
		} else {
			// This is a subsequent call for this request, so we need to retrieve the request
			// object from the connection class
			request = (__bridge HKHTTPRequest *) (*con_cls);
		}

		// If we have upload data, we need to process it. Otherwise, we can continue
		// processing the request.
		if (*upload_data_size != 0) {
			NSUInteger dataLength;

			NSLog(@"Received %lu bytes of upload data", *upload_data_size);

			dataLength = *upload_data_size;
			[request appendBytesToHTTPBody:upload_data length:dataLength];

			// Tell libmicrohttpd that we processed this portion of data
			*upload_data_size = 0;
			return MHD_YES;
		} else {
			return [server _sendResponseForRequest:request
										connection:connection
											   URL:[request URL]
											method:[request method]];
		}
	}
}

// A MHD_RequestCompletedCallback to release the request object when the request is completed.
static void requestCompletedCallback(__attribute__((unused)) void *cls,
									 __attribute__((unused)) struct MHD_Connection *connection,
									 void **con_cls,
									 __attribute__((unused)) enum MHD_RequestTerminationCode toe) {
	@autoreleasepool {
		if (*con_cls != NULL) {
			// Cast the result to void to indicate to the compiler that we are intentionally
			// ignoring the return value while transferring ownership to ARC.
			(void) (__bridge_transfer HKHTTPRequest *) (*con_cls);
			*con_cls = NULL;
		}
	}
}

@implementation HKHTTPServer {
	struct MHD_Daemon *_daemon;
}

+ (instancetype)serverWithPort:(NSUInteger)port {
	return [[self alloc] initWithPort:port];
}

- (instancetype)initWithPort:(NSUInteger)port {
	self = [super init];
	if (self) {
		_port = port;
		_router = [HKRouter
			routerWithRoutes:@[]
			 notFoundHandler:^HKHTTPResponse *(__attribute__((unused)) HKHTTPRequest *request) {
				 return [HKHTTPResponse responseWithStatus:404];
			 }];
	}
	return self;
}

- (BOOL)startWithError:(NSError **)error {
	_daemon =
		MHD_start_daemon(MHD_USE_AUTO_INTERNAL_THREAD, (unsigned short) _port, NULL, NULL,
						 &accessHandler, (__bridge void *) (self), MHD_OPTION_NOTIFY_COMPLETED,
						 requestCompletedCallback, NULL, MHD_OPTION_END);
	if (!_daemon) {
		if (error) {
			*error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
		}
		return NO;
	}
	return YES;
}

- (void)stop {
	if (_daemon) {
		MHD_stop_daemon(_daemon);
		_daemon = NULL;
	}
}

/*
	Get connection information, and search for a registered handler in the router.
	If a handler is found, execute it and return the result, otherwise execute
	the notFoundHandler.

	This method is called by the requestHandler MHD_AccessHandlerCallback.
*/
- (enum MHD_Result)_sendResponseForRequest:(HKHTTPRequest *)request
								connection:(struct MHD_Connection *)conn
									   URL:(NSURL *)URL
									method:(NSString *)method {
	struct MHD_Response *mhd_response;
	int returnCode;

	HKHTTPResponse *response = nil;
	HKHandlerBlock middlewareHandler = nil;
	NSData *responseData = nil;
	NSDictionary<NSString *, NSString *> *responseHeaders = nil;
	HKHandlerBlock handler = [[self router] handlerForRequest:request];
	middlewareHandler = [[self router] middleware];

	if (!handler) {
		NSLog(@"Could not find handler!");
		handler = [[self router] notFoundHandler];
		response = handler(request);
	} else if (middlewareHandler) {
		response = middlewareHandler(request);
	}

	// If middleware set a response, use it. Otherwise, use the response from the router.
	if (response == nil) {
		// Execute the installed handler block
		response = handler(request);
	}

	responseData = [response data];
	responseHeaders = [response headers];

	// If we have response data, create a response from it. Otherwise, create an empty response.
	if (responseData) {
		// We need to copy the response data, as we do not have direct control over the lifetime
		// of the NSData object.
		mhd_response = MHD_create_response_from_buffer(
			[responseData length], (void *) [responseData bytes], MHD_RESPMEM_MUST_COPY);
		if (!mhd_response) {
			return MHD_NO;
		}
	} else {
		mhd_response = MHD_create_response_from_buffer(0, "", MHD_RESPMEM_PERSISTENT);
	}

	if (responseHeaders) {
		for (NSString *key in [responseHeaders allKeys]) {
			NSString *value = [responseHeaders objectForKey:key];
			MHD_add_response_header(mhd_response, [key UTF8String], [value UTF8String]);
		}
	}

	returnCode = MHD_queue_response(conn, (unsigned int) [response status], mhd_response);
	MHD_destroy_response(mhd_response);
	return returnCode;
}

@end
