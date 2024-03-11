/* vmpserverd - A virtual multimedia processor
 * Copyright (C) 2024 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import "VMPRecordingManager.h"

@implementation VMPRecordingManager {
	NSDate *_deadline;
}

+ (instancetype)recorderWithLaunchArgs:(NSString *)launchArgs
								  path:(NSURL *)path
						   recordUntil:(NSDate *)date
							  delegate:(id<VMPPipelineManagerDelegate>)delegate {
	return [[VMPRecordingManager alloc] initWithLaunchArgs:launchArgs
													  path:path
											   recordUntil:date
												  delegate:delegate];
}

- (instancetype)initWithLaunchArgs:(NSString *)launchArgs
							  path:(NSURL *)p
					   recordUntil:(NSDate *)date
						  delegate:(id<VMPPipelineManagerDelegate>)delegate {
	NSString *pseudoChannel;

	pseudoChannel = [@"_recording_" stringByAppendingString:[p path]];
	self = [super initWithLaunchArgs:launchArgs channel:pseudoChannel delegate:delegate];
	if (self) {
		_path = [p copy];
		_deadline = [date copy];
	}

	return self;
}

- (NSDate *)deadline {
	return _deadline;
}

@end
