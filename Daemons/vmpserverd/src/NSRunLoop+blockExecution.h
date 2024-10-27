/* vmpserverd - A virtual multimedia processor
 * Copyright (C) 2024 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import <Foundation/Foundation.h>

@interface NSRunLoop (blockExecution)

/**
 * Schedules a block to be executed with an initial delay, increasing the delay after each execution
 * until a maximum delay is reached or the block returns YES.
 *
 * @param block The block to execute, which returns a BOOL. Return NO to continue execution with an
 * increased delay, or YES to stop further executions.
 * @param initialDelay The initial delay before the block is first executed.
 * @param delayIncrement The amount by which the delay is increased after each execution.
 * @param maxDelay The maximum delay between executions.
 */
- (void)scheduleBlock:(BOOL (^)(void))block
		 initialDelay:(NSTimeInterval)initialDelay
	   delayIncrement:(NSTimeInterval)delayIncrement
			 maxDelay:(NSTimeInterval)maxDelay;

@end
