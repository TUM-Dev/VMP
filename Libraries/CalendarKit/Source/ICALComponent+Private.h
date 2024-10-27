/* CalendarKit - An ObjC wrapper around libical
 * Copyright (C) 2024 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import "CalendarKit/ICALComponent.h"
#import <libical/icalcomponent.h>

@interface ICALComponent (Private)

- (instancetype)initWithHandle:(icalcomponent *)handle;
- (instancetype)initWithHandle:(icalcomponent *)handle root:(ICALComponent *)root;

- (icalcomponent *)handle;

@end
