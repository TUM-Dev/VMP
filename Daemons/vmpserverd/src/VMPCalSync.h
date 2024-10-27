/* vmpserverd - A virtual multimedia processor
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>

#import "VMPCalEvent.h"

@interface VMPCalSync : NSObject {
	NSMutableArray<VMPCalEvent *> *_events;
}

@property (readonly) NSURL *icalURL;
@property (readonly) NSTimeInterval updateInterval;
@property (readonly) NSArray<NSString *> *locations;

- (instancetype)initWithURL:(NSURL *)url
				  locations:(NSArray<NSString *> *)locations
			 updateInterval:(NSTimeInterval)interval;

@end
