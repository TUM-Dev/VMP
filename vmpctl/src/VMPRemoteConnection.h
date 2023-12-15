/* vmpctl - A configuration utility for vmpserverd
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import <Foundation/Foundation.h>

@interface VMPRemoteConnection : NSObject

@property (readonly) NSURL *address;

+ (instancetype)connectionWithAddress:(NSURL *)address
							 username:(NSString *)username
							 password:(NSString *)password;

- (instancetype)initWithAddress:(NSURL *)address
					   username:(NSString *)username
					   password:(NSString *)password;

- (NSDictionary *)configuration:(NSError **)error;

- (NSDictionary *)status:(NSError **)error;

- (NSData *)graphForChannel:(NSString *)channel error:(NSError **)error;

- (NSData *)graphForMountpoint:(NSString *)mountpoint error:(NSError **)error;

@end