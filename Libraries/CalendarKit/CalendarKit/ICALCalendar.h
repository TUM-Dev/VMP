/* CalendarKit - An RFC 5545-compliant calendar library for Objective-C
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import <CalendarKit/ICALEvent.h>
#import <CalendarKit/ICALTimeZone.h>

NS_ASSUME_NONNULL_BEGIN

/**
	@brief The version of the iCalendar specification.

	@see https://tools.ietf.org/html/rfc5545#section-3.7.4
 */
typedef NS_ENUM(NSInteger, ICALCalendarVersion) {
	/// 2.0 corresponds to RFC 5545.
	ICALCalendarVersion2_0
};

/**
	@brief The scale of the calendar.

	@see https://tools.ietf.org/html/rfc5545#section-3.7.1
 */
typedef NS_ENUM(NSInteger, ICALCalendarScale) {
	/// Gregorian calendar scale.
	ICALCalendarScaleGregorian
};

@interface ICALCalendar : ICALComponent

/**
	@brief Parse an iCalendar calendar from data.

	@param data The iCalendar data to parse.
	@param error If an error occurs, upon return contains an NSError object

	@return An ICALCalendar object, or nil if an error occurred.
*/
+ (instancetype)calendarFromData:(NSData *)data error:(NSError **)error;

/**
	@brief Parse an iCalendar calendar from data.

	@param data The iCalendar data to parse.
	@param error If an error occurs, upon return contains an NSError object

	@return An initialised ICALCalendar object, or nil if an error occurred.
*/
- (instancetype)initWithData:(NSData *)data error:(NSError **)error;

/**
	@brief The version of the iCalendar specification.

	@note This property is REQUIRED.

	@see https://tools.ietf.org/html/rfc5545#section-3.7.4
*/
@property (readonly) ICALCalendarVersion version;

/**
	@brief The product identifier of the calendar

	@note This property is REQUIRED.

	@see https://tools.ietf.org/html/rfc5545#section-3.7.3
 */
@property (readonly) NSString *productIdentifier;

/**
	@brief The scale of the calendar.

	@note If no scale is specified, the Gregorian calendar scale is
	assumed.

	@see https://tools.ietf.org/html/rfc5545#section-3.7.1
 */
@property (readonly) ICALCalendarScale scale;

/**
	@brief Events in the calendar.

	An array of all events in the calendar.
*/
@property (readonly) NSArray<ICALEvent *> *events;

@end

NS_ASSUME_NONNULL_END
