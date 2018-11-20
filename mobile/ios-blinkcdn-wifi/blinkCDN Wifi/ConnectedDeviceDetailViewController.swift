//
//  ConnectedDeviceDetailViewController.swift
//  blinkCDN Wifi
//
//  Created by Charles Bethin on 9/26/18.
//  Copyright © 2018 Charles Bethin. All rights reserved.
//

import UIKit
import Charts

class ConnectedDeviceDetailViewController: UIViewController, ChartViewDelegate {

    @IBOutlet weak var ipLabel: UILabel!
    @IBOutlet weak var macLabel: UILabel!
    @IBOutlet weak var failureCount: UILabel!
    @IBOutlet weak var bandwidthLabel: UILabel!
    @IBOutlet weak var lineChart: LineChartView!
    
    var wifiController: WifiController?
    
    var device: Device = Device(ip: "ip", mac: "mac", name: "", isAlive: false, isEnabled: true) {
        didSet {
            self.ip = device.IP
            self.mac = device.MAC
        }
    }
    
    private var ip: String = "IP Address: Not found" {
        didSet {
            ip = "IP Address: \(ip)"
        }
    }
    
    private var mac: String = "MAC Address: Not found" {
        didSet {
            mac = "MAC Address: \(mac)"
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        wifiController?.onDeviceInformationUpdate = onDeviceInformationUpdate

        ipLabel.text? = ip
        macLabel.text? = mac
        
        lineChart.delegate = self
        lineChart.chartDescription?.text = "Bandwidth Usage for Device"
        lineChart.noDataText = "No data available"
    }
    
    private func onDeviceInformationUpdate() {
        guard let wifiController = self.wifiController else { return }
        if let device = wifiController.connectedDevices.first(where: { $0 == self.device } ) {
            DispatchQueue.main.async {
                self.failureCount.text = String(device.numTCPFailures ?? 0)
                
                let bandwidth = WifiController.BandwidthToMbps(device.bandwidth ?? 0)
                self.bandwidthLabel.text = String(format: "%.3f", bandwidth)
            }
        }
        
        updateChartData()
    }
    
    func updateChartData() {
        var entries = [ChartDataEntry]()
        
        if let wifiController = wifiController {
            if let i = wifiController.connectedDevices.firstIndex(of: self.device),
                let pastBandwidths = wifiController.connectedDevices[i].pastBandwidths {
                var i = 0;
                for bandwidth in pastBandwidths {
                    let mbpsBandwidth = WifiController.BandwidthToMbps(bandwidth)
                    entries.append(ChartDataEntry(x: Double(i), y: mbpsBandwidth))
                    i += 1
                }
                
                let chartDataset = LineChartDataSet(values: entries, label: "Bandwidth (mbps)")
                chartDataset.lineWidth = 3
                chartDataset.circleRadius = 4
                let chartData = LineChartData(dataSet: chartDataset)
                
                DispatchQueue.main.async {
                    self.lineChart.drawBordersEnabled = true
                    self.lineChart.data = chartData
                }
            }
        }
    }
    
}
