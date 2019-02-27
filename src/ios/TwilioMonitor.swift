//
//  TwilioMonitor.swift
//
//
//  Created by Dan Homerick on 1/8/19.
//  Copyright (c) 2019 Cape Productions, Inc. All rights reserved.
//

import TwilioVideo

@objc class TwilioMonitor: NSObject {
    private static var room: TVIRoom?
    private static var ignoredCandidateIds: Set<String> = Set()
    private static var previousReport: TVIStatsReport?
    private static var latestReport: TVIStatsReport?

    public class func set(room: TVIRoom?) {
        TwilioMonitor.room = room
    }

    public class func getStats(completion: @escaping ([String:Any]?) -> Void) {
        TwilioMonitor.collectStats { stats in
            completion(stats?.toJSONDictionary())
        }
    }

    class func collectStats(completion: @escaping (TwilioStats?) -> Void) {

        TwilioMonitor.room?.getStatsWith { (reports: [TVIStatsReport]) in

            guard let report = reports.first else {
                NSLog("Received empty stats reports array")
                // Reset reports
                TwilioMonitor.previousReport = nil
                TwilioMonitor.latestReport = nil
                completion(nil)
                return
            }

            if reports.count > 1 {
                NSLog("Only the first out of \(reports.count) TVIStatsReports will be processed")
            }

            var prevReport = TwilioMonitor.latestReport
            if prevReport?.peerConnectionId != report.peerConnectionId {
                prevReport = nil
            }

            TwilioMonitor.latestReport = report
            TwilioMonitor.previousReport = prevReport

            let twilioStats = TwilioStats(current: report, previous: prevReport, ignoreCandidates: TwilioMonitor.ignoredCandidateIds)

            // To reduce log spam, only report the unused "other" candidates once. Omit them after the first report.
            if let others = twilioStats.otherCandidates {
                for candidate in others {
                    if let id = candidate.transportId {
                        ignoredCandidateIds.insert(id)
                    }
                }
            }

            completion(twilioStats)
        }
    }

}
