/* CalendarKit - An RFC 5545-compliant calendar library for Objective-C
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */
#import <stdint.h>

#import "ICALParser.h"

NS_ASSUME_NONNULL_BEGIN

@implementation ICALTokenizer {
	NSData *_data;
	NSUInteger _position;
	NSUInteger _lastPosition;
	BOOL _inQuotedString;
	ICALTokenType _state;
}

- (instancetype)initWithData:(NSData *)data {
	self = [super init];

	if (self) {
		_data = data;
		_position = 0;
		_lastPosition = 0;
		_inQuotedString = NO;
		_state = ICALTokenTypeNone;
	}

	return self;
}

- (ICALTokenType)nextToken {
	if (_state == ICALTokenTypeValue) {
		return ICALTokenTypeNone;
	}

	const uint8_t *bytes;
	NSUInteger length;

	bytes = [_data bytes];
	length = [_data length];

	_lastPosition = _position;

	while (_position < length) {
		const uint8_t c = bytes[_position];
		_position++;

		if (_inQuotedString) {
			if (c == '"') {
				_inQuotedString = NO;
			}
			continue;
		}

		switch (c) {
		case '"':
			_inQuotedString = YES;
			break;
		case ':': // Transition to value state
			_state = ICALTokenTypeValue;
			return ICALTokenTypeProperty;
		case ';': // Parameter seperator. Transition to parameter state
			_state = ICALTokenTypeParameter;
			return ICALTokenTypeParameter;
		case ',': // Parameter Value seperator. Stay until transition to value state
			if (_state == ICALTokenTypeParameterValue) {
				return ICALTokenTypeParameterValue;
			}
			return ICALTokenTypeNone;
		case '=': // Parameter name/value seperator. Transition to parameter value state
			if (_state == ICALTokenTypeParameter) {
				_state = ICALTokenTypeParameterValue;
				return ICALTokenTypeParameter;
			}

			// Ignore if not in parameter state
			continue;
		}
	}

	return ICALTokenTypeNone;
}

- (NSString *)stringValue {
	NSRange range;
	NSData *subdata;
	NSString *string;

	range = NSMakeRange(_lastPosition, _position - _lastPosition);
	subdata = [_data subdataWithRange:range];
	string = [[NSString alloc] initWithData:subdata encoding:NSUTF8StringEncoding];

	return string;
}

@end

@implementation ICALParser

/*
 * Unfolds the data by removing CRLF sequences and continuation lines.
 *
 * We need to operate on raw data, as some very simple implementation
 * could have folded in the middle of a multi-byte UTF-8 character.
 *
 * See https://tools.ietf.org/html/rfc5545#section-3.1
 */
+ (NSArray<NSData *> *)_unfoldData:(NSData *)data {
	NSMutableArray<NSData *> *lines;
	NSMutableData *unfoldedData;
	const uint8_t *bytes;
	NSUInteger length;
	NSUInteger i;

	lines = [NSMutableArray array];
	unfoldedData = [NSMutableData data];
	bytes = [data bytes];
	length = [data length];

	i = 0;
	while (i < length) {
		// Check for a CRLF sequence
		if (i < length + 1 && bytes[i] == '\r' && bytes[i + 1] == '\n') {
			i += 2;

			// Is this a continuation line?
			if (i < length && (bytes[i] == ' ' || bytes[i] == '\t')) {
				i++;
			} else if ([unfoldedData length]) { // End of line and not empty
				// Make an immutable copy of the unfolded data
				[lines addObject:[unfoldedData copy]];

				// Reset the unfolded data
				unfoldedData = [NSMutableData data];
			}
		} else {
			[unfoldedData appendBytes:&bytes[i] length:1];
			i++;
		}
	}

	// Add the last line
	if ([unfoldedData length]) {
		[lines addObject:[unfoldedData copy]];
	}

	return lines;
}

- (nullable ICALComponent *)parseData:(NSData *)data error:(NSError **)error {
	return nil;
}

@end

NS_ASSUME_NONNULL_END
