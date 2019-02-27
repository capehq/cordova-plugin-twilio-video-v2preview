//
//  TwilioVideoViewController.swift
//
//  Copyright (C) 2019 by Cape Productions, Inc.
//
// Converted from TwilioVideoViewController.m

import Foundation
import TwilioVideo
import UIKit

protocol TwilioVideoViewControllerDelegate: NSObjectProtocol {
    func dismiss()
    func onConnected(_ participantId: String?, participantSid: String?)
    func onDisconnected(_ participantId: String?, participantSid: String?)
}

private let ANIMATION_DURATION: Double = 0.4
private let TIMER_INTERVAL: Double = 4
private let defaultOrientation: UIInterfaceOrientation = .landscapeRight

@objc(TwilioVideoViewController) class TwilioVideoViewController: UIViewController, UITextFieldDelegate, TVIRemoteParticipantDelegate, TVIRoomDelegate, TVIVideoViewDelegate {
    weak var delegate: TwilioVideoViewControllerDelegate?
    var accessToken = ""
    var remoteParticipantName = ""

    func connect(toRoom room: String?) {
        guard let room = room else {
            logMessage("Invalid room")
            return
        }
        showRoomUI(true)

        if (accessToken == "TWILIO_ACCESS_TOKEN") {
            logMessage("Fetching an access token")
            showRoomUI(false)
        } else {
            doConnect(room)
        }
    }

// MARK: Video SDK components
    private var viewedParticipant: TVIRemoteParticipant?
    private weak var remoteView: TVIVideoView?
    private var room: TVIRoom?
// MARK: UI Element Outlets and handles


    @IBOutlet private weak var disconnectButton: UIButton!
    @IBOutlet private weak var messageLabel: UILabel!
    // CS-69: Weak timer or else we get a crash on invalidate
    private weak var timer: Timer?

// MARK: - UIViewController
    override func viewDidLoad() {
        super.viewDidLoad()

        logMessage("TwilioVideo v\(TwilioVideo.version())")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // Lock to landscape orientation.
        var orientation = UIInterfaceOrientation(rawValue: UIDevice.current.orientation.rawValue)
        if orientation?.isLandscape == false {
            orientation = defaultOrientation
        }
        UIDevice.current.setValue(NSNumber(value: orientation?.rawValue ?? 0), forKey: "orientation")

        // Start icon timer
        startTimer()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // Stop any timer
        stopTimer()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if disconnectButton.isHidden {
            disconnectButton.isHidden = !disconnectButton.isHidden
            showDisconnectButton()
            startTimer()
        } else {
            resetTimer()
        }
    }

    @objc func hideDisconnectButton() {
        UIView.animate(withDuration: TimeInterval(ANIMATION_DURATION), delay: 0, options: .allowUserInteraction, animations: {
            self.disconnectButton.layer.opacity = 0.0
        }) { finished in
            if finished {
                self.disconnectButton.isHidden = !self.disconnectButton.isHidden
            }
        }
    }

    func showDisconnectButton() {
        UIView.animate(withDuration: TimeInterval(ANIMATION_DURATION), delay: 0, options: .allowUserInteraction, animations: {
            self.disconnectButton.layer.opacity = 1.0
        })
    }

    func startTimer() {
        timer = Timer.scheduledTimer(timeInterval: TimeInterval(TIMER_INTERVAL), target: self, selector: #selector(TwilioVideoViewController.hideDisconnectButton), userInfo: nil, repeats: false)
    }

    func resetTimer() {
        stopTimer()
        startTimer()
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

// MARK: - Public

    @IBAction func disconnectButtonPressed(_ sender: Any) {
        stopTimer()
        room?.disconnect()
        delegate?.dismiss()
    }

// MARK: - Private
    func doConnect(_ room: String) {
        if (accessToken == "TWILIO_ACCESS_TOKEN") {
            logMessage("Please provide a valid token to connect to a room");
            return
        }

        let connectOptions = TVIConnectOptions(token: accessToken, block: { builder in

                // The name of the Room where the Client will attempt to connect to. Please note that if you pass an empty
                // Room `name`, the Client will create one for you. You can get the name or sid from any connected Room.
                builder.roomName = room
            })

        // Connect to the Room using the options we provided.
        self.room = TwilioVideo.connect(with: connectOptions, delegate: self)

        logMessage("Attempting to connect to room \(room)")
    }

    func setupRemoteView() {
        // Creating `TVIVideoView` programmatically
        let remoteView = TVIVideoView()

        // `TVIVideoView` supports UIViewContentModeScaleToFill, UIViewContentModeScaleAspectFill and UIViewContentModeScaleAspectFit
        // UIViewContentModeScaleAspectFit is the default mode when you create `TVIVideoView` programmatically.
        self.remoteView?.contentMode = UIView.ContentMode.scaleAspectFit

        view.insertSubview(remoteView, at: 0)
        self.remoteView = remoteView

        var centerX: NSLayoutConstraint? = nil
        if let remoteView = self.remoteView {
            centerX = NSLayoutConstraint(item: remoteView, attribute: .centerX, relatedBy: .equal, toItem: view, attribute: .centerX, multiplier: 1, constant: 0)
        }
        if let centerX = centerX {
            view.addConstraint(centerX)
        }
        var centerY: NSLayoutConstraint? = nil
        if let remoteView = self.remoteView {
            centerY = NSLayoutConstraint(item: remoteView, attribute: .centerY, relatedBy: .equal, toItem: view, attribute: .centerY, multiplier: 1, constant: 0)
        }
        if let centerY = centerY {
            view.addConstraint(centerY)
        }
        var width: NSLayoutConstraint? = nil
        if let remoteView = self.remoteView {
            width = NSLayoutConstraint(item: remoteView, attribute: .width, relatedBy: .equal, toItem: view, attribute: .width, multiplier: 1, constant: 0)
        }
        if let width = width {
            view.addConstraint(width)
        }
        var height: NSLayoutConstraint? = nil
        if let remoteView = self.remoteView {
            height = NSLayoutConstraint(item: remoteView, attribute: .height, relatedBy: .equal, toItem: view, attribute: .height, multiplier: 1, constant: 0)
        }
        if let height = height {
            view.addConstraint(height)
        }
    }

    // Reset the client ui status
    func showRoomUI(_ inRoom: Bool) {
        // self.micButton.hidden = !inRoom;
        // self.disconnectButton.hidden = !inRoom;
        UIApplication.shared.isIdleTimerDisabled = inRoom
    }

    func cleanupRemoteParticipant() {
        if let viewedParticipant = viewedParticipant {
            if viewedParticipant.videoTracks.count > 0, let remoteView = remoteView {
                viewedParticipant.videoTracks[0].videoTrack?.removeRenderer(remoteView)
                remoteView.removeFromSuperview()
            }
            self.viewedParticipant = nil
            delegate?.onDisconnected(room?.localParticipant?.identity, participantSid: room?.localParticipant?.sid)
        }
    }

    func logMessage(_ msg: String?) {
        print("\(msg ?? "")")
    }

// MARK: - UITextFieldDelegate

// MARK: - TVIRoomDelegate
    func didConnect(to room: TVIRoom) {
        // At the moment, this example only supports rendering one Participant at a time.

        logMessage("Connected to room \(room.name) as \(room.localParticipant?.identity ?? "??") ... waiting on participant to join")
        messageLabel.text = remoteParticipantName
        viewedParticipant = nil
        for participant in room.remoteParticipants {
            participant.delegate = self
        }
        TwilioMonitor.set(room: room)

        delegate?.onConnected(room.localParticipant?.identity, participantSid: room.localParticipant?.sid)
    }

    func room(_ room: TVIRoom, didDisconnectWithError error: Error?) {
        cleanupRemoteParticipant()
        self.room = nil

        showRoomUI(false)
        delegate?.dismiss()
    }

    func room(_ room: TVIRoom, didFailToConnectWithError error: Error) {
        logMessage("Failed to connect to room, error = \(error)")

        self.room = nil

        showRoomUI(false)
        delegate?.dismiss()
    }

    func room(_ room: TVIRoom, participantDidConnect participant: TVIRemoteParticipant) {
        participant.delegate = self
        logMessage("Room \(room.name) participant \(participant.identity) connected")
    }

    func room(_ room: TVIRoom, participantDidDisconnect participant: TVIRemoteParticipant) {
        logMessage("Room \(room.name) participant \(participant.identity) disconnected")
        if viewedParticipant == participant {
            logMessage("Participant disconnected")
            cleanupRemoteParticipant()
            delegate?.dismiss()
        }
    }

// MARK: - TVIRemoteParticipantDelegate
    func subscribed(to videoTrack: TVIRemoteVideoTrack, publication: TVIRemoteVideoTrackPublication, for participant: TVIRemoteParticipant) {
        logMessage("Participant \(participant.identity) subscribed to video track.")

        if viewedParticipant != participant {
            cleanupRemoteParticipant()
            viewedParticipant = participant
            setupRemoteView()
            if let remoteView = remoteView {
                videoTrack.addRenderer(remoteView)
            }
        }
    }

    func unsubscribed(from videoTrack: TVIRemoteVideoTrack, publication: TVIRemoteVideoTrackPublication, for participant: TVIRemoteParticipant) {
        logMessage("Participant \(participant.identity) unsubscribed from video track.")

        if viewedParticipant == participant {
            if let remoteView = remoteView {
                videoTrack.removeRenderer(remoteView)
            }
            remoteView?.removeFromSuperview()
            cleanupRemoteParticipant()
            delegate?.dismiss()
            // TODO: This will kick us out....some ideas:
            //  1. Search for another participant with a video track (requires saving all participants or tracking in addedVideoTrack)
        }
    }

// MARK: - TVIVideoViewDelegate
    func videoView(_ view: TVIVideoView, videoDimensionsDidChange dimensions: CMVideoDimensions) {
        logMessage("Dimensions changed to: \(dimensions.width) x \(dimensions.height)")
        self.view.setNeedsLayout()
    }
}

class PlatformUtils: NSObject {
    class func isSimulator() -> Bool {
#if TARGET_IPHONE_SIMULATOR
        return true
#endif
        return false
    }
}
