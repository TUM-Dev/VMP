/* vmpserverd - A virtual multimedia processor
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import <Foundation/NSError.h>
#import <Foundation/NSObject.h>

/**
	@brief A protocol for objects that can be serialized to and from a property list

	@discussion This protocol is used to serialize and deserialize objects to and from a property
   list representation. This means that all objects in the property list representation are
   instances of NSString, NSNumber, NSArray, NSDictionary, or NSNull.

	One can also serialise the property list representation to JSON using NSJSONSerialization.

*/
@protocol VMPPropertyListProtocol <NSObject>

- (id)initWithPropertyList:(id)propertyList error:(NSError **)error;
- (id)propertyList;

@end