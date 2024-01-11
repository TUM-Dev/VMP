/* CalendarKit - An RFC 5545-compliant calendar library for Objective-C
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#include "Foundation/NSArray.h"
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

#define SET_PARSER_ERROR_NESTED(err_ptr, err_underlying, err_description)                          \
	if (err_ptr) {                                                                                 \
		*err_ptr = [NSError errorWithDomain:ICALErrorDomain                                        \
									   code:ICALObjectParseError                                   \
								   userInfo:@{                                                     \
									   NSLocalizedDescriptionKey : (err_description),              \
									   NSUnderlyingErrorKey : (err_underlying)                     \
								   }];                                                             \
	}

#define SET_PARSER_ERROR(err_ptr, err_description)                                                 \
	if (err_ptr) {                                                                                 \
		*err_ptr = [NSError errorWithDomain:ICALErrorDomain                                        \
									   code:ICALObjectParseError                                   \
								   userInfo:@{NSLocalizedDescriptionKey : (err_description)}];     \
	}

NS_ASSUME_NONNULL_BEGIN

/*
 * Returns YES if the transition from the given state to the given state is valid.
 */
static BOOL _isTransitionValid(ICALTokenType from, ICALTokenType to) {
	switch (from) {
	case ICALTokenTypeNone:
		return to == ICALTokenTypeProperty;
	case ICALTokenTypeProperty:
		// Property can transition to a parameter (with ';') or a value (with ':')
		return to == ICALTokenTypeParameter || to == ICALTokenTypeValue;
	case ICALTokenTypeParameter:
		// Parameter can transition to a parameter value or quoted parameter value (with '=')
		return to & ICALTokenParameterValueMask;
	case ICALTokenTypeQuotedParameterValue:
	case ICALTokenTypeParameterValue:
		// Parameter value can transition to a (quoted) parameter value (with ','), parameter (with
		// ';'), or a value (with ':')
		return (to & ICALTokenParameterValueMask) || to == ICALTokenTypeParameter
			   || to == ICALTokenTypeValue;

	case ICALTokenTypeValue:
		// Reached end-of-line, so no transition is valid
		return to == ICALTokenTypeNone;
	default:
		return NO;
	}
}

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
		_state = ICALTokenTypeProperty;
		_prevState = ICALTokenTypeNone;
	}

	return self;
}

- (instancetype)init {
	self = [super init];

	if (self) {
		_state = ICALTokenTypeNone;
		_prevState = ICALTokenTypeNone;
	}

	return self;
}

- (void)setData:(NSData *)data line:(NSUInteger)line {
	_state = ICALTokenTypeProperty;
	_prevState = ICALTokenTypeNone;
	_position = 0;
	_valuePosition = 0;
	_lastPosition = 0;
	_inQuotedString = NO;
	_line = line;
	_data = data;
}

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
			_state = ICALTokenTypeValue;

			if (!_isTransitionValid(_prevState, _state)) {
				_state = ICALTokenTypeError;
				SET_ERROR(error, ICALParserUnexpectedPropetyValueSeperatorError,
						  @"Unexpected property value seperator", _line, _position);
				return _state;
			}

			return _prevState;
		case ';': // Parameter seperator. Transition to parameter state
			_state = ICALTokenTypeParameter;

			if (!_isTransitionValid(_prevState, _state)) {
				_state = ICALTokenTypeError;
				SET_ERROR(error, ICALParserUnexpectedParameterError,
						  @"Unexpected parameter seperator", _line, _position);
				return _state;
			}
			return _prevState;
		case ',': // Parameter Value seperator. Stay until transition to value state
			if (!_isTransitionValid(_prevState, _state)) {
				_state = ICALTokenTypeError;
				SET_ERROR(error, ICALParserUnexpectedParameterValueError,
						  @"Unexpected parameter value seperator", _line, _position);
				return _state;
			}
			return _state;
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

@implementation ICALParser {
	// The content line tokenizer
	ICALTokenizer *_tokenizer;
	// Unfolded content lines
	NSArray<NSData *> *_lines;
	// Current line
	NSUInteger _curLine;
	// Parsed Components
	NSMutableArray<ICALComponent *> *_components;
	// (Partial) Properties of actively parsed component
	NSMutableDictionary<NSString *, NSMutableDictionary *> *_currentProps;
}

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

+ (instancetype)parserWithData:(NSData *)data {
	return [[ICALParser alloc] initWithData:data];
}

- (instancetype)initWithData:(NSData *)data {
	self = [super init];

	if (self) {
		_lines = [ICALParser _unfoldData:data];
		_tokenizer = [[ICALTokenizer alloc] init];
		_curLine = 0;
		_components = [NSMutableArray array];
		_currentProps = [NSMutableDictionary dictionary];
	}

	return self;
}

- (nullable NSArray<ICALComponent *> *)parseWithError:(NSError **)error {
	ICALTokenType tokenType;
	NSError *tError = NULL;

	if (_curLine != 0) {
		SET_PARSER_ERROR(error, @"Parser has already been called");
		return nil;
	}

	NSString *currentComponent = @"";
	NSString *lastProperty = @"";
	// Buffer parameter values until we see the next parameter or value
	NSMutableArray *parameterValues = [NSMutableArray array];

	for (NSData *line in _lines) {
		NSString *lastParameter = @"";

		[_tokenizer setData:line line:_curLine++];

		tokenType = [_tokenizer nextTokenWithError:&tError];

		while (!(tokenType & ICALTokenInvalidMask)) {
			switch (tokenType) {
			case ICALTokenTypeProperty: {
				NSString *name;

				name = [[_tokenizer stringValue] uppercaseString];
				lastProperty = name;

				// Do not add BEGIN/END properties to the component
				if ([@"BEGIN" isEqualToString:name]) {
					// Get the component type

					tokenType = [_tokenizer nextTokenWithError:&tError];
					if (tokenType & ICALTokenInvalidMask) {
						SET_PARSER_ERROR_NESTED(error, tError,
												@"Error while trying to get component type");
						return nil;
					} else if (tokenType != ICALTokenTypeValue) {
						SET_PARSER_ERROR(error, @"Unexpected token type in BEGIN property");
						return nil;
					}

					currentComponent = [[_tokenizer stringValue] uppercaseString];
					break;
				} else if ([@"END" isEqualToString:name]) {
					// Create components out of the current properties
					if ([currentComponent length] == 0) {
						SET_PARSER_ERROR(error, @"Unexpected END property without BEGIN property");
						return nil;
					}

					ICALComponent *component;
					component = [[ICALComponent alloc] initWithProperties:_currentProps
																	 type:currentComponent
																	error:&tError];
					// Reset the current properties
					_currentProps = [NSMutableDictionary dictionary];
					if (tError) {
						SET_PARSER_ERROR_NESTED(error, tError,
												@"Error while trying to create component");
						return nil;
					}

					[_components addObject:component];
					break;
				} else if (_currentProps[name]) {
					break; // FIXME: Are duplicate properties allowed?
				}

				// Create a new dictionary for the property
				[_currentProps setObject:[NSMutableDictionary dictionary] forKey:name];
				break;
			}
			case ICALTokenTypeParameter: {
				[self _storeParameterValues:parameterValues
							  withParameter:lastParameter
								forProperty:lastProperty];

				NSMutableDictionary *property = [_currentProps objectForKey:lastProperty];
				lastParameter = [[_tokenizer stringValue] uppercaseString];
				if ([lastParameter isEqualToString:@""]) {
					SET_PARSER_ERROR(error, @"Unexpected empty parameter");
					return nil;
				}

				// Add the parameter to the property with empty value dictionary
				[property setObject:[NSMutableDictionary dictionary] forKey:lastParameter];
				break;
			}

			// Parameter values are first added to an array, and later (see
			// ICALTokenTypeParameter and ICALTokenTypeValue) added to the
			// corresponding property.
			//
			// This is because a parameter can have multiple values, and we
			// don't know if a parameter has multiple values until we see the
			// next parameter or value.
			case ICALTokenTypeParameterValue:
				[parameterValues addObject:[[_tokenizer stringValue] uppercaseString]];
				break;
			case ICALTokenTypeQuotedParameterValue:
				[parameterValues addObject:[_tokenizer stringValue]];
				break;
			case ICALTokenTypeValue: {
				NSMutableDictionary *propDict;
				NSString *value;

				[self _storeParameterValues:parameterValues
							  withParameter:lastParameter
								forProperty:lastProperty];

				propDict = [_currentProps objectForKey:lastProperty];
				value = [_tokenizer stringValue];

				[propDict setObject:value forKey:ICALPropertyValueKey];
				break;
			}
			default:
				break;
			}

			// Get the next token
			tokenType = [_tokenizer nextTokenWithError:&tError];
		}

		if (tError) {
			SET_PARSER_ERROR_NESTED(error, tError, @"Error while parsing content line");
			return nil;
		}
	}

	return _components;
}

- (void)_storeParameterValues:(NSMutableArray<NSString *> *)arr
				withParameter:(NSString *)parameter
				  forProperty:(NSString *)property {
	NSMutableDictionary *dict;

	if ([arr count] == 0 || [parameter isEqualToString:@""]) {
		// Reset the array
		[arr removeAllObjects];
		return;
	}

	dict = [_currentProps objectForKey:property];

	if ([arr count] == 1) {
		[dict setObject:[arr objectAtIndex:0] forKey:parameter];
	} else {
		[dict setObject:[arr copy] forKey:parameter];
	}

	// Reset the array
	[arr removeAllObjects];
}

@end

NS_ASSUME_NONNULL_END
