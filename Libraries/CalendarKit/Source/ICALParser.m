/* CalendarKit - An RFC 5545-compliant calendar library for Objective-C
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#include "Foundation/NSObjCRuntime.h"
#import <CalendarKit/ICALError.h>
#import <stdint.h>

#import "ICALParser.h"

#define SET_ERROR(err_ptr, err_code, err_description, err_line, err_position)                      \
	if (err_ptr) {                                                                                 \
		*err_ptr = [NSError errorWithDomain:ICALErrorDomain                                        \
									   code:(err_code) userInfo:@{                                 \
										   NSLocalizedDescriptionKey : (err_description),          \
										   ICALParserPositionKey : @((err_position)),              \
										   ICALParserLineKey : @((err_line))                       \
									   }];                                                         \
	}
NS_ASSUME_NONNULL_BEGIN

@implementation ICALTokenizer {
	NSData *_data;
	NSUInteger _line;
	NSUInteger _position;
	NSUInteger _valuePosition;
	NSUInteger _lastPosition;
	BOOL _inQuotedString;
	ICALTokenType _state;
	ICALTokenType _prevState;
}

- (instancetype)initWithData:(NSData *)data line:(NSUInteger)line {
	self = [super init];

	if (self) {
		_data = data;
		_line = line;
		_position = 0;
		_valuePosition = 0;
		_lastPosition = 0;
		_inQuotedString = NO;
		_state = ICALTokenTypeProperty;
		_prevState = ICALTokenTypeNone;
	}

	return self;
}

/*
 * State machine without transition to error state:
 *
 *                ;     ┌─────────────┐      =
 *          ┌──────────▶│  parameter  │──────────┐
 *          │           └─────────────┘          │
 *          │                  ▲                 │          ,
 *          │                  │                 │         ┌─┐
 *   ┌─────────────┐           │ ;               ▼         │ │
 *   │    none     │           │        ┌─────────────────┐▼ │
 *   └─────────────┘           └────────│ parameter value │──┘
 *                                      └─────────────────┘
 *                                               │
 *                                               │
 *                      ┌─────────────┐          │
 *                      │    value    │◀─────────┘
 *                      └─────────────┘      :
 */
- (ICALTokenType)nextTokenWithError:(NSError **)error {
	if (_state == ICALTokenTypeNone || _state == ICALTokenTypeError) {
		return _state;
	}

	const uint8_t *bytes;
	NSUInteger length;

	bytes = [_data bytes];
	length = [_data length];
	_lastPosition = _position;
	BOOL wasQuoted = NO;

	// Handle value token by setting position to end of line
	if (_state == ICALTokenTypeValue) {
		_prevState = _state;
		_state = ICALTokenTypeNone;
		_position = _valuePosition = length;
		return ICALTokenTypeValue;
	}

	while (_position < length) {
		const uint8_t c = bytes[_position];
		// Do not include control characters in the value
		_valuePosition = _position;
		_prevState = _state;
		_position += 1;

		if (_inQuotedString) {
			if (c == '"') {
				_inQuotedString = NO;
				wasQuoted = YES;
			} else if ((c < 0x20 || c == 0x7F) && c != 0x09) {
				// Invalid CONTROL chars (%x00-08 / %x0A-1F / %x7F) in quoted string
				_state = ICALTokenTypeError;
				SET_ERROR(error, ICALParserControlCharError,
						  @"Invalid CONTROL character in quoted string", _line, _position);
				return _state;
			}
			continue;
		}

		switch (c) {
		case '"':
			if (wasQuoted) {
				// Invalid character after quoted string
				_state = ICALTokenTypeError;
				SET_ERROR(error, ICALParserQuotedStringError,
						  @"Cannot start new quoted string after ending one", _line, _position);
				return _state;
			}

			_inQuotedString = YES;
			if (_state == ICALTokenTypeParameterValue) {
				_state = ICALTokenTypeQuotedParameterValue;
			}
			break;
		case ':': // Transition to value state
				  // Check if transition is valid
			if (_prevState == ICALTokenTypeParameterValue
				|| _prevState == ICALTokenTypeQuotedParameterValue
				|| _prevState == ICALTokenTypeProperty) {
				_state = ICALTokenTypeValue;
				return _prevState;
			}
			// Invalid transition to value state
			_state = ICALTokenTypeError;
			SET_ERROR(error, ICALParserUnexpectedPropetyValueSeperatorError,
					  @"Unexpected property value seperator", _line, _position);
			return _state;
		case ';': // Parameter seperator. Transition to parameter state
			if (_prevState == ICALTokenTypeProperty || _prevState == ICALTokenTypeParameterValue
				|| _prevState == ICALTokenTypeQuotedParameterValue) {
				_state = ICALTokenTypeParameter;
				return _prevState;
			}
			// Invalid transition to parameter state
			_state = ICALTokenTypeError;
			SET_ERROR(error, ICALParserUnexpectedParameterError, @"Unexpected parameter seperator",
					  _line, _position);
			return _state;
		case ',': // Parameter Value seperator. Stay until transition to value state
			if (_state == ICALTokenTypeParameterValue
				|| _state == ICALTokenTypeQuotedParameterValue) {
				return _state;
			}
			SET_ERROR(error, ICALParserUnexpectedParameterValueError,
					  @"Unexpected parameter value seperator", _line, _position);
			return ICALTokenTypeError;
		case '=': // Parameter name/value seperator. Transition to parameter value state
			if (_state == ICALTokenTypeParameter) {
				_state = ICALTokenTypeParameterValue;
				return ICALTokenTypeParameter;
			}

			// Ignore if not in parameter state
			continue;
		default:
			/*
			 * Check for invalid CONTROL chars (%x00-08 / %x0A-1F / %x7F)
			 */
			if ((c < 0x20 || c == 0x7F) && c != 0x09) {
				_state = ICALTokenTypeError;
				SET_ERROR(error, ICALParserControlCharError,
						  @"Invalid CONTROL character in unquoted string", _line, _position);
				return _state;
			}
			if (wasQuoted) {
				// Invalid character after quoted string
				_state = ICALTokenTypeError;
				SET_ERROR(error, ICALParserQuotedStringError,
						  @"Invalid character after quoted string", _line, _position);
				return _state;
			}
		}
	}

	SET_ERROR(error, ICALParserUnexpectedEndOfLineError, @"Unexpected end of line", _line,
			  _valuePosition);
	return ICALTokenTypeError;
}

- (NSString *)stringValue {
	if (_position == 0) {
		return @"";
	}

	NSRange range;
	NSData *subdata;
	NSString *string;

	range = NSMakeRange(_lastPosition, _valuePosition - _lastPosition);
	subdata = [_data subdataWithRange:range];
	string = [[NSString alloc] initWithData:subdata encoding:NSUTF8StringEncoding];

	if (_prevState == ICALTokenTypeQuotedParameterValue) {
		if ([string length] < 2) {
			return @"";
		}

		// Remove quotes
		string = [string substringWithRange:NSMakeRange(1, [string length] - 2)];
	}

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
