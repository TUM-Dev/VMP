/* vmpserverd - A virtual multimedia processor
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import "VMPConfigModel.h"
#import "VMPProfileModel.h"

#import "VMPPipelineManager.h"
#import "VMPProfileManager.h"
#import "VMPRecordingManager.h"
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
@property (nonatomic, readonly) VMPConfigModel *configuration;

/**
 * @brief The current pipeline profile
 */
@property (nonatomic, readonly) VMPProfileModel *currentProfile;

/**
 * @brief Provides global statistics for all managed pipelines and the RTSP server.
 *
 * This dictionary contains the aggregated statistics of all the pipelines being managed.
 *
 * Example structure of the returned dictionary:
 * @code
 * {
 *     "managed_pipelines": [
 *         {
 *             "name": "pipeline0", // The unique name of the pipeline
 *             "type": "v4l2", // The type of pipeline, e.g., 'v4l2' for video4linux2
 *             "state": "playing", // Current state of the pipeline, e.g., 'playing', 'paused'
 *             "numberOfRestarts": 2 // The number of times the pipeline has been restarted
 *         }
 *         // Additional pipeline dictionaries...
 *     ]
 * }
 * @endcode
 *
 * The "managed_pipelines" array within the dictionary contains one dictionary for each
 * managed pipeline.
 *
 * @return NSDictionary containing the global statistics of all managed pipelines and RTSP server.
 */
@property (nonatomic, readonly) NSDictionary *globalStatistics;

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

#pragma mark - Recording

/**
 * @brief Create a new RecordingManager instance
 *
 * The defined channels from the vmpserverd configuration are
 * used to construct a new RecordingManager instance.
 *
 * Available Keys for Options:
 * - "videoChannel" (REQUIRED)
 * - "audioChannel" (REQUIRED)
 * - "videoBitrate" (OPTIONAL, in bbps. Default is 2500kbps)
 * - "audioBitrate" (OPTIONAL, in kbps. Default is 96kbps)
 * - "scaledWidth"  (OPTIONAL)
 * - "scaledHeight" (OPTIONAL)
 */
- (VMPRecordingManager *)defaultRecordingWithOptions:(NSDictionary *)options
												path:(NSURL *)path
											deadline: (NSDate *)date
											   error: (NSError **) error;

/**
 * @brief Schedule a recording specified by a VMPRecording.
 *
 * Note that this method is MT-Safe by locking the internal
 * array of recordings.
 *
 * @returns YES if the recording deadline is later than current time, NO
 * otherwise.
 */
- (BOOL)scheduleRecording:(VMPRecordingManager *)recording;

/**
 * @brief Returns an array of all currently active recordings.
 */
- (NSArray<VMPRecordingManager *> *)recordings;

#pragma mark - Lifecycle

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
