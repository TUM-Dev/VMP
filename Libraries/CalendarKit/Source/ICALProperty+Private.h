/* CalendarKit - An ObjC wrapper around libical
 * Copyright (C) 2024 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import <libical/icalproperty.h>

#import "CalendarKit/ICALProperty.h"

@interface ICALProperty (Private)

- (instancetype)initWithHandle:(icalproperty *)handle owner:(ICALComponent *)owner;

@end
