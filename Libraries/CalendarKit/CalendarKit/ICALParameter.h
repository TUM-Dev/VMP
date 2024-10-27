/* CalendarKit - An ObjC wrapper around libical
 * Copyright (C) 2024 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import <Foundation/NSObjCRuntime.h>
#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>

NS_ASSUME_NONNULL_BEGIN

@interface ICALParameter : NSObject {
	void *_handle;
}

- (NSString *_Nullable)ianaName;
- (NSString *_Nullable)ianaValue;
- (NSString *)icalString;

@end

NS_ASSUME_NONNULL_END
