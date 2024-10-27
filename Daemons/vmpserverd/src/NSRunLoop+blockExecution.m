/* vmpserverd - A virtual multimedia processor
 * Copyright (C) 2024 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import "NSRunLoop+blockExecution.h"

@implementation NSRunLoop (BlockExecution)

- (void)scheduleBlock:(BOOL (^)(void))block
		 initialDelay:(NSTimeInterval)initialDelay
	   delayIncrement:(NSTimeInterval)delayIncrement
			 maxDelay:(NSTimeInterval)maxDelay {
	NSMutableDictionary *userInfo = [@{
		@"block" : [block copy],
		@"delayIncrement" : @(delayIncrement),
		@"maxDelay" : @(maxDelay),
		@"currentDelay" : @(initialDelay)
	} mutableCopy];

	[self performSelector:@selector(executeBlockWithUserInfo:)
			   withObject:userInfo
			   afterDelay:initialDelay];
}

- (void)executeBlockWithUserInfo:(NSMutableDictionary *)userInfo {
	BOOL (^block)(void) = userInfo[@"block"];
	NSTimeInterval delayIncrement = [userInfo[@"delayIncrement"] doubleValue];
	NSTimeInterval maxDelay = [userInfo[@"maxDelay"] doubleValue];
	NSTimeInterval currentDelay = [userInfo[@"currentDelay"] doubleValue];

	BOOL shouldStop = block();
	if (!shouldStop) {
		currentDelay = MIN(currentDelay + delayIncrement, maxDelay);
		userInfo[@"currentDelay"] = @(currentDelay);
		[self performSelector:@selector(executeBlockWithUserInfo:)
				   withObject:userInfo
				   afterDelay:currentDelay];
	}
}

@end
