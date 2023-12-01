/* vmp-server - A virtual multimedia processor
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#include "VMPPipelineManager.h"
#include "VMPProfileModel.h"
#include <Foundation/NSArray.h>
#include <Foundation/NSDate.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSISO8601DateFormatter.h>
#include <MicroHTTPKit/HKHTTPResponse.h>
#include <MicroHTTPKit/HKRouter.h>
#import <MicroHTTPKit/MicroHTTPKit.h>
#import <glib.h>

#import "VMPConfigModel.h"
#import "VMPJournal.h"
#import "VMPProfileManager.h"
#import "VMPRTSPServer.h"
#import "VMPServerMain.h"

#include "config.h"

@implementation VMPServerMain {
	VMPRTSPServer *_rtspServer;
	VMPProfileManager *_profileMgr;
	HKHTTPServer *_httpServer;
	NSString *_version;
	NSDate *_startedAtDate;
	NSString *_startedAtDateISO8601;
}

+ (instancetype)serverWithConfiguration:(VMPConfigModel *)configuration error:(NSError **)error {
	return [[VMPServerMain alloc] initWithConfiguration:configuration
										  forcePlatform:nil
												  error:error];
}

+ (instancetype)serverWithConfiguration:(VMPConfigModel *)configuration
						  forcePlatform:(NSString *)platform
								  error:(NSError **)error {
	return [[VMPServerMain alloc] initWithConfiguration:configuration
										  forcePlatform:platform
												  error:error];
}

- (instancetype)initWithConfiguration:(VMPConfigModel *)configuration error:(NSError **)error {
	return [self initWithConfiguration:configuration forcePlatform:nil error:error];
}

- (instancetype)initWithConfiguration:(VMPConfigModel *)configuration
						forcePlatform:(NSString *)platform
								error:(NSError **)error {
	VMP_ASSERT(configuration, @"Configuration cannot be nil");

	self = [super init];
	if (self) {
		_configuration = configuration;
		NSUInteger port;

		if (platform) {
			_profileMgr = [VMPProfileManager managerWithPath:[configuration profileDirectory]
											 runtimePlatform:platform
													   error:error];
		} else {
			_profileMgr = [VMPProfileManager managerWithPath:[configuration profileDirectory]
													   error:error];
		}
		if (!_profileMgr) {
			return nil;
		}

		_version =
			[NSString stringWithFormat:@"%d.%d.%d", MAJOR_VERSION, MINOR_VERSION, PATCH_VERSION];
		_startedAtDate = [NSDate date];

		// Create ISO8601 date string
		NSISO8601DateFormatter *formatter = [[NSISO8601DateFormatter alloc] init];
		_startedAtDateISO8601 = [formatter stringFromDate:_startedAtDate];

		// Create RTSP server
		_rtspServer = [VMPRTSPServer serverWithConfiguration:configuration
													 profile:[_profileMgr currentProfile]];

		// Create HTTP server
		port = [[configuration httpPort] integerValue];
		// We install HTTP handlers later on when -runWithError: is invoked
		_httpServer = [HKHTTPServer serverWithPort:port];
	}

	return self;
}

#pragma mark - HTTP handlers

- (HKHandlerBlock)_statusHandlerV1 {
	return ^HKHTTPResponse *(HKHTTPRequest *request) {
		VMPProfileModel *profile;
		profile = [_profileMgr currentProfile];

		NSDictionary *response = @{
			@"version" : _version,
			@"platform" : [_profileMgr runtimePlatform],
			@"profile" : @{
				@"name" : [profile name],
				@"identifier" : [profile identifier],
				@"version" : [profile version],
				@"description" : [profile description],
			},
			@"startedAt" : _startedAtDateISO8601,
		};

		return [HKHTTPJSONResponse responseWithJSONObject:response status:200 error:NULL];
	};
}

- (HKHandlerBlock)_configHandlerV1 {
	return ^HKHTTPResponse *(HKHTTPRequest *request) {
		return [HKHTTPJSONResponse responseWithJSONObject:[_configuration propertyList]
												   status:200
													error:NULL];
	};
}

- (HKHandlerBlock)_channelGraphHandlerV1 {
	return ^HKHTTPResponse *(HKHTTPRequest *request) {
		NSString *channel;
		NSDictionary *headers;
		VMPPipelineManager *mgr;

		channel = [request queryParameters][@"channel"];

		if (!channel) {
			NSDictionary *response = @{
				@"error" : @"Missing channel parameter",
			};
			return [HKHTTPJSONResponse responseWithJSONObject:response status:400 error:NULL];
		}

		mgr = [_rtspServer pipelineManagerForChannel:channel];
		if (!mgr) {
			NSDictionary *response = @{
				@"error" : @"Channel not found",
			};
			return [HKHTTPJSONResponse responseWithJSONObject:response status:404 error:NULL];
		}

		headers = @{
			@"Content-Type" : @"text/plain",
		};

		return [[HKHTTPResponse alloc] initWithData:[mgr pipelineDotGraph]
											headers:headers
											 status:200];
	};
}

- (void)setupHTTPHandlers {
	HKRouter *router;
	HKRoute *statusRoute;
	HKRoute *configRoute;
	HKRoute *channelGraphRoute;

	router = [_httpServer router];

	// FIXME: Implement authorization via middleware
	// GET /api/v1/status
	statusRoute = [HKRoute routeWithPath:@"/api/v1/status"
								  method:HKHTTPMethodGET
								 handler:[self _statusHandlerV1]];
	// GET /api/v1/config
	configRoute = [HKRoute routeWithPath:@"/api/v1/config"
								  method:HKHTTPMethodGET
								 handler:[self _configHandlerV1]];
	// GET /api/v1/channel/graph
	channelGraphRoute = [HKRoute routeWithPath:@"/api/v1/channel/graph"
										method:HKHTTPMethodGET
									   handler:[self _channelGraphHandlerV1]];

	[router registerRoute:statusRoute];
	[router registerRoute:configRoute];
	[router registerRoute:channelGraphRoute];
}

#pragma mark - Server Lifecycle

- (void)iterateMainLoop:(NSTimer *)timer {
	// One iteration of the main loop in the default context. Non-blocking.
	g_main_context_iteration(NULL, FALSE);
}

- (BOOL)runWithError:(NSError **)error {
	// Iterate glib mainloop context with NSTimer (fire every second)
	NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:1.0
													  target:self
													selector:@selector(iterateMainLoop:)
													userInfo:nil
													 repeats:YES];

	NSRunLoop *current = [NSRunLoop currentRunLoop];
	[current addTimer:timer forMode:NSDefaultRunLoopMode];

	if (![_rtspServer startWithError:error]) {
		return NO;
	}

	[self setupHTTPHandlers];
	if (![_httpServer startWithError:error]) {
		return NO;
	}

	VMPInfo(@"HTTP server listening on port %@", [_configuration httpPort]);

	return YES;
}

- (void)gracefulShutdown {
	VMPInfo(@"Shutting down...");
	[_rtspServer stop];
	[_httpServer stop];
}

@end