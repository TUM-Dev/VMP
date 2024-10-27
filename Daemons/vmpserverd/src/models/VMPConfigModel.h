/* vmpserverd - A virtual multimedia processor
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import <Foundation/Foundation.h>

#import "VMPConfigChannelModel.h"
#import "VMPConfigMountpointModel.h"
#import "VMPPropertyListProtocol.h"

@interface VMPConfigModel : NSObject <VMPPropertyListProtocol>

@property (nonatomic, strong) NSString *name;

@property (nonatomic, strong) NSString *profileDirectory;

@property (nonatomic, strong) NSString *scratchDirectory;

@property (nonatomic, strong) NSString *icalURL;

@property (nonatomic, strong) NSString *rtspAddress;

@property (nonatomic, strong) NSString *rtspPort;

@property (nonatomic, strong) NSString *httpPort;

@property (nonatomic, strong) NSNumber *httpAuth;

@property (nonatomic, strong) NSString *httpUsername;

@property (nonatomic, strong) NSString *httpPassword;

@property (nonatomic, strong) NSString *gstDebug;

@property (nonatomic, strong) NSArray<id> *locations;

@property (nonatomic, strong) NSArray<VMPConfigMountpointModel *> *mountpoints;

@property (nonatomic, strong) NSArray<VMPConfigChannelModel *> *channels;

- (NSArray *)propertyListMountpoints;
- (NSArray *)propertyListChannels;

- (id)initWithPropertyList:(id)propertyList error:(NSError **)error;

- (id)propertyList;

@end