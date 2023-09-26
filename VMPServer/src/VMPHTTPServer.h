/* vmp-server - A virtual multimedia processor
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import <Foundation/Foundation.h>

@interface VMPHTTPURLRequest : NSObject
@property (nonatomic, readonly) NSString *method;
@property (nonatomic, readonly) NSString *path;
@property (nonatomic, readonly) NSDictionary<NSString *, NSString *> *headers;
@property (nonatomic, readonly) NSData *body;
@end

/**
	@brief A very simple HTTP request handler
*/
@protocol VMPHTTPServerHandler <NSObject>
/**
	@brief Handle a HTTP request

	@param request The HTTP request.
	@param response The HTTP response
*/
- (NSHTTPURLResponse *)handleRequest:(NSString *)request;
@end

@interface VMPHTTPServer : NSObject

@property (nonatomic, readonly) NSString *address;
@property (nonatomic, readonly) NSUInteger port;

+ (VMPHTTPServer *)serverWithAddress:(NSString *)address port:(NSUInteger)port;

- (instancetype)initWithAddress:(NSString *)address port:(NSUInteger)port;

- (void)addHandlerForPath:(NSString *)path method:(NSString *)method handler:(id<VMPHTTPServerHandler>)handler;
- (void)addHandlerForPath:(NSString *)path
				   method:(NSString *)method
			responseBlock:(NSHTTPURLResponse * (^)(VMPHTTPURLRequest *) )responseBlock;

- (BOOL)startWithError:(NSError **)error;
@end