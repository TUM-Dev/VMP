/* MicroHTTPKit - A small libmicrohttpd wrapper
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import "HKHTTPRequest+Private.h"

@implementation HKHTTPRequest (Private)

- (void)appendBytesToHTTPBody:(const void *)bytes length:(NSUInteger)length {
	NSAssert([_HTTPBody isKindOfClass:[NSMutableData class]], @"HTTPBody is not mutable", nil);

	NSMutableData *data = (NSMutableData *) _HTTPBody;
	[data appendBytes:bytes length:length];
}

@end
