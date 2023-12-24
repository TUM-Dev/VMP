/* CalendarKit - An RFC 5545-compliant calendar library for Objective-C
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import <CalendarKit/ICALComponent.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, ICALTokenType) {
	ICALTokenTypeNone,
	ICALTokenTypeValue,
	ICALTokenTypeParameter,
	ICALTokenTypeParameterValue,
	ICALTokenTypeQuotedParameterValue,
	ICALTokenTypeProperty,
	ICALTokenTypeError
};

/**
 * A tokenizer for RFC 5545 content lines.
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

- (nullable ICALComponent *)parseData:(NSData *)data error:(NSError **)error;

@end

// Methods exposed for testing
@interface ICALParser (Testing)

+ (NSArray<NSData *> *)_unfoldData:(NSData *)data;

@end

NS_ASSUME_NONNULL_END
