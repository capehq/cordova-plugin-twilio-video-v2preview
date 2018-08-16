//
//  TwilioVideoViewController.m
//
//  Copyright © 2016-2017 Twilio, Inc. All rights reserved.
//

@import TwilioVideo;
#import "TwilioVideoViewController.h"


#import <Foundation/Foundation.h>

@interface PlatformUtils : NSObject

+ (BOOL)isSimulator;

@end

@implementation PlatformUtils

+ (BOOL)isSimulator {
#if TARGET_IPHONE_SIMULATOR
    return YES;
#endif
    return NO;
}

@end

@interface TwilioVideoViewController () <UITextFieldDelegate, TVIParticipantDelegate, TVIRoomDelegate, TVIVideoViewDelegate, TVICameraCapturerDelegate>

#pragma mark Video SDK components

@property (nonatomic, strong) TVIParticipant *viewedParticipant;
@property (nonatomic, weak) TVIVideoView *remoteView;
@property (nonatomic, strong) TVIRoom *room;

#pragma mark UI Element Outlets and handles



@property (nonatomic, weak) IBOutlet UIButton *disconnectButton;
@property (nonatomic, weak) IBOutlet UILabel *messageLabel;

@property (nonatomic, assign) NSTimer *timer;

@end

@implementation TwilioVideoViewController
@synthesize delegate;

#pragma mark - UIViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self logMessage:[NSString stringWithFormat:@"TwilioVideo v%@", [TwilioVideo version]]];
    
    // Configure access token manually for testing, if desired! Create one manually in the console
    //  self.accessToken = @"TWILIO_ACCESS_TOKEN";

    [self startTimer];
    
}

- (void)viewDidAppear:(BOOL)animated {

    // Lock to landscape orientation.

    [[UIDevice currentDevice] setValue:
     [NSNumber numberWithInteger: UIInterfaceOrientationLandscapeLeft]
                                forKey:@"orientation"];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if(self.disconnectButton.hidden) {
        self.disconnectButton.hidden = !self.disconnectButton.hidden;
        [self showDisconnectButton];
        [self startTimer];
    } else {
        [self resetTimer];
    }
}

-(void)hideDisconnectButton {
    [UIView animateWithDuration:0.4 delay:0 options:UIViewAnimationOptionAllowUserInteraction animations:^{
        self.disconnectButton.layer.opacity = 0.0f;
    } completion: ^(BOOL finished) {
        if(finished) {
            self.disconnectButton.hidden = !self.disconnectButton.hidden;
        }
    }];
}

-(void)showDisconnectButton {
    [UIView animateWithDuration:0.4 delay:0 options:UIViewAnimationOptionAllowUserInteraction animations:^{
        self.disconnectButton.layer.opacity = 1.0f;
    } completion: nil];
}

-(void)startTimer {
    self.timer = [NSTimer scheduledTimerWithTimeInterval:4 target:self selector:@selector(hideDisconnectButton) userInfo:nil repeats:NO];
}

-(void)resetTimer {
    [self.timer invalidate];
    self.timer = nil;
    [self startTimer];
}

#pragma mark - Public
    
- (void)connectToRoom:(NSString*)room {
    [self showRoomUI:YES];
    
    if ([self.accessToken isEqualToString:@"TWILIO_ACCESS_TOKEN"]) {
        [self logMessage:[NSString stringWithFormat:@"Fetching an access token"]];
        [self showRoomUI:NO];
    } else {
        [self doConnect:room];
    }
}

- (IBAction)disconnectButtonPressed:(id)sender {
    [self.room disconnect];
    [self.delegate dismiss];
}

#pragma mark - Private

- (void)doConnect:(NSString*)room {
    if ([self.accessToken isEqualToString:@"TWILIO_ACCESS_TOKEN"]) {
        //   [self logMessage:@"Please provide a valid token to connect to a room"];
        return;
    }

    TVIConnectOptions *connectOptions = [TVIConnectOptions optionsWithToken:self.accessToken
                                                                      block:^(TVIConnectOptionsBuilder * _Nonnull builder) {
                                                                          
                                                                          // The name of the Room where the Client will attempt to connect to. Please note that if you pass an empty
                                                                          // Room `name`, the Client will create one for you. You can get the name or sid from any connected Room.
                                                                          builder.roomName = room;
                                                                      }];
    
    // Connect to the Room using the options we provided.
    self.room = [TwilioVideo connectWithOptions:connectOptions delegate:self];
    
    //   [self logMessage:[NSString stringWithFormat:@"Attempting to connect to room %@", room]];
}

- (void)setupRemoteView {
    // Creating `TVIVideoView` programmatically
    TVIVideoView *remoteView = [[TVIVideoView alloc] init];
    
    // `TVIVideoView` supports UIViewContentModeScaleToFill, UIViewContentModeScaleAspectFill and UIViewContentModeScaleAspectFit
    // UIViewContentModeScaleAspectFit is the default mode when you create `TVIVideoView` programmatically.
    self.remoteView.contentMode = UIViewContentModeScaleAspectFit;
    
    [self.view insertSubview:remoteView atIndex:0];
    self.remoteView = remoteView;
    
    NSLayoutConstraint *centerX = [NSLayoutConstraint constraintWithItem:self.remoteView
                                                               attribute:NSLayoutAttributeCenterX
                                                               relatedBy:NSLayoutRelationEqual
                                                                  toItem:self.view
                                                               attribute:NSLayoutAttributeCenterX
                                                              multiplier:1
                                                                constant:0];
    [self.view addConstraint:centerX];
    NSLayoutConstraint *centerY = [NSLayoutConstraint constraintWithItem:self.remoteView
                                                               attribute:NSLayoutAttributeCenterY
                                                               relatedBy:NSLayoutRelationEqual
                                                                  toItem:self.view
                                                               attribute:NSLayoutAttributeCenterY
                                                              multiplier:1
                                                                constant:0];
    [self.view addConstraint:centerY];
    NSLayoutConstraint *width = [NSLayoutConstraint constraintWithItem:self.remoteView
                                                             attribute:NSLayoutAttributeWidth
                                                             relatedBy:NSLayoutRelationEqual
                                                                toItem:self.view
                                                             attribute:NSLayoutAttributeWidth
                                                            multiplier:1
                                                              constant:0];
    [self.view addConstraint:width];
    NSLayoutConstraint *height = [NSLayoutConstraint constraintWithItem:self.remoteView
                                                              attribute:NSLayoutAttributeHeight
                                                              relatedBy:NSLayoutRelationEqual
                                                                 toItem:self.view
                                                              attribute:NSLayoutAttributeHeight
                                                             multiplier:1
                                                               constant:0];
    [self.view addConstraint:height];
}

// Reset the client ui status
- (void)showRoomUI:(BOOL)inRoom {
    // self.micButton.hidden = !inRoom;
    // self.disconnectButton.hidden = !inRoom;
    [UIApplication sharedApplication].idleTimerDisabled = inRoom;
}

- (void)cleanupRemoteParticipant {
    if (self.viewedParticipant) {
        if ([self.viewedParticipant.videoTracks count] > 0) {
            [self.viewedParticipant.videoTracks[0] removeRenderer:self.remoteView];
            [self.remoteView removeFromSuperview];
        }
        self.viewedParticipant = nil;
    }
}

- (void)logMessage:(NSString *)msg {
    NSLog(@"%@", msg);
}

#pragma mark - UITextFieldDelegate

#pragma mark - TVIRoomDelegate

- (void)didConnectToRoom:(TVIRoom *)room {
    // At the moment, this example only supports rendering one Participant at a time.
    
    // [self logMessage:[NSString stringWithFormat:@"Connected to room %@ as %@", room.name, room.localParticipant.identity]];
    [self logMessage:@"Waiting on participant to join"];
    self.messageLabel.text = self.remoteParticipantName;
    self.viewedParticipant = nil;
    for (TVIParticipant* participant in room.participants) {
        participant.delegate = self;
    }
}

- (void)room:(TVIRoom *)room didDisconnectWithError:(nullable NSError *)error {
    // [self logMessage:[NSString stringWithFormat:@"Disconncted from room %@, error = %@", room.name, error]];
    
    [self cleanupRemoteParticipant];
    self.room = nil;
    
    [self showRoomUI:NO];
    [self.delegate dismiss];
}

- (void)room:(TVIRoom *)room didFailToConnectWithError:(nonnull NSError *)error{
    //  [self logMessage:[NSString stringWithFormat:@"Failed to connect to room, error = %@", error]];
    
    self.room = nil;
    
    [self showRoomUI:NO];
    [self.delegate dismiss];
}

- (void)room:(TVIRoom *)room participantDidConnect:(TVIParticipant *)participant {
    participant.delegate = self;
    //   [self logMessage:[NSString stringWithFormat:@"Room %@ participant %@ connected", room.name, participant.identity]];
}

- (void)room:(TVIRoom *)room participantDidDisconnect:(TVIParticipant *)participant {
    // [self logMessage:[NSString stringWithFormat:@"Room %@ participant %@ disconnected", room.name, participant.identity]];
    if (self.viewedParticipant == participant) {
        [self logMessage:@"Participant disconnected"];
        [self cleanupRemoteParticipant];
        [self.delegate dismiss];
    }
}

#pragma mark - TVIParticipantDelegate

- (void)participant:(TVIParticipant *)participant addedVideoTrack:(TVIVideoTrack *)videoTrack {
    //   [self logMessage:[NSString stringWithFormat:@"Participant %@ added video track.", participant.identity]];
  
    if (self.viewedParticipant != participant) {
		[self cleanupRemoteParticipant];
        self.viewedParticipant = participant;
        [self setupRemoteView];
        [videoTrack addRenderer:self.remoteView];
    }
}

- (void)participant:(TVIParticipant *)participant removedVideoTrack:(TVIVideoTrack *)videoTrack {
    //   [self logMessage:[NSString stringWithFormat:@"Participant %@ removed video track.", participant.identity]];
    
    if (self.viewedParticipant == participant) {
        [videoTrack removeRenderer:self.remoteView];
        [self.remoteView removeFromSuperview];
        [self cleanupRemoteParticipant];
        [self.delegate dismiss];
		// TODO: This will kick us out....some ideas:
		//  1. Search for another participant with a video track (requires saving all participants or tracking in addedVideoTrack)
    }
}

- (void)participant:(TVIParticipant *)participant addedAudioTrack:(TVIAudioTrack *)audioTrack {
    //  [self logMessage:[NSString stringWithFormat:@"Participant %@ added audio track.", participant.identity]];
}

- (void)participant:(TVIParticipant *)participant removedAudioTrack:(TVIAudioTrack *)audioTrack {
    //  [self logMessage:[NSString stringWithFormat:@"Participant %@ removed audio track.", participant.identity]];
}

- (void)participant:(TVIParticipant *)participant enabledTrack:(TVITrack *)track {
    NSString *type = @"";
    if ([track isKindOfClass:[TVIAudioTrack class]]) {
        type = @"audio";
    } else {
        type = @"video";
    }
    //  [self logMessage:[NSString stringWithFormat:@"Participant %@ enabled %@ track.", participant.identity, type]];
}

- (void)participant:(TVIParticipant *)participant disabledTrack:(TVITrack *)track {
    NSString *type = @"";
    if ([track isKindOfClass:[TVIAudioTrack class]]) {
        type = @"audio";
    } else {
        type = @"video";
    }
    //  [self logMessage:[NSString stringWithFormat:@"Participant %@ disabled %@ track.", participant.identity, type]];
}

#pragma mark - TVIVideoViewDelegate

- (void)videoView:(TVIVideoView *)view videoDimensionsDidChange:(CMVideoDimensions)dimensions {
    NSLog(@"Dimensions changed to: %d x %d", dimensions.width, dimensions.height);
    [self.view setNeedsLayout];
}

@end
