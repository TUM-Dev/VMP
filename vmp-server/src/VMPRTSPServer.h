/* vmp-server - A virtual multimedia processor
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import "VMPPipelineManager.h"
#import "VMPServerMain.h"

#import <gst/rtsp-server/rtsp-server.h>

/**
	@brief RTSP server class

	This class is responsible for setting up the RTSP server, and
	creating the pipeline channels.

	Currently, this class is a wrapper around the GStreamer RTSP server, and additionally
	initialises the ingress pipelines.
*/
@interface VMPRTSPServer : NSObject <VMPPipelineManagerDelegate>

/**
	@brief Server configuration for configuring RTSP server

	@note This property is readonly, and can only be set during initialisation.
*/
@property (nonatomic, readonly) VMPServerConfiguration *configuration;

+ (instancetype)serverWithConfiguration:(VMPServerConfiguration *)configuration;
- (instancetype)initWithConfiguration:(VMPServerConfiguration *)configuration;

/**
	@brief Start the RTSP server

	@return YES if the server was started successfully, NO otherwise.
*/
- (BOOL)startWithError:(NSError **)error;

@end