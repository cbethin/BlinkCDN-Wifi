//
//  BlinkResponseTypes.swift
//  blinkCDN Wifi
//
//  Created by Charles Bethin on 10/29/18.
//  Copyright © 2018 Charles Bethin. All rights reserved.
//

import Foundation

struct BlinkHTTPResponse<T: Decodable>: Decodable  {
    let Response: BlinkResponseType
    let Data: T
}

enum BlinkResponseType: String, Decodable {
    case fail
    case success
}

struct BlinkBandwidthForDevice: Decodable {
    let IP: String
    let Bandwidth: Int
}

struct BlinkTCPFailuresForDevice: Decodable {
    let IP: String
    let Failures: Int
}
