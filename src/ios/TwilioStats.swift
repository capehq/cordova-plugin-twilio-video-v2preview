//
//  TwilioStats.swift
//
//  Created by Dan Homerick on 1/11/19.
//  Copyright (c) 2019 Cape Productions, Inc. All rights reserved.
//

import TwilioVideo

enum TwilioRegion: String, Codable {
    case unrecognized
    case australia
    case brazil
    case germany
    case ireland
    case india
    case japan
    case singapore
    case usaEastCoast
    case usaWestCoast
}

/// Similar to TVIStatsReport, but allows us more control. In particular, we want to create our own reports which
/// include bitrates as bps, rather than just total bytes sent. Additionally, we want to cut some arrays down to just
/// a single item, for improved logging.
final class TwilioStats: Encodable, Equatable {
    public let peerConnectionId: String
    public let timestamp: Double
    public var region: TwilioRegion? // Region of the Twilio room

    public var remoteVideo: TVIRemoteVideoTrackStats?
    public var candidatePair: TVIIceCandidatePairStats?
    public var localCandidate: TVIIceCandidateStats?
    public var remoteCandidate: TVIIceCandidateStats?
    public var otherCandidates: [TVIIceCandidateStats]?

    // Stats for lastest sample period
    public var samplePeriod: Double?
    public var bpsReceived: UInt?
    public var packetLossRatio: Double? // packetsLost : packetsSent -- for latest sample period only

    /**
     - parameters:
     - current: Most up to date stats report
     - previous: Previous stats report. For best results, should be from approximately one second prior.
     - ignoreCandidates: Used to prevent repeatedly logging unused candidates. Candidates in this set will be omitted from otherCandidates
     array. If a candidate is part of the active candidate pair (local or remote), it will be included regardless.
     */
    public init(current: TVIStatsReport, previous: TVIStatsReport?, ignoreCandidates: Set<String>?) {
        peerConnectionId = current.peerConnectionId

        remoteVideo = current.remoteVideoTrackStats.first
        if current.remoteVideoTrackStats.count > 1 {
            NSLog("Only reporting first remote video track out of \(current.remoteVideoTrackStats.count)")
        }

        timestamp = remoteVideo?.timestamp ?? NSDate().timeIntervalSince1970

        for pair in current.iceCandidatePairStats where pair.isActiveCandidatePair {
            candidatePair = pair
            break
        }
        if candidatePair == nil {
            NSLog("No active candidate pair found. Using first of \(current.iceCandidatePairStats.count) pairs.")
            candidatePair = current.iceCandidatePairStats.first
        }

        if let localCandidateId = candidatePair?.localCandidateId {
            for candidate in current.iceCandidateStats where candidate.transportId == localCandidateId {
                localCandidate = candidate
                break
            }
        }

        if let remoteCandidateId = candidatePair?.remoteCandidateId {
            for candidate in current.iceCandidateStats where candidate.transportId == remoteCandidateId {
                remoteCandidate = candidate
                break
            }
        }

        if let remoteIp = remoteCandidate?.ip {
            region = TwilioUtils.identifyRegion(ipAddress: remoteIp)
        }

        for candidate in current.iceCandidateStats {
            if let id = candidate.transportId {
                if id != localCandidate?.transportId && id != remoteCandidate?.transportId {
                    if let ignores = ignoreCandidates, ignores.contains(id) {
                        continue
                    }

                    if var others = otherCandidates {
                        others.append(candidate)
                    } else {
                        otherCandidates = [candidate]
                    }
                }
            }
        }

        calcDiffStats(current: current, previous: previous)
    }

    private func calcDiffStats(current: TVIStatsReport, previous: TVIStatsReport?) {
        guard let previous = previous else { return }

        guard let currTrackStats = current.remoteVideoTrackStats.first,
            let prevTrackStats = previous.remoteVideoTrackStats.first else { return }

        let tDelta: Double = (currTrackStats.timestamp - prevTrackStats.timestamp) / 1000 // milliseconds -> seconds

        guard tDelta > 0 else {
            NSLog("Twilio stats timestamp delta is 0 or negative: \(tDelta)")
            return
        }

        samplePeriod = tDelta
        bpsReceived = UInt(( Double(currTrackStats.bytesReceived - prevTrackStats.bytesReceived) / tDelta ) * 8)

        let packetsReceivedDelta = Double(currTrackStats.packetsReceived - prevTrackStats.packetsReceived)
        if !packetsReceivedDelta.isZero, packetsReceivedDelta > 0.0 {
            // Explicit isZero check because we had a paranoia-inducing crash here despite the > 0 check.
            packetLossRatio = Double(currTrackStats.packetsLost - prevTrackStats.packetsLost) / packetsReceivedDelta
        } else {
            packetLossRatio = 0.0
        }
    }

    public static func == (lhs: TwilioStats, rhs: TwilioStats) -> Bool {
        return lhs.peerConnectionId == rhs.peerConnectionId && lhs.timestamp == rhs.timestamp
    }
}

// MARK: - Extend TVI stats classes to support Encodable

// For the Twilio stats types, it isn't sufficient to just declare a CodingKeys enum. Trying to do so gives the error:
// "Implementation of 'Encodable' cannot be automatically synthesized in an extension in a different file to the type"
// Since we shouldn't alter Twilio's SDK files, we write the encode function ourselves.

extension TVIRemoteVideoTrackStats: Encodable {
    enum CodingKeys: CodingKey {
        // From TVIBaseTrackStats
        case codec
        case packetsLost
        case ssrc
        case timestamp
        case trackSid

        // From TVIRemoteTrackStats
        case bytesReceived
        case packetsReceived

        // From TCIRemoteVideoTrackStats
        case dimensions
        case frameRate
    }

    enum VideoDimensionKeys: CodingKey {
        case width
        case height
    }

    public func encode(to encoder: Encoder) throws {
        // From TVIBaseTrackStats
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(codec, forKey: .codec)
        try container.encodeIfPresent(packetsLost, forKey: .packetsLost)
        try container.encodeIfPresent(ssrc, forKey: .ssrc)
        try container.encodeIfPresent(timestamp, forKey: .timestamp)
        try container.encodeIfPresent(trackSid, forKey: .trackSid)

        // From TVIRemoteTrackStats
        try container.encodeIfPresent(bytesReceived, forKey: .bytesReceived)
        try container.encodeIfPresent(packetsReceived, forKey: .packetsReceived)

        // From TCIRemoteVideoTrackStats
        var dimensionsContainer = container.nestedContainer(keyedBy: VideoDimensionKeys.self, forKey: .dimensions)
        try dimensionsContainer.encode(dimensions.width, forKey: .width)
        try dimensionsContainer.encode(dimensions.height, forKey: .height)

        try container.encodeIfPresent(frameRate, forKey: .frameRate)
    }
}

extension TVIIceCandidatePairState {
    public func toString() -> String {
        switch self {
        case .succeeded: return "succeeded"
        case .frozen: return "frozen"
        case .waiting: return "waiting"
        case .inProgress: return "inProgress"
        case .failed: return "failed"
        case .cancelled: return "cancelled"
        case .unknown: return "unknown"
        default: return "unrecognized value \(rawValue)"
        }
    }
}

extension TVIIceCandidatePairStats: Encodable {
    enum CodingKeys: CodingKey {
        case isActiveCandidatePair
        case relayProtocol
        case transportId
        case localCandidateId
        // case localCandidateIp // Redundant with IceCandidateStats info that we already log
        case remoteCandidateId
        // case remoteCandidateIp
        case state
        case priority // Appears to always be 0, with candidates (rather than the pair) having the priority.
        case isNominated
        case isWritable
        case isReadable
        case bytesSent
        case bytesReceived
        case currentRoundTripTime
        case availableOutgoingBitrate // with SDK 2.6.0, is always 0
        case availableIncomingBitrate // with SDK 2.6.0, is always 0
        case requestsReceived
        case requestsSent
        case responsesReceived
        case responsesSent
        case retransmissionsReceived
        case retransmissionsSent
        case consentRequestsReceived
        case consentRequestsSent
        case consentResponsesReceived
        case consentResponsesSent
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(isActiveCandidatePair, forKey: .isActiveCandidatePair)
        try container.encodeIfPresent(relayProtocol, forKey: .relayProtocol)
        try container.encodeIfPresent(transportId, forKey: .transportId)
        try container.encodeIfPresent(localCandidateId, forKey: .localCandidateId)
        // try container.encodeIfPresent(localCandidateIp, forKey: .localCandidateIp)
        try container.encodeIfPresent(remoteCandidateId, forKey: .remoteCandidateId)
        // try container.encodeIfPresent(remoteCandidateIp, forKey: .remoteCandidateIp)
        try container.encodeIfPresent(state.toString(), forKey: .state)
        if priority != 0 {
            try container.encodeIfPresent(priority, forKey: .priority)
        }
        try container.encodeIfPresent(isNominated, forKey: .isNominated)
        try container.encodeIfPresent(isWritable, forKey: .isWritable)
        try container.encodeIfPresent(isReadable, forKey: .isReadable)
        try container.encodeIfPresent(bytesSent, forKey: .bytesSent)
        try container.encodeIfPresent(bytesReceived, forKey: .bytesReceived)
        try container.encodeIfPresent(currentRoundTripTime, forKey: .currentRoundTripTime)
        if availableOutgoingBitrate > 0 {
            try container.encodeIfPresent(availableOutgoingBitrate, forKey: .availableOutgoingBitrate)
        }
        if availableIncomingBitrate > 0 {
            try container.encodeIfPresent(availableIncomingBitrate, forKey: .availableIncomingBitrate)
        }
        if requestsReceived > 0 {
            try container.encodeIfPresent(requestsReceived, forKey: .requestsReceived)
        }
        if requestsSent > 0 {
            try container.encodeIfPresent(requestsSent, forKey: .requestsSent)
        }
        if responsesReceived > 0 {
            try container.encodeIfPresent(responsesReceived, forKey: .responsesReceived)
        }
        if responsesSent > 0 {
            try container.encodeIfPresent(responsesSent, forKey: .responsesSent)
        }
        if retransmissionsReceived > 0 {
            try container.encodeIfPresent(retransmissionsReceived, forKey: .retransmissionsReceived)
        }
        if retransmissionsSent > 0 {
            try container.encodeIfPresent(retransmissionsSent, forKey: .retransmissionsSent)
        }
        if consentRequestsReceived > 0 {
            try container.encodeIfPresent(consentRequestsReceived, forKey: .consentRequestsReceived)
        }
        if consentRequestsSent > 0 {
            try container.encodeIfPresent(consentRequestsSent, forKey: .consentRequestsSent)
        }
        if consentResponsesReceived > 0 {
            try container.encodeIfPresent(consentResponsesReceived, forKey: .consentResponsesReceived)
        }
        if consentResponsesSent > 0 {
            try container.encodeIfPresent(consentResponsesSent, forKey: .consentResponsesSent)
        }
    }
}

extension TVIIceCandidateStats: Encodable {
    enum CodingKeys: String, CodingKey {
        case candidateType
        case isDeleted
        case ip
        case isRemote
        case port
        case priority
        case protocol_ = "protocol"
        case url
        case transportId
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(candidateType, forKey: .candidateType)
        try container.encodeIfPresent(isDeleted, forKey: .isDeleted)
        try container.encodeIfPresent(ip, forKey: .ip)
        try container.encodeIfPresent(isRemote, forKey: .isRemote)
        try container.encodeIfPresent(port, forKey: .port)
        try container.encodeIfPresent(priority, forKey: .priority)
        try container.encodeIfPresent(self.protocol, forKey: .protocol_)
        if let url = url, !url.isEmpty {
            try container.encodeIfPresent(url, forKey: .url)
        }
        try container.encodeIfPresent(transportId, forKey: .transportId)
    }
}

extension TVIStatsReport: Encodable {
    enum CodingKeys: CodingKey {
        case peerConnectionId
        case remoteVideoTrackStats
        case iceCandidatePairStats
        case iceCandidateStats

        // ignoring:
        // remoteAudioTrackStats -- not using audio at this time
        // remoteAudioTrackStats -- not using audio at this time
        // remoteVideoTrackStats -- we expect to be the only ones providing a video track

    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(peerConnectionId, forKey: .peerConnectionId)
        try container.encodeIfPresent(remoteVideoTrackStats, forKey: .remoteVideoTrackStats)
        try container.encodeIfPresent(iceCandidatePairStats, forKey: .iceCandidatePairStats)
        try container.encodeIfPresent(iceCandidateStats, forKey: .iceCandidateStats)
    }
}
