/* vmpserverd - A virtual multimedia processor
 * Copyright (C) 2024 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import <CalendarKit/CalendarKit.h>
#import <Foundation/Foundation.h>

typedef void (^VMPCalendarNotificationBlock)(ICALComponent *);
typedef BOOL (^VMPCalendarFilterBlock)(ICALComponent *);

/**
 * @brief Synchronises events from an ICAL server in a
 * user-specified time interval based on a list of lecture halls.
 *
 * All VEVENT's in the iCalendar feed have a LOCATION property which
 * features a lecture hall identifier. A configuration dictionary, passed
 * during initialisation of a VMPCalendarSync instance, is used to
 * filter-out unrelated VEVENTs.
 */
@interface VMPCalendarSync : NSObject

/**
 * @brief Synchronisation interval
 */
@property (readonly) NSTimeInterval interval;

@property (readonly) NSTimeInterval notifyBeforeStartThreshold;

/**
 * @brief iCalendar feed URL
 */
@property (readonly) NSURL *url;

/**
 * @brief Called when "notifyBeforeStart" threshold is reached or
 * exceeded. Note that the accuracy currently depends on the sync
 * interval.
 */
@property VMPCalendarNotificationBlock notificationBlock;

/**
 * @brief Called when new events are found in the feed. Callee
 * decides whether the events are added or ignored.
 */
@property VMPCalendarFilterBlock filterBlock;

- (instancetype)initWithURL:(NSURL *)url
				   interval:(NSTimeInterval)interval
		  notifyBeforeStart:(NSTimeInterval)threshold;

@end
