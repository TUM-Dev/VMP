/* CalendarKit - An RFC 5545-compliant calendar library for Objective-C
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
	@brief The type of component.

	@see https://tools.ietf.org/html/rfc5545#section-3.6
 */
typedef NS_ENUM(NSUInteger, ICALComponentType) {
	ICALComponentTypeEvent,
	ICALComponentTypeTodo,
	ICALComponentTypeJournal,
	ICALComponentTypeFreeBusy,
	ICALComponentTypeTimezone,
	ICALComponentTypeAlarm,
	ICALComponentTypeUnknown
};

/**
	@brief The base class for all iCalendar components.
*/
@interface ICALComponent : NSObject

/**
	@brief The type of component.

	@see ICALComponentType
 */
@property (readonly) ICALComponentType type;

/**
	@brief Properties of the component.

	Properties of this component as they appear in the iCalendar data.
	This data can be used to parse non-standard properties, such as
	vendor-specific properties.
*/
@property (readonly) NSDictionary<NSString *, NSString *> *properties;

/**
	@brief Subcomponents of the component.

	Subcomponents of this component as they appear in the iCalendar data.
	As known compoents have their own classes, one can introspect
	the type of the subcomponent and cast it to the appropriate class.
*/
@property (readonly) NSArray<ICALComponent *> *subcomponents;

@end

NS_ASSUME_NONNULL_END
