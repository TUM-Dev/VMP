/* vmpserverd - A virtual multimedia processor
 * Copyright (C) 2024 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import "VMPPipelineManager.h"

/// The encoding bitrate
extern NSString *const kVMPRecordingBitrate;

/**
 * @brief Recording Manager
 *
 * A subclass of th pipeline manager that
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

+ (instancetype)recorderWithChannel:(NSString *)channel
							   path:(NSURL *)path
						recordUntil:(NSDate *)date
							options:(NSDictionary *)options
						   delegate:(id<VMPPipelineManagerDelegate>)delegate;

- (instancetype)initWithChannel:(NSString *)channel
						   path:(NSURL *)path
					recordUntil:(NSDate *)date
						options:(NSDictionary *)options
					   delegate:(id<VMPPipelineManagerDelegate>)delegate NS_DESIGNATED_INITIALIZER;

- (NSDate *)deadline;

@end
