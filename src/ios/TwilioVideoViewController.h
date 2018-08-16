//
//  TwilioVideoViewController.h
//
//  Copyright © 2016-2017 Twilio, Inc. All rights reserved.
//

@import UIKit;

@protocol TwilioVideoViewControllerDelegate <NSObject>
-(void)dismiss;
@end

@interface TwilioVideoViewController : UIViewController
extern const double ANIMATION_DURATION;
extern const double TIMER_INTERVAL;
@property (assign) id <TwilioVideoViewControllerDelegate> delegate;
@property (nonatomic, strong) NSString *accessToken;
@property (nonatomic, strong) NSString *remoteParticipantName;

- (void)connectToRoom:(NSString*)room ;

@end
