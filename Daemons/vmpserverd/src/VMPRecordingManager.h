/* vmpserverd - A virtual multimedia processor
 * Copyright (C) 2024 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import "VMPPipelineManager.h"

/**
 * @brief Recording Manager
 *
 * A subclass of the pipeline manager that
 * has extensions for recording to a
 * file.
 */
@interface VMPRecordingManager : VMPPipelineManager

/**
 * Absolute destination path of recording.
 */
@property (nonatomic, readonly) NSURL *path;

/**
 * Additional recording and encoding options.
 */
@property (nonatomic, readonly) NSDictionary *options;

@property (atomic, assign) BOOL eosReceived;

+ (instancetype)recorderWithLaunchArgs:(NSString *)launchArgs
								  path:(NSURL *)path
						   recordUntil:(NSDate *)date
							  delegate:(id<VMPPipelineManagerDelegate>)delegate;

- (instancetype)initWithLaunchArgs:(NSString *)launchArgs
							  path:(NSURL *)path
					   recordUntil:(NSDate *)date
						  delegate:(id<VMPPipelineManagerDelegate>)delegate
	NS_DESIGNATED_INITIALIZER;

- (NSDate *)deadline;

@end
