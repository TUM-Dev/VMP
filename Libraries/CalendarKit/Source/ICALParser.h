/* CalendarKit - An RFC 5545-compliant calendar library for Objective-C
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import <CalendarKit/ICALCalendar.h>

NS_ASSUME_NONNULL_BEGIN

/// Bitwise AND with this mask to check if a token is an error
NSUInteger const ICALTokenInvalidMask = 0x1;

/// Bitwise AND with this mask to check if a token is a parameter value
NSUInteger const ICALTokenParameterValueMask = 0x10;

typedef NS_ENUM(NSUInteger, ICALTokenType) {
	ICALTokenTypeNone = 0x1,
	ICALTokenTypeError = 0x2,
	ICALTokenTypeValue = 0x4,
	ICALTokenTypeParameter = 0x8,
	ICALTokenTypeParameterValue = 0x10,
	ICALTokenTypeQuotedParameterValue = 0x20 + 0x10,
	ICALTokenTypeProperty = 0x40
};

/**
 * A tokenizer for RFC 5545 content lines.
 *
 * this class can be used in two ways. You can either
 * create an ICALTokenizer object with data directly
 * (initWithData:line:), or load data after object
 * creation.
 *
 * The latter can be done by sending setData:line:
 * to the object.
 *
 * @see https://tools.ietf.org/html/rfc5545#section-3.1
 */
@interface ICALTokenizer : NSObject

/**
 * @brief Initializes a new tokenizer with a content line.
 *
 * @param data The content line to tokenize.
 *
 * @return The initialized tokenizer.
 */
- (instancetype)initWithData:(NSData *)data line:(NSUInteger)line;

/**
	@brief Initializes a new tokenizer without data

	You can load data using setData:line:.

	@return The initialized tokenizer.
*/
- (instancetype)init;

/**
	@brief Set data and current line

	This resets the state of the tokenizer.
*/
- (void)setData:(NSData *)data line:(NSUInteger)line;

/**
 * @brief Returns the next token type in the content line.
 *
 * @return The next token type in the content line.
 */
- (ICALTokenType)nextTokenWithError:(NSError **)error;

/**
 * @brief Returns the current token in the content line.
 *
 * This method should be called after a call to nextToken.
 * @return The current token in the content line.
 */
- (NSString *)stringValue;

@end

@interface ICALParser : NSObject

+ (instancetype)parserWithData:(NSData *)data;

- (instancetype)initWithData:(NSData *)data;

- (nullable NSArray<ICALComponent *> *)parseWithError:(NSError **)error;

@end

// Methods exposed for testing
@interface ICALParser (Testing)

+ (NSArray<NSData *> *)_unfoldData:(NSData *)data;

@end

NS_ASSUME_NONNULL_END
