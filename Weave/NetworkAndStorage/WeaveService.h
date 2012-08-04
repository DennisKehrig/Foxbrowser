//
//  SGWeaveService.h
//  Foxbrowser
//
//  Created by simon on 10.07.12.
//  Copyright (c) 2012 Simon Grätzer. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol WeaveService <NSObject>

//put up an alert explaining what just went wrong
- (void) reportErrorWithInfo: (NSDictionary*)errInfo;

//put up an alert view specific to authentication issues, allowing the user to either ignore the problem, or sign out
- (void) reportAuthErrorWithMessage: (NSDictionary*)errInfo;

- (BOOL) canConnectToInternet;

- (void) startProgressSpinnersWithMessage:(NSString*)msg;
- (void) changeProgressSpinnersMessage:(NSString*)msg;
- (void) stopProgressSpinners;

- (void) login;
- (void) refreshViews;
- (void) eraseAllUserData;

- (void)performSelectorOnMainThread:(SEL)aSelector withObject:(id)arg waitUntilDone:(BOOL)wait;
@end

extern NSString *kWeaveDataRefreshNotification;
extern NSString *kWeaveSyncStatusChangedNotification;
extern NSString *kWeaveMessageKey;

extern id<WeaveService> weaveService;

@interface WeaveOperations : NSObject

+ (NSURL *)parseURLString:(NSString *)input;
+ (BOOL)handleURLInternal:(NSURL *)url;

@end