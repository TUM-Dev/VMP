/* vmpserverd - A virtual multimedia processor
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import <Foundation/Foundation.h>

#import "VMPPropertyListProtocol.h"

extern NSString *const VMPConfigMountpointTypeSingle;
extern NSString *const VMPConfigMountpointTypeCombined;

@interface VMPConfigMountpointModel : NSObject <VMPPropertyListProtocol>

@property (nonatomic, strong) NSString *name;

@property (nonatomic, strong) NSString *path;

@property (nonatomic, strong) NSString *type;

@property (nonatomic, strong) NSDictionary<NSString *, id> *properties;

- (id)initWithPropertyList:(id)propertyList error:(NSError **)error;

- (id)propertyList;

@end