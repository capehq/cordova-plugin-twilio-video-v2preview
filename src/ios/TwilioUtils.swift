//
//  TwilioUtils.swift
//
//  Created by Dan Homerick on 1/11/19.
//  Copyright © 2019 Cape Productions, Inc. All rights reserved.
//


enum TwilioUtils {
    private static func ipv4StringToUInt32(_ ip: String) -> UInt32 {
        var addr = sockaddr_in()
        let ptr: UnsafeMutablePointer<in_addr> = UnsafeMutablePointer(&addr.sin_addr)
        inet_aton(ip, ptr)
        return addr.sin_addr.s_addr.byteSwapped
    }

    // IP ranges last updated / verified: Jan 10, 2019
    // See: https://www.twilio.com/docs/video/ip-address-whitelisting
    //      https://www.twilio.com/docs/stun-turn/regions
    // ipAddress may include a port number.
    static func identifyRegion(ipAddress: String) -> TwilioRegion {
        guard let ip = ipAddress.components(separatedBy: ":").first else {
            NSLog("Failed to parse ipAddress as url: \(ipAddress)")
            return TwilioRegion.unrecognized
        }

        switch ipv4StringToUInt32(ip) {
        case 231867008...231867039,     // 13.210.2.128...13.210.2.159
        922549824...922549887:     // 54.252.254.64...54.252.254.127
            return TwilioRegion.australia
        case 317155616...317155647,     // 18.231.105.32...18.231.105.63
        2974273216...2974273279:   // 177.71.206.192...177.71.206.255
            return TwilioRegion.brazil
        case 876329472...876329503,     // 52.59.186.0...52.59.186.31
        314781920...314781951:     // 18.195.48.224...18.195.48.255
            return TwilioRegion.germany
        case 886570240...886570303,     // 52.215.253.0...52.215.253.63
        917209024...917209087,     // 54.171.127.192...54.171.127.255
        886537984...886538239:     // 52.215.127.0...52.215.127.255
            return TwilioRegion.ireland
        case 876790112...876790143,     // 52.66.193.96...52.66.193.127
        876790272...876790335:     // 52.66.194.0...52.66.194.63
            return TwilioRegion.india
        case 225702912...225702943,     // 13.115.244.0...13.115.244.31
        910245824...910245887:     // 54.65.63.192...54.65.63.255
            return TwilioRegion.japan
        case 233176832...233176863,     // 13.229.255.0...13.229.255.31
        917077888...917077951:     // 54.169.127.128...54.169.127.191
            return TwilioRegion.singapore
        case 583794176...583794431,     // 34.203.254.0...34.203.254.255
        917257216...917257727,     // 54.172.60.0...54.172.61.255
        583793152...583793663:     // 34.203.250.0...34.203.251.255
            return TwilioRegion.usaEastCoast
        case 584609408...584609439,     // 34.216.110.128...34.216.110.159
        921973504...921973759:     // 54.244.51.0...54.244.51.255
            return TwilioRegion.usaWestCoast
        default:
            NSLog("Failed to recognize Twilio region for IP address: \(ip)")
            return TwilioRegion.unrecognized
        }
    }
}
