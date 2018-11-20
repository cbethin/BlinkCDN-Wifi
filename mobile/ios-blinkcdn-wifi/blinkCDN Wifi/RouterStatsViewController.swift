//
//  RouterStatsViewController.swift
//  blinkCDN Wifi
//
//  Created by Charles Bethin on 11/9/18.
//  Copyright © 2018 Charles Bethin. All rights reserved.
//

import UIKit
import Charts

class RouterStatsViewController: UIViewController, WifiControllerDelegate {
    
    @IBOutlet weak var pieChart: PieChartView!
    
    var wifiController = WifiController()
    var dataEntries = [String : PieChartDataEntry]()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        pieChart.chartDescription?.text = ""
        
        
        wifiController.delegate = self
        wifiController.getPublicIPAddress(completion: nil)
        wifiController.getConnectedDevices(completion: nil)
        wifiController.startUpdatingBandwith(withInterval: 1)
        
        // Do any additional setup after loading the view.
    }
    
    // MARK: PIE CHART
    func updateChartData() {
        var entries = [PieChartDataEntry]()
        
        for device in wifiController.connectedDevices {
            // If Pie Chart doesn't have a data entry for a device, then add it
            if dataEntries[device.MAC] == nil {
                dataEntries[device.MAC] = PieChartDataEntry(value: 0)
            }
            
            // Update chart value for device and label it
            dataEntries[device.MAC]?.value = Double(device.bandwidth ?? 0)
            dataEntries[device.MAC]?.label = device.Name
            entries += [dataEntries[device.MAC]!]
        }
        
        let chartDataset = PieChartDataSet(values: entries, label: nil)
        let chartData = PieChartData(dataSet: chartDataset)
        
        pieChart.data = chartData
    }
    
    // MARK: WIFI CONTROLLER DELEGATE
    func onWifiStatusChange(to isWifiOn: Bool) {
        //
    }
    
    func onFailToChangeWifiStatus(to: Bool) {
        //
    }
    
    func onConnectedDevicesUpdate(added newDevices: [Device]?, removed oldDevices: [Device]?) {
        
        updateChartData()
    }
    
    func onPublicIPUpdate(to: String) {
        //
    }
    
    func onDeviceInformationUpdate() {
        //
    }

}
