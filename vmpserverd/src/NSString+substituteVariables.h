/* vmp-server - A virtual multimedia processor
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>

@interface NSString (substituteVariables)
- (NSString *)stringBySubstitutingVariables:(NSDictionary<NSString *, NSString *> *)variables
									  error:(NSError **)error;
@end