/* vmp-server - A virtual multimedia processor
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import "VMPErrors.h"

// Macro for strict parsing of dictionaries
#define SET_PROPERTY(property, key)                                                                \
	property = propertyList[key];                                                                  \
	if (!property) {                                                                               \
		VMP_FAST_ERROR(error, VMPErrorCodePropertyListError, @"'%@' property is missing", key);    \
		return nil;                                                                                \
	}