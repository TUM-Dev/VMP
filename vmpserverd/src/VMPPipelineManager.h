/* vmp-server - A virtual multimedia processor
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import <Foundation/Foundation.h>

#import "VMPUdevClient.h"
#import <gst/gst.h>

extern NSString *const kVMPStateIdle;
extern NSString *const kVMPStateDeviceConnected;
extern NSString *const kVMPStateDeviceDisconnected;
extern NSString *const kVMPStateDeviceError;
extern NSString *const kVMPStatePlaying;

/**
	@brief Delegate for pipeline state changes

	When the pipeline manager is active, this delegate
	is used to notify the client of state changes.

	Possible states are:
	- kVMPStateIdle
	- kVMPStateDeviceConnected
	- kVMPStateDeviceDisconnected
	- kVMPStateDeviceError
	- kVMPStatePlaying

	@see VMPPipelineManager
*/
@protocol VMPPipelineManagerDelegate <NSObject>
/**
	@brief Called when the pipeline state changes

	@param state The new pipeline state
*/
- (void)onStateChanged:(NSString *)state;

@optional
/**
	@brief Called when a GStreamer bus event is received

	@param message The GStreamer bus message

	A bus event of the internal pipeline is sent to the delegate.
*/
- (void)onBusEvent:(GstMessage *)message;
@end

/**
	@brief Base class for pipeline managers

	@property channel The GStreamer intervideo/interaudio channel name
	@property delegate The delegate to notify of state changes

	This class is used to manage a pipeline for a given channel.
	It is meant to be subclassed for specific pipelines, and
	not used directly.
*/
@interface VMPPipelineManager : NSObject

@property (nonatomic, weak) id<VMPPipelineManagerDelegate> delegate;
@property (nonatomic, strong) NSString *launchArgs;
@property (nonatomic, strong) NSString *channel;
@property (nonatomic, readonly) NSString *state;
@property (nonatomic, readonly) GstElement *pipeline;

+ (instancetype)managerWithLaunchArgs:(NSString *)args
							  channel:(NSString *)channel
							 delegate:(id<VMPPipelineManagerDelegate>)delegate;

/**
   @brief Returns a pipeline manager initialized with the given channel

   @param channel The GStreamer intervideo/interaudio channel name
   @param delegate The delegate to notify of state changes

   @note This method should not be called directly, but instead subclassed.

   @return The pipeline manager for the given channel
*/
- (instancetype)initWithLaunchArgs:(NSString *)args
						   channel:(NSString *)channel
						  delegate:(id<VMPPipelineManagerDelegate>)delegate;

/**
	@brief Starts the pipeline manager

	@return YES if the pipeline manager was started successfully, NO otherwise
*/
- (BOOL)start;

/**
	@brief Stops the pipeline manager
*/
- (void)stop;
@end
