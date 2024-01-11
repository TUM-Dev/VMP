/* MicroHTTPKit - A small libmicrohttpd wrapper
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import <MicroHTTPKit/HKRouter.h>

@interface HKRouter ()
@property (nonatomic, readwrite) NSArray<HKRoute *> *routes;
@end

@implementation HKRoute

+ (instancetype)routeWithPath:(NSString *)path
					   method:(NSString *)method
					  handler:(HKHandlerBlock)handler {
	return [[self alloc] initWithPath:path method:method handler:handler];
}

- (instancetype)initWithPath:(NSString *)path
					  method:(NSString *)method
					 handler:(HKHandlerBlock)handler {
	self = [super init];

	if (self) {
		_path = [path copy];
		_handler = [handler copy];
		_method = [method copy];
	}

	return self;
}

@end

@implementation HKRouter {
	NSMutableArray *_routes;
}

+ (instancetype)routerWithRoutes:(NSArray<HKRoute *> *)routes
				 notFoundHandler:(HKHandlerBlock)notFoundHandler {
	return [[self alloc] initWithRoutes:routes notFoundHandler:notFoundHandler];
}

- (instancetype)initWithRoutes:(NSArray<HKRoute *> *)routes
			   notFoundHandler:(HKHandlerBlock)notFoundHandler {
	self = [super init];

	if (self) {
		_routes = [NSMutableArray arrayWithArray:routes];
		_notFoundHandler = [notFoundHandler copy];
	}

	return self;
}

- (HKHandlerBlock)handlerForRequest:(HKHTTPRequest *)request {
	NSString *requestPath;
	requestPath = [[request URL] path];

	for (HKRoute *route in [self routes]) {
		if ([requestPath isEqualToString:[route path]] &&
			[[request method] isEqualToString:[route method]]) {
			return [route handler];
		}
	}

	return [self notFoundHandler];
}

- (void)registerRoute:(HKRoute *)route {
	[_routes addObject:route];
}

- (NSArray<HKRoute *> *)routes {
	return [_routes copy];
}

@end
