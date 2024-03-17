/* vmp-server - A virtual multimedia processor
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import <MicroHTTPKit/MicroHTTPKit.h>
#import <glib.h>

#import "VMPConfigModel.h"
#import "VMPJournal.h"
#import "VMPProfileManager.h"
#import "VMPRTSPServer.h"
#import "VMPServerMain.h"

#include <graphviz/gvc.h>
#include <graphviz/cgraph.h>

#include "config.h"

// Convert a DOT graph to SVG
static NSData *convertDOTtoSVG(NSData *dotData, NSError **error) {
	NSData *svgData;
    GVC_t *gvc;
	Agraph_t *g;
    char *rendered;
    unsigned int length;
	
	// Initialize Graphviz context
	gvc = gvContext();
	if (!gvc) {
		VMP_FAST_ERROR(error, VMPErrorCodeGraphvizError, @"Failed to initialize Graphviz context");
		return nil;
	}

	// Create a graph from the DOT data
	g = agmemread((char *)[dotData bytes]);
	if (!g) {
		VMP_FAST_ERROR(error, VMPErrorCodeGraphvizError, @"Failed to create graph from DOT data");
		gvFreeContext(gvc);
		return nil;
	}

	if (gvLayout(gvc, g, "dot") != 0) {
		VMP_FAST_ERROR(error, VMPErrorCodeGraphvizError, @"Failed to layout graph");
		agclose(g);
		gvFreeContext(gvc);
		return nil;
	}

	if (gvRenderData(gvc, g, "svg", &rendered, &length) != 0) {
		VMP_FAST_ERROR(error, VMPErrorCodeGraphvizError, @"Failed to render graph to SVG");
		gvFreeLayout(gvc, g);
		agclose(g);
		gvFreeContext(gvc);
		return nil;
	}

	svgData = [NSData dataWithBytes:rendered length:length];

    // Clean up
    gvFreeRenderData(rendered);
    gvFreeLayout(gvc, g);
    agclose(g);
    gvFreeContext(gvc);

	return svgData;
}

@implementation VMPServerMain {
	VMPRTSPServer *_rtspServer;
	VMPProfileManager *_profileMgr;
	HKHTTPServer *_httpServer;
	NSString *_version;
	NSDate *_startedAtDate;
	NSString *_startedAtDateISO8601;
}

#define DEFAULT_HEADERS                                                                            \
	(@{                                                                                            \
		@"Access-Control-Allow-Origin" : @"*",                                                     \
		@"Content-Type" : @"application/json",                                                     \
	})

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

// CORS Handler for all endpoints
- (HKHandlerBlock)_corsHandlerV1 {
	return ^HKHTTPResponse *(HKHTTPRequest *request) {
		HKHTTPResponse *response;
		NSDictionary *headers = @{
			@"Access-Control-Allow-Origin" : @"*",
			@"Access-Control-Allow-Methods" : @"GET, OPTIONS",
			@"Access-Control-Allow-Headers" : @"Authorization, Content-Type",
			@"Access-Control-Max-Age" : @"3600",
		};

		response = [HKHTTPResponse responseWithStatus:200];
		[response setHeaders:headers];

		return response;
	};
}

- (HKHandlerBlock)_middleware {
	return ^HKHTTPResponse *(HKHTTPRequest *request) {
		NSString *authVal;
		NSString *authPair;
		NSDictionary *response;
		NSData *decodedData;

		authVal = [request headers][HKHTTPHeaderAuthorization];
		if (!authVal) {
			response = @{
				@"error" : @"Missing Authorization Header",
			};
			return [HKHTTPJSONResponse responseWithJSONObject:response status:401 error:NULL];
		}

		decodedData = [[NSData data] initWithBase64EncodedString:authVal options:0];
		if (!decodedData) {
			NSDictionary<NSString *, NSString *> *headers;

			response = @{
				@"error" : @"Failed to decode the base64-encoded basic auth value",
			};
			headers = @{
				HKHTTPHeaderContentType : HKHTTPHeaderContentApplicationJSON,
				@"WWW-Authenticate" : @"Basic realm=\"vmp\"",
			};

			// When authorization fails due to a missing Authorization header,
			// the server should respond with a 401 Unauthorized status code and
			// include a WWW-Authenticate header in the response.
			return [HKHTTPJSONResponse responseWithJSONObject:response
													   status:500
													  headers:headers
														error:NULL];
		}

		authPair = [[NSString alloc] initWithData:decodedData encoding:NSUTF8StringEncoding];
		if (!authPair) {
			response = @{
				@"error" : @"Could not convert base64-decoded Basic Auth value into a string",
			};
			return [HKHTTPJSONResponse responseWithJSONObject:response status:500 error:NULL];
		}

		NSLog(@"authVal: %@ decodedData: %@ authPair %@", authVal, decodedData, authPair);

		// Find the first occurrence of ":" to separate username from password
		// Note that the username must not contain a colon (See. RFC7617 for addtional details).
		NSRange range = [authPair rangeOfString:@":"];
		if (range.location != NSNotFound) {
			NSString *username;
			NSString *password;

			username = [authPair substringToIndex:range.location];
			password = [authPair substringFromIndex:range.location + range.length];

			if ([[_configuration httpUsername] isEqual:username] &&
				[[_configuration httpPassword] isEqual:password]) {
				// Do not overwrite HTTP response in middleware
				// if authorization was successful.
				return nil;
			}

			response = @{
				@"error" : @"Invalid username are password",
			};
			return [HKHTTPJSONResponse responseWithJSONObject:response status:401 error:NULL];
		} else {
			response = @{
				@"error" :
					@"Could not find username password seperator (:) in decoded basic auth value",
			};
			return [HKHTTPJSONResponse responseWithJSONObject:response status:401 error:NULL];
		}
	};
}

- (HKHandlerBlock)_statusHandlerV1 {
	return ^HKHTTPResponse *(HKHTTPRequest *request) {
		VMPProfileModel *profile;
		HKHTTPJSONResponse *response;
		profile = [_profileMgr currentProfile];

		NSDictionary *data = @{
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

		response = [HKHTTPJSONResponse responseWithJSONObject:data status:200 error:NULL];
		[response setHeaders:DEFAULT_HEADERS];
		return response;
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
		NSString *format;
		NSData *pipelineDot;
		NSDictionary *headers;
		VMPPipelineManager *mgr;

		channel = [request queryParameters][@"channel"];
		format = [request queryParameters][@"format"];

		if (!channel) {
			NSDictionary *response = @{
				@"error" : @"Missing channel parameter",
			};
			return [HKHTTPJSONResponse responseWithJSONObject:response status:400 error:NULL];
		}
		if (!format) {
			format = @"svg";
		}
		format = [format lowercaseString];

		mgr = [_rtspServer pipelineManagerForChannel:channel];
		if (!mgr) {
			NSDictionary *response = @{
				@"error" : @"Channel not found",
			};
			return [HKHTTPJSONResponse responseWithJSONObject:response status:404 error:NULL];
		}

		pipelineDot = [mgr pipelineDotGraph];

		if ([format isEqualToString:@"svg"]) {
			NSError *error;
			NSData *svgData;

			svgData = convertDOTtoSVG(pipelineDot, &error);
			if (!svgData) {
				NSDictionary *response = @{
					@"error" : [error localizedDescription],
				};
				return [HKHTTPJSONResponse responseWithJSONObject:response status:500 error:NULL];
			}

			headers = @{
				@"Content-Type" : @"image/svg+xml",
			};

			return [[HKHTTPResponse alloc] initWithData:svgData headers:headers status:200];
		} else if ([format isEqualToString:@"dot"]) {
			headers = @{
				@"Content-Type" : @"text/plain",
			};

			return [[HKHTTPResponse alloc] initWithData:pipelineDot headers:headers status:200];
		}

		NSDictionary *response = @{
			@"error" : @"Invalid format parameter",
		};
		return [HKHTTPJSONResponse responseWithJSONObject:response status:400 error:NULL];
	};
}

- (HKHandlerBlock)_mountpointGraphHandlerV1 {
	return ^HKHTTPResponse *(HKHTTPRequest *request) {
		NSString *mountpoint;
		NSString *format;
		NSDictionary *headers;
		NSData *data;

		mountpoint = [request queryParameters][@"mountpoint"];
		format = [request queryParameters][@"format"];

		if (!mountpoint) {
			NSDictionary *response = @{
				@"error" : @"Missing mountpoint parameter",
			};
			return [HKHTTPJSONResponse responseWithJSONObject:response status:400 error:NULL];
		}
		if (!format) {
			format = @"svg";
		}
		format = [format lowercaseString];

		data = [_rtspServer dotGraphForMountPointName:mountpoint];
		if (!data) {
			NSDictionary *response = @{
				@"error" : @"Mountpoint not found",
			};
			return [HKHTTPJSONResponse responseWithJSONObject:response status:404 error:NULL];
		}

		if ([format isEqualToString:@"svg"]) {
			NSError *error;
			NSData *svgData;

			svgData = convertDOTtoSVG(data, &error);
			if (!svgData) {
				NSDictionary *response = @{
					@"error" : [error localizedDescription],
				};
				return [HKHTTPJSONResponse responseWithJSONObject:response status:500 error:NULL];
			}

			headers = @{
				@"Content-Type" : @"image/svg+xml",
			};

			return [[HKHTTPResponse alloc] initWithData:svgData headers:headers status:200];
		} else if ([format isEqualToString:@"dot"]) {
			headers = @{
				@"Content-Type" : @"text/plain",
			};

			return [[HKHTTPResponse alloc] initWithData:data headers:headers status:200];
		}

		NSDictionary *response = @{
			@"error" : @"Invalid format parameter",
		};
		return [HKHTTPJSONResponse responseWithJSONObject:response status:400 error:NULL];
	};
}

/*
 * POST /api/v1/recording/create
 *
 * Example request body:
 * {
 *  "videoChannel": "present0",
 *  "audioChannel": "audio0",
 *  "stopAt": "2024-03-11T13:06:00Z"
 * }
 *
 * Example response:
 * {
 *	"status": "ok",
 *	"numberOfSeconds": 62.94332504272461,
 *	"stopAt": "2024-03-11T13:06:00+0000",
 *	"startAt": "2024-03-11T13:04:57+0000",
 *	"path": "/tmp/recording_2024-03-11T13:04:57+0000.mkv"
 * }
 *
 * TODO: Add option to schedule a recording at a later date
 */
- (HKHandlerBlock)_recordingCreateV1 {
	return ^HKHTTPResponse *(HKHTTPRequest *request) {
		id decodedBody;
		NSError *error = nil;
		NSMutableDictionary *recordingOptions;

		// Check if scratchDirectory is set
		if ([[_configuration scratchDirectory] length] == 0) {
			NSDictionary *response = @{
				@"error" : @"No scratch directory set",
			};
			return [HKHTTPJSONResponse responseWithJSONObject:response status:500 error:NULL];
		}

		decodedBody = [NSJSONSerialization JSONObjectWithData:[request HTTPBody]
													 options:0
													   error:NULL];
		if (!decodedBody) {
			NSDictionary *response = @{
				@"error" : @"Failed to decode JSON body",
			};
			return [HKHTTPJSONResponse responseWithJSONObject:response status:400 error:NULL];
		}

		if (![decodedBody isKindOfClass:[NSDictionary class]]) {
			NSDictionary *response = @{
				@"error" : @"Invalid JSON body",
			};
			return [HKHTTPJSONResponse responseWithJSONObject:response status:400 error:NULL];
		}
		recordingOptions = [decodedBody mutableCopy];

		// Validate the body
		NSString *videoChannel = recordingOptions[@"videoChannel"];
		NSString *audioChannel = recordingOptions[@"audioChannel"];
		NSString *stopAt = recordingOptions[@"stopAt"];

		if (!videoChannel || !audioChannel || !stopAt) {
			NSDictionary *response = @{
				@"error" : @"Missing required parameters",
			};
			return [HKHTTPJSONResponse responseWithJSONObject:response status:400 error:NULL];
		}

		NSDateFormatter *isoFormatter = [[NSDateFormatter alloc] init];
		NSDate *stopAtDate;

		[isoFormatter setDateFormat: @"yyyy-MM-dd'T'HH:mm:ssZ"];

		stopAtDate = [isoFormatter dateFromString:stopAt];
		if (!stopAtDate) {
			NSDictionary *response = @{
				@"error" : @"Invalid ISO8601 date in 'stopAt' value",
			};
			return [HKHTTPJSONResponse responseWithJSONObject:response status:400 error:NULL];
		}
		
		// Check if stop date is reasonable (not more then 8 hours in the future)
		// TODO: Add option to define this in configuration
		if ([stopAtDate timeIntervalSinceNow] > 8 * 60 * 60) {
			NSDictionary *response = @{
				@"error" : @"Stop date is too far in the future > 8 hours",
			};
			return [HKHTTPJSONResponse responseWithJSONObject:response status:400 error:NULL];
		}
		
		// Create a new recording with default options
		// TODO: Allow for user to specify options
		[recordingOptions addEntriesFromDictionary:@{
			@"videoBitrate" : @2500,
			@"audioBitrate" : @96,
			@"scaledWidth" : @1920,
			@"scaledHeight" : @1080
		}];

		NSURL *url;
		NSDate *now;
		VMPRecordingManager *recording;

		now = [NSDate date];
		url = [NSURL fileURLWithPathComponents:@[
			[_configuration scratchDirectory],
			[NSString stringWithFormat:@"recording_%@.mkv", [isoFormatter stringFromDate: now]]
		]];

		recording = [_rtspServer defaultRecordingWithOptions:recordingOptions
											path:url
										deadline:stopAtDate
										   error:&error];
		if (!recording) {
			NSString *desc;

			desc = [NSString stringWithFormat:@"Failed to create recording: %@", [error localizedDescription]];
			NSDictionary *response = @{
				@"error" : desc
			};
			return [HKHTTPJSONResponse responseWithJSONObject:response status:500 error:NULL];
		}

		if (![_rtspServer scheduleRecording: recording]) {
			NSDictionary *response = @{
				@"error" : @"Failed to schedule recording"
			};
			return [HKHTTPJSONResponse responseWithJSONObject:response status:500 error:NULL];
		}

		return [HKHTTPJSONResponse responseWithJSONObject:@{
			@"status" : @"ok",
			@"path" : [url path],
			@"startAt": [isoFormatter stringFromDate:now],
			@"stopAt" : [isoFormatter stringFromDate:stopAtDate],
			@"numberOfSeconds": @([stopAtDate timeIntervalSinceDate:now])
		} status:200 error:NULL];
	};
}

- (void)setupHTTPHandlers {
	HKRouter *router;
	HKRoute *statusRoute;
	HKRoute *configRoute;
	HKRoute *channelGraphRoute;
	HKRoute *mountpointGraphRoute;
	HKRoute *recordingCreateRoute;
	HKHandlerBlock CORSHandler;

	router = [_httpServer router];
	CORSHandler = [self _corsHandlerV1];

	// The middleware is called after the initial
	// request was parsed and checked against the
	// list of known routes.
	//
	// The middleware is responsible for
	// authentication.
	if ([[_configuration httpAuth] boolValue]) {
		[router setMiddleware:[self _middleware]];
	}

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
	// GET /api/v1/mountpoint/graph
	mountpointGraphRoute = [HKRoute routeWithPath:@"/api/v1/mountpoint/graph"
										   method:HKHTTPMethodGET
										  handler:[self _mountpointGraphHandlerV1]];
	// POST /api/v1/recording/create
	recordingCreateRoute = [HKRoute routeWithPath:@"/api/v1/recording/create"
											method:HKHTTPMethodPOST
										   handler:[self _recordingCreateV1]];
	

	[router registerRoute:statusRoute withCORSHandler:CORSHandler];
	[router registerRoute:configRoute withCORSHandler:CORSHandler];
	[router registerRoute:channelGraphRoute withCORSHandler:CORSHandler];
	[router registerRoute:mountpointGraphRoute withCORSHandler:CORSHandler];
	[router registerRoute:recordingCreateRoute withCORSHandler:CORSHandler];
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