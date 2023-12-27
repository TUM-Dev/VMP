/* vmp-server - A virtual multimedia processor
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import "VMPPropertyListProtocol.h"
#import <Foundation/Foundation.h>

#include <gst/gstpad.h>

extern NSString *VMPPadDirectionSrc;
extern NSString *VMPPadDirectionSink;
extern NSString *VMPPadDirectionUnknown;

@interface VMPPadModel : NSObject <VMPPropertyListProtocol>

@property (nonatomic, strong) NSString *name;

@property (nonatomic, strong) NSString *direction;

@property (nonatomic, assign) BOOL linked;

/**
	@brief The name of the element that this pad is linked to

	@note You can assume that this element is in the same bin
	as the element that this pad belongs to
*/
@property (nonatomic, strong) NSString *linkedElement;

+ (instancetype)modelWithGstPad:(GstPad *)pad;

- (instancetype)initWithGstPad:(GstPad *)pad;

- (id)initWithPropertyList:(id)propertyList error:(NSError **)error;
- (id)propertyList;

@end