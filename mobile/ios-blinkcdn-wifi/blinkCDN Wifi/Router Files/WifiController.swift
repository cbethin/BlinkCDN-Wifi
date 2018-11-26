//
//  WifiController.swift
//  Oxygen
//
//  Created by Charles Bethin on 9/18/18.
//  Copyright © 2018 Charles Bethin. All rights reserved.
//

import Foundation

protocol WifiControllerDelegate {
    func onWifiStatusChange(to isWifiOn: Bool)
    func onFailToChangeWifiStatus(to: Bool)
    func onConnectedDevicesUpdate(added newDevices: [Device]?, removed oldDevices: [Device]?)
    func onPublicIPUpdate(to: String)
    func onDeviceInformationUpdate()
}

class WifiController {
    
    // MARK: PROPERTIES
    var delegate: WifiControllerDelegate?
    private var id: String?
    fileprivate let SERVER: String = "publicapi.blinkcdn.com:8080"
    private(set) var isOn: Bool = false { didSet { delegate?.onWifiStatusChange(to: self.isOn) } }
    private(set) var connectedDevices: [Device] = [
        Device(ip: "192.168.8.194", mac: "mac", name: "Charles-MBP", isAlive: true, isEnabled: true, bandwidth: 200000),
        Device(ip: "192.168.8.160", mac: "mac2", name: "Justin-iPhone", isAlive: true, isEnabled: true, bandwidth: 100000)
    ]
    private(set) var publicIP: String?
    
    var onConnectedDevicesUpdate: (([Device]?, [Device]?) -> Void)?
    var onDeviceInformationUpdate: (() -> Void)?
    
    // MARK: GLOBAL CONTROL & DATA
    func doesHaveValidKey() -> Bool {
        guard let key = UserDefaults.standard.object(forKey: "blinkWifiKey") as? String else { return false }
        print("KEY: \(key)")
        var isKeyValid = false
        
        let group = DispatchGroup()
        group.enter()
        
        DispatchQueue.global().sync {
            tryKey(key: key, completion: { (didSucceed) in
                isKeyValid = didSucceed
                group.leave()
            })
        }
        
        group.wait()
        return isKeyValid
    }
    
    func tryKey(key: String, completion: @escaping (Bool)->Void) {
        sendGetRequest(url: "http://\(SERVER)/publicapi/doesrouterexist?id=\(key)", onSuccess: { (data) in
            do {
                let decodedResponse = try JSONDecoder().decode(BlinkHTTPResponse<Bool>.self, from: data)
                let doesRouterExist = decodedResponse.Data
                if doesRouterExist {
                    UserDefaults.standard.set(key, forKey: "blinkWifiKey")
                    self.id = key
                }
                
                completion(doesRouterExist)
                
            } catch {
                print("Could not check key: \(error)")
                completion(false)
            }
            
        }, onFailure: {
            completion(false)
        })
    }
    
    func turnWifiOn() {
        sendGetRequest(url: "http://\(SERVER)/publicapi/setupwifi", onSuccess: { (data) in
            if String(data: data, encoding: .utf8) == "Success" {
                self.isOn = true
            } else {
                self.delegate?.onFailToChangeWifiStatus(to: true)
            }
        }, onFailure: {
            self.delegate?.onFailToChangeWifiStatus(to: true)
        })
    }
    
    func turnWifiOff() {
        sendGetRequest(url: "http://\(SERVER)/publicapi/turnoffwifi", onSuccess: { (data) in
            if String(data: data, encoding: .utf8) == "Success" {
                self.isOn = false
            } else {
                self.delegate?.onFailToChangeWifiStatus(to: false)
            }
        }, onFailure: {
            self.delegate?.onFailToChangeWifiStatus(to: false)
        })
    }
    
    func getPublicIPAddress(completion: ((Bool) -> Void)?) {
        sendGetRequest(url: "http://\(SERVER)/publicapi/publicip", onSuccess: { (data) in
            if let ip = String(data: data, encoding: .utf8) {
                self.publicIP = ip
                
                if let completion = completion {
                    completion(true)
                } else {
                    self.delegate?.onPublicIPUpdate(to: ip)
                }
            }
            
        }, onFailure: {
            if let completion = completion {
                completion(false)
            }
        })
    }
    
    // MARK: DEVICE DATA RETRIEVAL
    func getConnectedDevices(completion: ((Bool) -> Void)?) {
        sendGetRequest(url: "http://\(SERVER)/publicapi/publiccondev", onSuccess: { (data) in
            do {
                let response2 = try JSONDecoder().decode(BlinkHTTPResponse<[Device]>.self, from: data)
                if response2.Response == .fail {
                    print("Response: FAIL. Could not get connected devices:", response2.Data)
                    completion?(false)
                }
                
                print("Updating conn dev.")
                var newDevices: [Device] = []
                var oldDevices: [Device] = []
                
                // Update any connected devices that we already had, insert new devices not yet in connectedDevices
                response2.Data.forEach { (device) in
                    if let _ = self.connectedDevices.firstIndex(where: { $0 == device }) {
                        // We won't overwrite the device we already had cuz we update it's values via other means
//                        self.connectedDevices[i] = device
                    } else {
                        self.connectedDevices.append(device)
                        newDevices.append(device)
                    }
                }
                
                // Remove any connectedDevices that were not in the response update
                self.connectedDevices.forEach { (device) in
                    if response2.Data.firstIndex(where: { $0 == device }) == nil {
                        if let i = self.connectedDevices.firstIndex(where: { $0 == device }) {
                            self.connectedDevices.remove(at: i)
                            oldDevices.append(device)
                        }
                    }
                }
                
                self.delegate?.onConnectedDevicesUpdate(added: newDevices, removed: oldDevices)
                self.onConnectedDevicesUpdate?(newDevices, oldDevices)
                completion?(true)
                
            } catch {
                print("Error extracting connected devices.", error)
                completion?(false)
            }
            
        }, onFailure: {
            completion?(false)
        })
    }
    
    func getBandwidthForDevices(completion: ((Bool) -> Void)?) {
        sendGetRequest(url: "http://\(SERVER)/publicapi/bandwidths", onSuccess: { (data) in
            do {
                let decodedResponse = try JSONDecoder().decode(BlinkHTTPResponse<[BlinkBandwidthForDevice]>.self, from: data)
                if decodedResponse.Response == .fail {
                    print("Response: FAIL. Could not get bandwidths:", decodedResponse.Data)
                    completion?(false)
                }
                
                for item in decodedResponse.Data {
                    if let i = self.connectedDevices.firstIndex(where: { $0.IP == item.IP }) {
                        self.connectedDevices[i].bandwidth = item.Bandwidth
                        
                        if self.connectedDevices[i].pastBandwidths == nil {
                            self.connectedDevices[i].pastBandwidths = []
                        }
                        
                        self.connectedDevices[i].pastBandwidths! += [item.Bandwidth]
                    }
                }
                
                completion?(true)
            } catch {
                print("Error decoding bandwidths from server:", error)
                completion?(false)
            }
            
        }, onFailure: {
            completion?(false)
        })
    }
    
    func getTCPFailuresForDevices(completion: ((Bool) -> Void)?) {
        sendGetRequest(url: "http://\(SERVER)/publicapi/numtcpfails", onSuccess: { (data) in
            do {
                let decodedResponse = try JSONDecoder().decode(BlinkHTTPResponse<[BlinkTCPFailuresForDevice]>.self, from: data)
                if decodedResponse.Response == .fail {
                    print("Response: FAIL. Could not get bandwidths:", decodedResponse.Data)
                    completion?(false)
                }
                
                for device in decodedResponse.Data {
                    if let i = self.connectedDevices.firstIndex(where: { $0.IP == device.IP }) {
                        self.connectedDevices[i].numTCPFailures = device.Failures
                    }
                }
                
                completion?(true)
            } catch {
                print("Error decoding TCP Failures from server:", error)
                completion?(false)
            }
            
        }, onFailure: {
            completion?(false)
        })
    }
    
    func getDeviceType(for device: Device, completion: ((Bool) -> Void)?) {
        sendGetRequest(url: "http://\(SERVER)/publicapi/getdevicetype?mac=\(device.MAC)", onSuccess: { data in
            do {
                let decodedResponse = try JSONDecoder().decode(BlinkHTTPResponse<DeviceInfo>.self, from: data)
                if let device = self.connectedDevices.first(where: { $0 == device }) {
                    device.info = decodedResponse.Data
                }
            
                self.onDeviceInformationUpdate?()
                self.delegate?.onDeviceInformationUpdate()
                completion?(true)
                
            } catch {
                print("Could not decode device type: \(error)")
                completion?(false)
            }
        }, onFailure: {
            completion?(false)
        })
    }
    
    func startUpdatingBandwith(withInterval interval: UInt32) {
        DispatchQueue.global(qos: .default).async {
            while(true) {
                self.getBandwidthForDevices(completion: { (didComplete) in
                    if didComplete {
                        self.delegate?.onDeviceInformationUpdate()
                        self.onDeviceInformationUpdate?()
                    } else {
                        print("Could not update bandwidths")
                    }
                })
                
                sleep(interval)
            }
        }
    }
    
    func startUpdatingTCPFailures(withInterval interval: UInt32) {
        DispatchQueue.global(qos: .default).async {
            while(true) {
                self.getTCPFailuresForDevices(completion: { (didComplete) in
                    if didComplete {
                        self.delegate?.onDeviceInformationUpdate()
                        self.onDeviceInformationUpdate?()
                    } else {
                        print("Could not update TCP Failures")
                    }
                })
                
                sleep(interval)
            }
        }
    }
    
    func startUpdatingConnectedDevices(withInterval interval: UInt32) {
        DispatchQueue.global(qos: .default).async {
            while(true) {
                self.getConnectedDevices(completion: nil)
                sleep(interval)
            }
        }
    }
    
    
    // MARK: DEVICE  CONTROL
    func disableWifi(for device: Device, completion: ((Bool) -> Void)?) {
        if connectedDevices.isEmpty {
            completion?(false)
            return
        }
        
        let selectedDevice = connectedDevices.filter { $0 == device }[0]
        selectedDevice.IsEnabled = false
        
        sendGetRequest(url: "http://\(SERVER)/publicapi/setwifiStatus?mac=\(device.MAC)&status=off", onSuccess: { (_) in
            if let completion = completion {
                completion(true)
            }
        }, onFailure: {
            if let completion = completion {
                completion(false)
            }
        })
        
        print("Disabling: \(connectedDevices.map { $0.IsEnabled })")
    }
    
    func enableWifi(for device: Device, completion: ((Bool) -> Void)?) {
        if connectedDevices.isEmpty {
            completion?(false)
            return
        }
        
        let selectedDevice = connectedDevices.filter { $0 == device }[0]
        
        sendGetRequest(url: "http://\(SERVER)/publicapi/setwifiStatus?mac=\(device.MAC)&status=on", onSuccess: { (_) in
            if let completion = completion {
                selectedDevice.IsEnabled = true
                completion(true)
            }
        }, onFailure: {
            if let completion = completion {
                completion(false)
            }
        })
        
        print("Disabling: \(connectedDevices.map { $0.IsEnabled })")
    }
    
    private func sendGetRequest(url: String, onSuccess: @escaping (Data) -> Void, onFailure: @escaping () -> Void) {
        if let url = URL(string: url) {
            URLSession.shared.dataTask(with: url) { (data, response, error) in
                if error != nil {
                    print("Error sending get request to: \(url) -", error!.localizedDescription)
                    onFailure()
                    return
                }
                
                if let data = data {
                    onSuccess(data)
                } else {
                    onFailure()
                }
                }.resume()
        } else {
            print("Error sending get request to: \(url)")
            onFailure()
        }
    }
    
    static func BandwidthToMbps(_ bandwidth: Int) -> Double {
        return Double(bandwidth)/1e6*8
    }
}
