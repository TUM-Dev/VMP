/* vmp-server - A virtual multimedia processor
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import <Foundation/Foundation.h>

#include <gst/gst.h>

@interface VMPBinDataHarness : NSObject

+ (instancetype)harnessWithBin:(GstBin *)bin;

- (instancetype)initWithBin:(GstBin *)bin;

@end