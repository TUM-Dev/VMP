/* vmpserverd - A virtual multimedia processor
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import "VMPCalSync.h"

@implementation VMPCalSync

- (instancetype)initWithURL:(NSURL *)url
				  locations:(NSArray<NSString *> *)locations
			 updateInterval:(NSTimeInterval)interval {
	self = [super init];
	if (self) {
		_icalURL = url;
		_updateInterval = interval;
		_locations = [locations copy];
		_events = [NSMutableArray arrayWithCapacity:100];
	}

	return self;
}

@end
