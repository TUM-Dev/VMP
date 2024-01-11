/* CalendarKit - An RFC 5545-compliant calendar library for Objective-C
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString *const ICALComponentTypeCalendar;
extern NSString *const ICALComponentTypeEvent;
extern NSString *const ICALComponentTypeTODO;
extern NSString *const ICALComponentTypeJournal;
extern NSString *const ICALComponentTypeFB;
extern NSString *const ICALComponentTypeTimeZone;
extern NSString *const ICALComponentTypeAlarm;

extern NSString *const ICALPropertyValueKey;

/**
	@brief The base class for all iCalendar components.
*/
@interface ICALComponent : NSObject

/**
	@brief ICALComponent initialiser

	@param properties Component properties
	@param type The type of component
	@param error Can be used by subclasses to indicate an error

	@returns an initialised ICALComponent object
*/
- (instancetype)initWithProperties:(NSDictionary<NSString *, NSDictionary *> *)properties
							  type:(NSString *)type
							 error:(NSError **)error NS_DESIGNATED_INITIALIZER;

/**
	@brief The type of component.

	@see ICALComponentType
 */
@property (readonly) NSString *type;

/**
	@brief Properties of the component.

	Properties of this component as they appear in the iCalendar data.
	This data can be used to parse non-standard properties, such as
	vendor-specific properties.

	The key of the dictionary is the name of the property, the value
	is a dictionary containing the parameters of the property.
*/
@property (copy) NSDictionary<NSString *, NSDictionary *> *properties;

@end

NS_ASSUME_NONNULL_END
