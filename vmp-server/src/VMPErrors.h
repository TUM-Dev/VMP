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
	/// V4L2 device capabilities error. Used in VMPV4L2PipelineManager
	VMPErrorV4L2DeviceCapabilities = 2,
	/// ALSA device capabilities error. Used in VMPALSAPipelineManager
	VMPErrorALSADeviceCapabilities = 3,
	/// Udev initialization error. Used in VMPUDevClient
	VMPErrorCodeUdevError = 4,
	/// Udev monitor initialization error. Used in VMPUDevClient
	VMPErrorCodeUdevMonitorError = 5,
	VMPErrorCodeGStreamerParseError = 6,
	VMPErrorCodeGStreamerStateChangeError = 7,
};