/* vmp-server - A virtual multimedia processor
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import "VMPServerMain.h"
#include "VMPConfigModel.h"
#import "VMPJournal.h"
#import "VMPProfileManager.h"
#import "VMPRTSPServer.h"

#import <glib.h>

@implementation VMPServerMain {
	VMPRTSPServer *_rtspServer;
	VMPProfileManager *_profileMgr;
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

		_rtspServer = [VMPRTSPServer serverWithConfiguration:configuration
													 profile:[_profileMgr currentProfile]];
	}

	return self;
}

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

	return YES;
}

@end