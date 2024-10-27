/* CalendarKit - An ObjC wrapper around libical
 * Copyright (C) 2024 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import <Foundation/NSDictionary.h>
#import <Foundation/NSError.h>
#import <Foundation/NSObjCRuntime.h>
#import <Foundation/NSString.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString *const ICALErrorDomain;

#define ICAL_FAST_ERROR(err, errorCode, description, ...)                                          \
	do {                                                                                           \
		if (err) {                                                                                 \
			NSString *message = [NSString stringWithFormat:description, ##__VA_ARGS__];            \
			*err = [NSError errorWithDomain:ICALErrorDomain                                        \
									   code:errorCode                                              \
								   userInfo:@{NSLocalizedDescriptionKey : message}];               \
		}                                                                                          \
	} while (0)

typedef NS_ENUM(NSUInteger, ICALError) {
	ICALErrorNone = 0,
	ICALErrorBadArgument,
	ICALErrorConstruction,
	ICALErrorAllocation,
	ICALErrorMalformedData,
	ICALErrorParse,
	ICALErrorInternal,
	ICALErrorFile,
	ICALErrorUsage,
	ICALUnimplementedError,
	ICALUnknownError
};

NS_ASSUME_NONNULL_END
