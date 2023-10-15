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
							  Channel:(NSString *)channel
							 Delegate:(id<VMPPipelineManagerDelegate>)delegate;

/**
   @brief Returns a pipeline manager initialized with the given channel

   @param channel The GStreamer intervideo/interaudio channel name
   @param delegate The delegate to notify of state changes

   @note This method should not be called directly, but instead subclassed.

   @return The pipeline manager for the given channel
*/
- (instancetype)initWithLaunchArgs:(NSString *)args
						   Channel:(NSString *)channel
						  Delegate:(id<VMPPipelineManagerDelegate>)delegate;

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

/**
	@brief Pipeline manager for V4L2 devices

	@property device The V4L2 device to use

	This class is used to manage a pipeline for a given V4L2 device.
	It creates and manages a GStreamer pipeline, with the V4L2 device
	as source, and a intervideosink with the given channel name as sink.

	Once started, the pipeline manager actively monitors device events
	for the given device. If the device is disconnected, the pipeline
	is stopped and the state is set to kVMPStateDeviceDisconnected.

	If the device is reconnected, the pipeline is created, or restarted
	if it was already running, and the state is set to kVMPStateDeviceConnected.
	If successful, the state is subsequently set to kVMPStatePlaying.
	Otherwise, the state is set to kVMPStateDeviceError.o

	Initially, the state is set to kVMPStateIdle.

	Other pipelines can hook into this pipeline by using the intervideosrc
	with the same channel name. If the pipeline is stopped, the intervideosrc
	will return a black screen.

	It is important to note that this inter pipeline mechanism only works
	in the same process, and is not an inter-process communication mechanism.
*/
@interface VMPV4L2PipelineManager : VMPPipelineManager <VMPUdevClientDelegate>

@property (nonatomic, readonly) NSString *device;

/**
	@brief Returns a pipeline manager initialized with the given device

	@param device The V4L2 device to use
	@param channel The GStreamer intervideo/interaudio channel name
	@param delegate The delegate to notify of state changes

	@return The initialized pipeline manager for the given device
	*/
+ (instancetype)managerWithDevice:(NSString *)device
						  channel:(NSString *)channel
						 Delegate:(id<VMPPipelineManagerDelegate>)delegate;

/**
	@brief Initializes and returns a pipeline manager object

	@param device The V4L2 device to use
	@param channel The GStreamer intervideo/interaudio channel name
	@param delegate The delegate to notify of state changes

	@return A pipeline manager object initialized for the given device
*/
- (instancetype)initWithDevice:(NSString *)device
					   channel:(NSString *)channel
					  Delegate:(id<VMPPipelineManagerDelegate>)delegate;
@end