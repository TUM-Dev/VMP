/* vmpserverd - A virtual multimedia processor
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import <Foundation/Foundation.h>
#import <gst/gst.h>

NS_ASSUME_NONNULL_BEGIN

/// The initial state of the pipeline after creation
extern NSString *const kVMPStateCreated;
/// The state of the pipeline when playing
extern NSString *const kVMPStatePlaying;
/// The state of the pipeline when EOS was received over the GStreamer bus
extern NSString *const kVMPStateEOS;

/// Key for pipeline restart count in stats dictionary. @see VMPPipelineManager
extern NSString *const kVMPStatisticsNumberOfRestarts;

// Forward-declaration for VMPPipelineManagerDelegate
@class VMPPipelineManager;

/**
 * @brief Delegate for pipeline state changes
 *
 * When the pipeline manager is active, this delegate
 * is used to notify the client of state changes.
 *
 * Possible states:
 * @li @see kVMPStateCreated - The initial state after creation.
 * @li @see kVMPStatePlaying - The state when playing.
 * @li @see kVMPStateEOS - The state when EOS is received.
 *
 * @see VMPPipelineManager
 */
@protocol VMPPipelineManagerDelegate <NSObject>

/**
 * @brief Called when the pipeline state changes
 *
 * @param state The new pipeline state
 */
- (void)onStateChanged:(NSString *)state manager:(VMPPipelineManager *)mgr;

@optional
/**
 * @brief Called when a GStreamer bus event is received
 *
 * @param message The GStreamer bus message
 *
 * If a bus event on the internal GStreamer pipeline's bus occurs, we will
 * forward this event if the delegate implemented this method.
 */
- (void)onBusEvent:(GstMessage *)message manager:(VMPPipelineManager *)mgr;
@end

/**
 * @brief Pipeline Manager
 *
 * We use the metaphor of a pipeline when processing
 * incoming buffers from one, or more sources, sending
 * them to zero or more intermediaries, until the buffers
 * are finally processed by the sink.
 *
 * Thankfully, all the heavy lifting is done by GStreamer
 * (in theory) and we only need to bother with the actual
 * configuration.
 *
 * For this, we abstract a GStreamer pipeline into an
 * Objective-C object which is responsible for configuration,
 * lifetime, statistics, and delegation of GStreamer events.
 */
@interface VMPPipelineManager : NSObject

/**
 * A weak reference to the registered delegate
 */
@property (nonatomic, weak) id<VMPPipelineManagerDelegate> delegate;

/**
 * The GStreamer launch arguments which were passed to the initialiser.
 *
 * @note Changing the launch arguments takes effect on the next pipeline
 * restart.
 */
@property (nonatomic, readonly) NSString *launchArgs;

/**
 * @brief channel name
 *
 * This name may be used in the GStreamer pipeline to publish an
 * intervideosrc or interaudiosrc.
 */
@property (nonatomic, readonly) NSString *channel;

/**
 * @brief the current state of the pipeline
 *
 * Possible states:
 * @li @see kVMPStateCreated - The initial state after creation.
 * @li @see kVMPStatePlaying - The state when playing.
 * @li @see kVMPStateEOS - The state when EOS is received.
 */
@property (nonatomic, readonly) NSString *state;

/**
 * @brief Pipeline statistics
 *
 * The following statistics are available:
 * @li @see kVMPStatisticsNumberOfRestarts - The number of times the pipeline
 * has been restarted
 */
@property (nonatomic, readonly) NSDictionary *statistics;

/**
 * @brief The VMPPipelineManager convenience initialiser
 *
 * @param args GStreamer pipeline description
 * @param channel the channel name which may be used by GStreamer
 * @param delegate The delegate for event notifications
 *
 * @returns the pipeline manager for the given channel
 */
+ (instancetype)managerWithLaunchArgs:(NSString *)args
							  channel:(NSString *)channel
							 delegate:(id<VMPPipelineManagerDelegate>)delegate;

/**
 * @brief The VMPPipelineManager initialiser
 *
 * @param args GStreamer pipeline description
 * @param channel the channel name which may be used by GStreamer
 * @param delegate the delegate for event notifications
 *
 * The first argument is the string of the GStreamer pipeline description.
 * It is the same configuration you would use when configuring "gst-launch-1.0".
 *
 * Here is an example: `gst-launch-1.0 videotestsrc ! autovideosink` The source
 * element is a `videotestsrc` which creates a SMPTE video test stream by
 * default, and the sink `autovideosink` with no intermediary element.
 *
 * The second argument is the name of the channel. It is the same name of the channel
 * you have configured in the server configuration.
 * We are decoupling pipelines internally with `inter{audio,video}{src, sink}`
 * elements which require a channel name.
 * Your pipeline may not use these elements, but we still need to differentiate
 * between instances of this class.
 *
 * The third argument is a delegate for non-optional and optional events.
 * @See VMPPipelineManagerDelegate
 *
 * @returns a pipeline manager initialised with the given channel
 */
- (instancetype)initWithLaunchArgs:(NSString *)args
						   channel:(NSString *)channel
						  delegate:(id<VMPPipelineManagerDelegate>)delegate;

/*
 * @brief Retrieve the GStreamer dot graph of the pipeline
 *
 * GStreamer offers a way to view at the current pipeline configuration by
 * generated a dot graph of the pipeline, including elements, negotiated
 * capabilities, and the state of the pipeline.
 *
 * This functionality is exposed via this method.
 *
 * @returns ASCII-encoded dot graph of the pipeline
 */
- (nullable NSData *)pipelineDotGraph;

/**
 * @brief Starts the pipeline manager
 *
 * @returns YES if the pipeline manager was started successfully, NO otherwise
 */
- (BOOL)start;

/**
 * @brief Stops the pipeline manager
 */
- (void)stop;

@end

NS_ASSUME_NONNULL_END
