/* vmp-server - A virtual multimedia processor
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import <Foundation/Foundation.h>

extern NSString *const VMPErrorDomain;

/**
@brief Error codes for the VMPErrorDomain
*/
typedef NS_ENUM(NSInteger, VMPErrorCode) {
    /// Unknown error
    VMPErrorCodeUnknown = 0,
    /// Device not found
    VMPErrorCodeDeviceNotFound = 1,
    /// Udev initialization error. Used in VMPUDevClient
    VMPErrorCodeUdevError = 2,
    /// Udev monitor initialization error. Used in VMPUDevClient
    VMPErrorCodeUdevMonitorError = 3,
};