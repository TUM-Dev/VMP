/* MicroHTTPKit - A small libmicrohttpd wrapper
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import <MicroHTTPKit/HKHTTPRequest.h>

@interface HKHTTPRequest (Private)

- (void)appendBytesToHTTPBody:(const void *)bytes length:(NSUInteger)length;

@end
