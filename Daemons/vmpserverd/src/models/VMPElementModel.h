/* vmpserverd - A virtual multimedia processor
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import <Foundation/NSArray.h>
#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>

#include <gst/gstelement.h>

#import "VMPPropertyListProtocol.h"

@interface VMPElementModel : NSObject <VMPPropertyListProtocol>

@property (nonatomic, strong) NSString *name;

@property (nonatomic, strong) NSString *className;

@property (nonatomic, strong) NSString *state;

@property (nonatomic, strong) NSArray<VMPElementModel *> *children;

+ (instancetype)modelWithGstElement:(GstElement *)element;

- (instancetype)initWithGstElement:(GstElement *)element;
- (id)initWithPropertyList:(id)propertyList error:(NSError **)error;
- (id)propertyList;

@end