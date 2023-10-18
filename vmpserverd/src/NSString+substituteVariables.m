/* vmp-server - A virtual multimedia processor
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import <Foundation/Foundation.h>

#import "NSString+substituteVariables.h"

@implementation NSString (substituteVariables)
- (NSString *)stringBySubstitutingVariables:(NSDictionary<NSString *, NSString *> *)variables
									  error:(NSError **)error {
	NSMutableString *mutableSelf;
	NSArray<NSTextCheckingResult *> *matches;
	NSInteger nextOffset = 0;

	// We only need to compile the regex once
	static NSRegularExpression *regex;
	if (!regex) {
		// TODO: Allow for escaping of { and } characters
		regex = [NSRegularExpression regularExpressionWithPattern:@"\\{([^}]+)\\}"
														  options:0
															error:error];
		if (!regex)
			return nil;
	}

	mutableSelf = [self mutableCopy];
	// Match all variables in the string with the compiled regex
	matches = [regex matchesInString:mutableSelf
							 options:0
							   range:NSMakeRange(0, [mutableSelf length])];

	// Iterate over all matches, and replace them with the value from the variables dictionary if
	// present
	for (NSTextCheckingResult *res in matches) {
		NSRange matchRange, fullMatchRange;
		NSString *key, *value;

		matchRange = [res rangeAtIndex:1];
		fullMatchRange = [res range];
		// Shift range by the offset of the previous match
		matchRange = NSMakeRange(matchRange.location + nextOffset, matchRange.length);
		fullMatchRange = NSMakeRange(fullMatchRange.location + nextOffset, fullMatchRange.length);

		key = [mutableSelf substringWithRange:matchRange];
		value = variables[key];

		if (!value) {
			NSString *infoString;
			NSDictionary *userInfo;

			infoString = [NSString stringWithFormat:@"No value for key '%@'", key];
			userInfo = @{NSLocalizedDescriptionKey : infoString};

			if (error) {
				*error = [NSError errorWithDomain:@"NSString+substituteVariables"
											 code:0
										 userInfo:userInfo];
			}

			return nil;
		}

		[mutableSelf replaceCharactersInRange:fullMatchRange withString:value];

		// Update the offset for the next match
		nextOffset = nextOffset + [value length] - fullMatchRange.length;
	}

	return [mutableSelf copy];
}
@end
