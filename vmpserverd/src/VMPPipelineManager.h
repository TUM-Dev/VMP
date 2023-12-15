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
extern NSString *const kVMPStateError;

extern NSString *const kVMPStatisticsNumberOfRestarts;

@class VMPPipelineManager;

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
- (void)onStateChanged:(NSString *)state manager:(VMPPipelineManager *)mgr;

@optional
/**
	@brief Called when a GStreamer bus event is received

	@param message The GStreamer bus message

	A bus event of the internal pipeline is sent to the delegate.
*/
- (void)onBusEvent:(GstMessage *)message manager:(VMPPipelineManager *)mgr;
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

/**
	@brief The underlying GStreamer pipeline
*/
@property (nonatomic, readonly) GstElement *pipeline;

/**
	@brief The statistics of the pipeline

	The following statistics are available:
	- "numberOfRestarts" - The number of times the pipeline has been restarted
*/
@property (nonatomic, readonly) NSDictionary *statistics;

/**
	@brief Returns a pipeline manager initialized with the given channel

	@param channel The channel name for registering the pipeline
	@param delegate The delegate to notify of state changes

	@return The pipeline manager for the given channel
*/
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

/*
	@brief Retrieve the GStreamer dot graph of the pipeline

	@return ASCII-encoded dot graph of the pipeline
*/
- (NSData *)pipelineDotGraph;

/**
	@brief Starts the pipeline manager

	@return YES if the pipeline manager was started successfully, NO otherwise
*/
- (BOOL)start;

/**
	@brief Stops the pipeline manager
*/
- (void)stop;

/**
	@brief Schedules a restart of the pipeline via the run loop
*/
- (void)restart;
@end
