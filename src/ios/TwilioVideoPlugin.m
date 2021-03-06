/********* TwilioVideo.m Cordova Plugin Implementation *******/

@import TwilioVideo;
#import <Cordova/CDV.h>
#import "TwilioVideoViewController.h"

@interface TwilioVideoPlugin : CDVPlugin <TwilioVideoViewControllerDelegate>
@property (nonatomic, copy) NSString* callbackId;
@end


@implementation TwilioVideoPlugin

- (void)open:(CDVInvokedUrlCommand*)command {
    NSString* room = command.arguments[0];
    NSString* token = command.arguments[1];
    NSString* remoteParticipantName = command.arguments[2];
    
    
    dispatch_async(dispatch_get_main_queue(), ^{
        UIStoryboard *sb = [UIStoryboard storyboardWithName:@"TwilioVideo" bundle:nil];
        TwilioVideoViewController *vc = [sb instantiateViewControllerWithIdentifier:@"TwilioVideoViewController"];
        self.callbackId = command.callbackId;
        vc.delegate = self;
        vc.accessToken = token;
        vc.remoteParticipantName = remoteParticipantName;
       // UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
      //  [vc.navigationItem setRightBarButtonItem:[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(dismissTwilioVideoController)]];
         
        
        [self.viewController presentViewController:vc animated:YES completion:^{
            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"opened"];
            [pluginResult setKeepCallbackAsBool:YES];
            [vc connectToRoom:room];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:self.callbackId];
        }];
    });

}

- (void)getTwilioVersion:(CDVInvokedUrlCommand*)command {
  CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:[TwilioVideo version]];
  [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) dismissTwilioVideoController {
    [self.viewController dismissViewControllerAnimated: YES completion: ^ {
        if (self.callbackId != nil) {
            NSString * cbid = self.callbackId;
            self.callbackId = nil;
            CDVPluginResult * pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK  messageAsString:@"closed"];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:cbid];
        }
    }];
}

-(void) dismiss {
    [self dismissTwilioVideoController];
}

-(void) onConnected:(NSString *)participantId participantSid:(NSString *)participantSid
{
  NSDictionary *dict = @{
	@"event": @"onConnected",
	@"participantId": participantId,
	@"participantSid": participantSid,
  };
  CDVPluginResult * pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK  messageAsDictionary:dict];
  [pluginResult setKeepCallbackAsBool:YES];
  [self.commandDelegate sendPluginResult:pluginResult callbackId:self.callbackId];
}

-(void) onDisconnected:(NSString *)participantId participantSid:(NSString *)participantSid
{
  NSDictionary *dict = @{
	@"event": @"onDisconnected",
	@"participantId": participantId,
	@"participantSid": participantSid,
  };
  CDVPluginResult * pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK  messageAsDictionary:dict];
  [pluginResult setKeepCallbackAsBool:YES];
  [self.commandDelegate sendPluginResult:pluginResult callbackId:self.callbackId];
}

@end
