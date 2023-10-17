/* vmp-server - A virtual multimedia processor
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import <Foundation/NSError.h>
#import <Foundation/NSObject.h>

@protocol VMPPropertyListProtocol <NSObject>

- (id)initWithPropertyList:(id)propertyList error:(NSError **)error;
- (id)propertyList;

@end