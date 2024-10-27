/* CalendarKit - An ObjC wrapper around libical
 * Copyright (C) 2024 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import <Foundation/NSObjCRuntime.h>
#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>

#import <CalendarKit/ICALComponent.h>
#import <CalendarKit/ICALParameter.h>

NS_ASSUME_NONNULL_BEGIN

@interface ICALProperty : NSObject {
	// Strong reference to owner
	ICALComponent *_owner;
	// underlying libical handle. Lifetime tied to owner.
	void *_handle;
}

- (NSString *)name;
- (NSString *)value;

- (NSInteger)numberOfParameters;
- (void)enumerateParametersUsingBlock:(void (^)(ICALParameter *parameter, BOOL *stop))block;

@end

NS_ASSUME_NONNULL_END
