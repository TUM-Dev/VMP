/* CalendarKit - An ObjC wrapper around libical
 * Copyright (C) 2024 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import <libical/icalparameter.h>

#import <CalendarKit/ICALParameter.h>

NS_ASSUME_NONNULL_BEGIN

@interface ICALParameter (Private)

/**
 * Clone the underlying icalparameter and return an initialised ICALParameter
 * instance.
 */
- (instancetype)initWithHandle:(icalparameter *)handle;

@end

NS_ASSUME_NONNULL_END
