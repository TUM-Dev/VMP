/* CalendarKit - An RFC 5545-compliant calendar library for Objective-C
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import "ICALParser.h"

typedef NS_ENUM(NSUInteger, ICALParserState) { ICALParserStateNone };

NS_ASSUME_NONNULL_BEGIN

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
	const char *bytes;
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
