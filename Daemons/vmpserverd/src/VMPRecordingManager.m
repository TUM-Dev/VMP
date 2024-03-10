/* vmpserverd - A virtual multimedia processor
 * Copyright (C) 2024 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import "VMPRecordingManager.h"

NSString *const kVMPRecordingBitrate = @"recordingBitrate";

@implementation VMPRecordingManager {
	NSDate *_deadline;
}

+ (instancetype)recorderWithChannel:(NSString *)channel
							   path:(NSURL *)path
						recordUntil:(NSDate *)date
							options:(NSDictionary *)options
						   delegate:(id<VMPPipelineManagerDelegate>)delegate {
	return nil;
}

- (instancetype)initWithChannel:(NSString *)channel
						   path:(NSURL *)path
					recordUntil:(NSDate *)date
						options:(NSDictionary *)options
					   delegate:(id<VMPPipelineManagerDelegate>)delegate {
	self = [super initWithLaunchArgs:@"" channel:channel delegate:delegate];
	return self;
}


- (NSDate *)deadline {
	return nil;
}

@end
