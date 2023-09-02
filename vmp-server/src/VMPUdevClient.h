/* vmp-server - A virtual multimedia processor
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import <Foundation/Foundation.h>

/**
   @brief Delegate for device events

   When the udev monitor is active, this delegate
   is used to notify the client of device events.

   @see VMPUdevClient for additional subsystem filtering.
*/
@protocol VMPUdevClientDelegate <NSObject>
/**
   @brief Called when a device is added

   @param device The device that was added
*/
- (void)onDeviceAdded:(NSString *)device;

/**
   @brief Called when a device is removed

   @param device The device that was removed
*/
- (void)onDeviceRemoved:(NSString *)device;
@end

/**
   @brief Client for udev events

   This class is used to monitor udev events
   for a given set of subsystems.

   @property subsystems The subsystems to monitor
   @property delegate The delegate to notify of events

   @note You need to call startMonitorWithError: to start
   the actual monitoring of udev events.

   @see VMPUdevClientDelegate for device event callbacks.
*/
@interface VMPUdevClient : NSObject
@property (nonatomic, weak) id<VMPUdevClientDelegate> delegate;
@property (nonatomic, readonly) NSArray<NSString *> *subsystems;

/**
  @brief Returns a udev client initialized with the given subsystems

  @param subsystems The subsystems to monitor
  @param delegate The delegate to notify of events

  @return The initialized udev client for the given subsystems
*/
+ (instancetype)clientWithSubsystems:(NSArray<NSString *> *)subsystems Delegate:(id<VMPUdevClientDelegate>)delegate;

/**
	 @brief Creates and returns a new udev client object

	 @param subsystems The subsystems to monitor
	 @param delegate The delegate to notify of events

	 @return A new udev client for the given subsystems
*/
- (instancetype)initWithSubsystems:(NSArray<NSString *> *)subsystems Delegate:(id<VMPUdevClientDelegate>)delegate;

/**
   @brief Starts monitoring udev events

   @param error Set to an NSError object if an error occured, and error is not NULL

   This method returns immediately, as further events are handled asynchronously.
   A subsequent call to stopMonitor is required to stop the monitoring of udev events.
*/
- (void)startMonitorWithError:(NSError **)error;

/**
   @brief Stops monitoring udev events
*/
- (void)stopMonitor;
@end