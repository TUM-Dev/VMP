/* vmp-server - A virtual multimedia processor
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import <Foundation/Foundation.h>

#import "VMPPropertyListProtocol.h"

@interface VMPProfileModel : NSObject <VMPPropertyListProtocol>

@property (nonatomic, strong) NSString *name;

@property (nonatomic, strong) NSString *identifier;

@property (nonatomic, strong) NSString *version;

@property (nonatomic, strong) NSString *description;

@property (nonatomic, strong) NSArray<NSString *> *supportedPlatforms;

@property (nonatomic, strong) NSDictionary<NSString *, NSString *> *mountpoints;

@property (nonatomic, strong) NSDictionary<NSString *, NSString *> *audioProviders;

@property (nonatomic, strong) NSDictionary<NSString *, NSString *> *channels;

- (id)initWithPropertyList:(id)propertyList error:(NSError **)error;
- (id)propertyList;

@end
