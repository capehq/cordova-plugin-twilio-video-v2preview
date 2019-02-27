//
//  TwilioVideoPlugin.swift
//
// Copyright (C) 2019 by Cape Productions, Inc.
//
// Converted from TwilioVideoPlugin.m

import TwilioVideo

@objc(TwilioVideoPlugin) class TwilioVideoPlugin: CDVPlugin, TwilioVideoViewControllerDelegate {
    var callbackId: String?

    func open(_ command: CDVInvokedUrlCommand?) {
        let room = command?.arguments[0] as? String
        let token = command?.arguments[1] as? String
        let remoteParticipantName = command?.arguments[2] as? String

        DispatchQueue.main.async {
            let sb = UIStoryboard(name: "TwilioVideo", bundle: nil)
            if let vc = sb.instantiateViewController(withIdentifier: "TwilioVideoViewController") as? TwilioVideoViewController {
                self.callbackId = command?.callbackId
                vc.delegate = self
                vc.accessToken = token ?? ""
                vc.remoteParticipantName = remoteParticipantName ?? ""
                self.viewController.present(vc, animated: true) {
                    vc.connect(toRoom: room)
                    let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: "opened")
                    pluginResult?.keepCallback = true
                    self.commandDelegate.send(pluginResult, callbackId: self.callbackId)
                }
            }
        }

    }

    func getTwilioVersion(_ command: CDVInvokedUrlCommand?) {
        let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: TwilioVideo.version())
        commandDelegate.send(pluginResult, callbackId: command?.callbackId)
    }

    func getTwilioStats(_ command: CDVInvokedUrlCommand?) {
        TwilioMonitor.getStats { stats in
            if let stats = stats {
                print("Stats: \(stats)")
            }
            let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: stats)
            self.commandDelegate.send(pluginResult, callbackId: command?.callbackId)
        }
    }

    func dismissTwilioVideoController() {
        viewController.dismiss(animated: true) {
            if self.callbackId != nil {
                let cbid = self.callbackId
                self.callbackId = nil
                let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: "closed")
                self.commandDelegate.send(pluginResult, callbackId: cbid)
            }
        }
    }

    func dismiss() {
        dismissTwilioVideoController()
    }

    func onConnected(_ participantId: String?, participantSid: String?) {
        let dict = [
            "event": "onConnected",
            "participantId": participantId,
            "participantSid": participantSid
        ]
        let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: dict as [AnyHashable : Any])
        pluginResult?.keepCallback = true
        commandDelegate.send(pluginResult, callbackId: callbackId)
    }

    func onDisconnected(_ participantId: String?, participantSid: String?) {
        let dict = [
            "event": "onDisconnected",
            "participantId": participantId,
            "participantSid": participantSid
        ]
        let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: dict as [AnyHashable : Any])
        pluginResult?.keepCallback = true
        commandDelegate.send(pluginResult, callbackId: callbackId)
    }
}
