/* vmp-server - A virtual multimedia processor
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import "VMPElementModel.h"
#import "VMPJournal.h"
#import "VMPModelCommon.h"
#include <Foundation/NSArray.h>

#include "gst/gstelement.h"
#include "gst/gstutils.h"

@implementation VMPElementModel

+ (instancetype)modelWithGstElement:(GstElement *)element {
	return [[self alloc] initWithGstElement:element];
}

- (instancetype)initWithGstElement:(GstElement *)element {
	VMP_ASSERT(element, @"element must not be nil");

	self = [super init];
	if (self) {
		gchar *name;
		const gchar *className;
		const gchar *state;

		// Transfer: FULL
		name = gst_element_get_name(element);
		// Transfer: NONE
		state = gst_element_state_get_name(element->current_state);
		// Transfer: NONE
		className = G_OBJECT_TYPE_NAME(element);

		_name = [NSString stringWithUTF8String:name];
		_state = [NSString stringWithUTF8String:state];
		_className = [NSString stringWithUTF8String:className];

		// Object is a bin and has children
		if (GST_IS_BIN(element)) {
			NSMutableArray *childrenArray;
			NSUInteger numberOfChildren;
			GstBin *bin;
			GList *children;

			bin = GST_BIN(element);
			children = bin->children;
			numberOfChildren = (NSUInteger) g_list_length(children);
			childrenArray = [NSMutableArray arrayWithCapacity:numberOfChildren];

			// Iterate over all children in the list and add them to the array
			GList *l;
			for (l = children; l != NULL; l = l->next) {
				GstElement *element;
				VMPElementModel *child;

				element = GST_ELEMENT(l->data);
				child = [VMPElementModel modelWithGstElement:element];

				[childrenArray addObject:child];
			}

			_children = [childrenArray copy];
		} else {
			_children = @[];
		}

		g_free(name);
	}
	return self;
}
- (id)initWithPropertyList:(id)propertyList error:(NSError **)error {
	self = [super init];
	if (self) {
		SET_PROPERTY(_name, @"name");
		SET_PROPERTY(_className, @"className");
		SET_PROPERTY(_state, @"state");
	}
	return self;
}
- (id)propertyList {
	VMP_ASSERT(_name, @"name must not be nil");
	VMP_ASSERT(_className, @"className must not be nil");
	VMP_ASSERT(_state, @"state must not be nil");

	return
		@{@"name" : _name, @"className" : _className, @"state" : _state, @"children" : _children};
}
}

@end