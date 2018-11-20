//
//  DeviceTypeIdentifier.swift
//  blinkCDN Wifi
//
//  Created by Charles Bethin on 10/6/18.
//  Copyright © 2018 Charles Bethin. All rights reserved.
//

import Foundation

enum DeviceType: String, Codable {
    case iphone
    case appleWatch
    case macbook
    case tv
    case idk
}

struct DeviceInfo: Decodable {
    let Maker: String
    let DeviceType: DeviceType
}

class Device: Decodable, Equatable {
    let IP: String
    let MAC: String
    var Name: String
    var info: DeviceInfo?
    
    var bandwidth: Int?
    var pastBandwidths: [Int]?
    var numTCPFailures: Int?
    
    var IsAlive: Bool
    var IsEnabled: Bool
    
    static func ==(lhs: Device, rhs: Device) -> Bool {
        return lhs.IP == rhs.IP && lhs.MAC == rhs.MAC && lhs.Name == rhs.Name
    }
    
    init(ip: String, mac: String, name: String, isAlive: Bool, isEnabled: Bool, bandwidth: Int = -1) {
        self.IP = ip
        self.MAC = mac
        self.Name = name
        self.info = nil
        self.IsEnabled = isEnabled
        self.IsAlive = isAlive
        self.bandwidth = bandwidth
        
        self.pastBandwidths = []
    }
}

struct DeviceIdentifier {
    
    static func getDeviceManufacturer(mac: String) -> String? {
        let url = URL(string: "https://api.macvendors.com/\(mac)")
        let string = try? String(contentsOf: url!, encoding: .utf8)
        return string
    }
    
    static func isolateDeviceTypeFromName(device: Device) -> DeviceType {
        if device.Name.lowercased().contains("iphone") {
            return .iphone
        } else if device.Name.lowercased().contains("watch") {
            return .appleWatch
        } else if device.Name.lowercased().contains("mbp") {
            return .macbook
        }
        
        return .tv
    }
}
