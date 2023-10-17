/* vmp-server - A virtual multimedia processor
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import <Foundation/Foundation.h>

#import "VMPConfigModel.h"
#import "VMPErrors.h"

/**
	@brief Configures the RTSP server, and HTTP server.

	This class is the main entry point for the server.
	Configuration independent of the RTSP server is done here.
*/
@interface VMPServerMain : NSObject

@property (nonatomic, readonly) VMPConfigModel *configuration;

+ (instancetype)serverWithConfiguration:(VMPConfigModel *)configuration error:(NSError **)error;

- (instancetype)initWithConfiguration:(VMPConfigModel *)configuration error:(NSError **)error;

/**
	@brief Start the server
*/
- (BOOL)runWithError:(NSError **)error;

@end