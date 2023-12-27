/* vmpserverd - A virtual multimedia processor
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import "VMPConfigModel.h"
#import "VMPProfileModel.h"

#import "VMPPipelineManager.h"
#import "VMPProfileManager.h"
#import "VMPServerMain.h"

#import <gst/rtsp-server/rtsp-server.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief RTSP server class
 *
 * This class is responsible for setting up the RTSP server, and
 * creating the pipeline channels.
 *
 * Currently, this class is a wrapper around the GStreamer RTSP server, and additionally
 * initialises the pipeline managers for all registered channels.
 */
@interface VMPRTSPServer : NSObject <VMPPipelineManagerDelegate>

/**
 * @brief Server configuration for configuring RTSP server
 */
@property (readonly) VMPConfigModel *configuration;

/**
 * @brief The current pipeline profile
 */
@property (readonly) VMPProfileModel *currentProfile;

/**
 * @brief RTSP server convenience initialiser
 *
 * @param configuration The RTSP server configuration
 * @param profile The platform-specific profile
 *
 * @returns an rtsp server object with the supplied configuration and profile
 */
+ (instancetype)serverWithConfiguration:(VMPConfigModel *)configuration
								profile:(VMPProfileModel *)profile;

/**
 * @brief RTSP server initialiser
 *
 * @param configuration The RTSP server configuration
 * @param profile The platform-specific profile
 *
 * @note The actual construction of the channels and mountpoint registration
 * happens in startWithError:
 *
 * @returns an rtsp server object initialised with the supplied configuration and profile
 */
- (instancetype)initWithConfiguration:(VMPConfigModel *)configuration
							  profile:(VMPProfileModel *)profile;

/**
 * @brief Retrieve the pipeline manager for a given channel
 *
 * @returns a pipeline manager object is lookup was successful, nil otherwise.
 */
- (nullable VMPPipelineManager *)pipelineManagerForChannel:(NSString *)channel;

/**
 * @brief GStreamer pipeline graph for a given mountpoint
 *
 * As the pipeline is managed by the GStreamer RTSP server, and
 * not by pipeline managers (@see VMPPipelineManager), information may
 * be unavailable or outdated under certain circumstances.
 *
 * Information is extracted in a construction callback, and thus only available
 * if at least one client is connected to the mountpoint. The last pipeline
 * graph is cached.
 *
 * @returns an ASCII-encoded dot graph, or nil if no mountpoint could be found,
 * or an error occurred during generation.
 */
- (nullable NSData *)dotGraphForMountPointName:(NSString *)name;

/**
 * @brief Information about all active channels
 *
 * @returns an array of dictionaries containing "name", and "state" of the
 * channel
 */
- (NSArray<NSDictionary *> *)channelInfo;

/**
 * @brief Start the RTSP server
 *
 * @returns YES if the server was started successfully, NO otherwise.
 */
- (BOOL)startWithError:(NSError **)error;

/**
 * @brief Stop the RTSP server
 *
 * You should not restart the server after calling this method.
 */
- (void)stop;

@end

NS_ASSUME_NONNULL_END
