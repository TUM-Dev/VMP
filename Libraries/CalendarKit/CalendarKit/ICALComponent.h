/* CalendarKit - An ObjC wrapper around libical
 * Copyright (C) 2024 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import <Foundation/NSData.h>
#import <Foundation/NSEnumerator.h>
#import <Foundation/NSError.h>
#import <Foundation/NSObjCRuntime.h>
#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>

// Class reference to avoid cyclic dependency
@class ICALProperty;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, ICALComponentKind) {
	ICALComponentKindPlaceholder,
	/// Used to select all components
	ICALComponentKindAny,
	ICALComponentKindXROOT,
	/// MIME attached data, returned by parser
	ICALComponentKindXATTACH,
	ICALComponentKindVEVENT,
	ICALComponentKindVTODO,
	ICALComponentKindVJOURNAL,
	ICALComponentKindVCALENDAR,
	ICALComponentKindVAGENDA,
	ICALComponentKindVFREEBUSY,
	ICALComponentKindVALARM,
	ICALComponentKindXAUDIOALARM,
	ICALComponentKindXDISPLAYALARM,
	ICALComponentKindXEMAILALARM,
	ICALComponentKindXPROCEDUREALARM,
	ICALComponentKindVTIMEZONE,
	ICALComponentKindXSTANDARD,
	ICALComponentKindXDAYLIGHT,
	ICALComponentKindX,
	ICALComponentKindVSCHEDULE,
	ICALComponentKindVQUERY,
	ICALComponentKindVREPLY,
	ICALComponentKindVCAR,
	ICALComponentKindVCOMMAND,
	ICALComponentKindXLICINVALID,
	ICALComponentKindXLICMIMEPART,
	ICALComponentKindVAVAILABILITY,
	ICALComponentKindXAVAILABLE,
	ICALComponentKindVPOLL,
	ICALComponentKindVVOTER,
	ICALComponentKindXVOTE,
	ICALComponentKindVPATCH,
	ICALComponentKindXPATCH
};

@interface ICALComponent : NSObject <NSCopying> {
	void *_handle;
	ICALComponent *_Nullable _root;
}

+ (instancetype)componentWithData:(NSData *)data error:(NSError **)error;

- (instancetype)initWithData:(NSData *)data error:(NSError **)error;

- (ICALComponentKind)kind;

- (NSString *_Nullable)uid;

- (NSString *_Nullable)summary;

- (id)copyWithZone:(NSZone *)zone;

- (NSInteger)numberOfChildren;
- (NSInteger)numberOfProperties;

- (void)enumerateComponentsUsingBlock:(void (^)(ICALComponent *component, BOOL *stop))block;
- (void)enumeratePropertiesUsingBlock:(void (^)(ICALProperty *property, BOOL *stop))block;

@end

NS_ASSUME_NONNULL_END
