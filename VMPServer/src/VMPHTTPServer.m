/* vmp-server - A virtual multimedia processor
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import "VMPHTTPServer.h"

@implementation VMPHTTPURLRequest
@end

@interface VMPHTTPServer ()
@property (nonatomic, readwrite) NSString *address;
@property (nonatomic, readwrite) NSUInteger port;
@end

@implementation VMPHTTPServer
+ (VMPHTTPServer *)serverWithAddress:(NSString *)address port:(NSUInteger)port {
	return [[VMPHTTPServer alloc] initWithAddress:address port:port];
}

- (instancetype)initWithAddress:(NSString *)address port:(NSUInteger)port {
	self = [super init];
	if (self) {
		_address = address;
		_port = port;
	}

	return self;
}

- (void)addHandlerForPath:(NSString *)path method:(NSString *)method handler:(id<VMPHTTPServerHandler>)handler {
}
- (void)addHandlerForPath:(NSString *)path
				   method:(NSString *)method
			responseBlock:(NSHTTPURLResponse * (^)(VMPHTTPURLRequest *) )responseBlock {
}

- (BOOL)startWithError:(NSError **)error {
	return NO;
}
@end