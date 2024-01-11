/* CalendarKit - An RFC 5545-compliant calendar library for Objective-C
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString *const ICALErrorDomain;

extern NSString *const ICALParserPositionKey;
extern NSString *const ICALParserLineKey;

enum {
	ICALParserControlCharError = 1,
	ICALParserUnexpectedParameterError = 2,
	ICALParserUnexpectedParameterValueError = 3,
	ICALParserUnexpectedPropetyValueSeperatorError = 4,
	ICALParserUnexpectedEndOfLineError = 5,
	ICALParserQuotedStringError = 6,
	ICALObjectParseError = 7,
};

NS_ASSUME_NONNULL_END
