/* vmpserverd - A virtual multimedia processor
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import <Foundation/Foundation.h>

@interface VMPCalEvent : NSObject

@property (nonatomic) NSString *uid;
@property (nonatomic) NSString *summary;
@property (nonatomic) NSString *location;
@property (nonatomic) NSDate *startDate;
@property (nonatomic) NSDate *endDate;
@property BOOL recordingScheduled;

@end
