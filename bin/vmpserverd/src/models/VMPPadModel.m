/* vmp-server - A virtual multimedia processor
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import "VMPPadModel.h"
#include "VMPJournal.h"
#include "VMPModelCommon.h"
#include "gst/gstpad.h"

const NSString *VMPPadDirectionSrc = @"src";
const NSString *VMPPadDirectionSink = @"sink";
const NSString *VMPPadDirectionUnknown = @"unknown";

@implementation VMPPadModel

+ (instancetype)modelWithGstPad:(GstPad *)pad {
	return [[self alloc] initWithGstPad:pad];
}

- (instancetype)initWithGstPad:(GstPad *)pad {
	VMP_ASSERT(pad, @"pad must not be nil");

	self = [super init];
	if (self) {
		gchar *name;

		// Transfer: FULL
		name = gst_pad_get_name(pad);

		_name = [NSString stringWithUTF8String:name];

		switch (GST_PAD_DIRECTION(pad)) {
		case GST_PAD_SRC:
			_direction = VMPPadDirectionSrc;
			break;
		case GST_PAD_SINK:
			_direction = VMPPadDirectionSink;
			break;
		default:
			_direction = VMPPadDirectionUnknown;
			break;
		}

		g_free(name);
	}

	return self;
}

- (id)initWithPropertyList:(id)propertyList error:(NSError **)error {
	self = [super init];

	if (self) {
		NSNumber *linked;

		SET_PROPERTY(_name, @"name");
		SET_PROPERTY(_direction, @"direction");
		SET_PROPERTY(linked, @"linked");
		SET_PROPERTY(_linkedElement, @"linkedElement");

		_linked = [linked boolValue];
	}

	return self;
}
- (id)propertyList {
	VMP_ASSERT(_name, @"name must not be nil");
	VMP_ASSERT(_direction, @"direction must not be nil");
	VMP_ASSERT(_linkedElement, @"linkedElement must not be nil");

	return @{
		@"name" : _name,
		@"direction" : _direction,
		@"linked" : @(_linked),
		@"linkedElement" : _linkedElement
	};
}

@end