//
//  ViewController.swift
//  blinkCDN Wifi
//
//  Created by Charles Bethin on 9/25/18.
//  Copyright © 2018 Charles Bethin. All rights reserved.
//

import UIKit
import Charts

class DeviceListViewController: UIViewController, WifiControllerDelegate, ChartViewDelegate, UICollectionViewDelegate, UICollectionViewDataSource {

    // MARK: PROPERTIES
    @IBOutlet weak var pieChart: PieChartView!
    @IBOutlet weak var deviceInfoCard: DeviceInfoCardView!
    
    lazy var dynamicAnimator = UIDynamicAnimator()
    var snapBehavior: UISnapBehavior!
    
    var dataEntries = [String : PieChartDataEntry]()
    let colors = [ UIColor(named: "highlightColor1")!, UIColor(named: "highlightColor2")! ]
    
    private let refreshControl = UIRefreshControl()
    
    private var selectedDevice: Device? {
        didSet {
            self.dynamicAnimator.removeBehavior(snapBehavior)
            deviceInfoCard.moveDown {
                self.deviceInfoCard.focusDevice = self.selectedDevice
                self.dynamicAnimator.addBehavior(self.snapBehavior)
            }
        }
    }
    
    var wifiController = WifiController()
    
    // MARK: VIEW LOADING
    override func viewWillAppear(_ animated: Bool) {
        navigationController?.setNavigationBarHidden(true, animated: true)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        navigationController?.setNavigationBarHidden(false, animated: true)
    }
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
//        UserDefaults.standard.removeObject(forKey: "blinkWifiKey")
        
        // Setup wifiController
        let doesKeyExist = wifiController.doesHaveValidKey()
        if !doesKeyExist {
            if let vc = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "loginVC") as? LoginViewController {
                vc.wifiController = wifiController
                vc.presentedBy = self
                present(vc, animated: true, completion: nil)
            }
            
        } else {
            setupWifiController()
        }
        
        wifiController.delegate = self
        
        pieChart.delegate = self
        pieChart.chartDescription?.text = ""
        pieChart.noDataText = "No data available."
        pieChart.holeColor = UIColor(named: "bgDarker")!
        pieChart.entryLabelColor = UIColor(named: "text")!
        pieChart.legend.enabled = false
        
        deviceInfoCard.translatesAutoresizingMaskIntoConstraints = false
        
        let pan = UIPanGestureRecognizer(target: self, action: #selector(pan(_:)))
        deviceInfoCard.addGestureRecognizer(pan)
        snapBehavior = UISnapBehavior(item: deviceInfoCard, snapTo: CGPoint(x: deviceInfoCard.center.x, y: deviceInfoCard.center.y))
        snapBehavior.damping = 0.5
        dynamicAnimator.addBehavior(snapBehavior)

        let tap = UITapGestureRecognizer(target: self, action: #selector(tap(_:)))
        deviceInfoCard.addGestureRecognizer(tap)
    }
    
    func setupWifiController() {
        print("Setting up")
        wifiController.getConnectedDevices(completion: { _ in
            print("GOT IT")
        })
        wifiController.getPublicIPAddress(completion: nil)
        
        // Start getting bandwidth & tcp failure updates every second
        wifiController.startUpdatingBandwith(withInterval: 1)
        wifiController.startUpdatingTCPFailures(withInterval: 1)
        wifiController.startUpdatingConnectedDevices(withInterval: 20)
    }
    
    @objc func tap(_ sender: UITapGestureRecognizer) {
        performSegue(withIdentifier: "toConnectedDeviceDetail", sender: self)
    }
    
    @objc func pan(_ sender: UIPanGestureRecognizer) {
        switch sender.state {
        case .began:
            print("Began")
            dynamicAnimator.removeBehavior(snapBehavior)
            deviceInfoCard.layer.animateShadowOpacity(from: DeviceInfoCardView.Constants.minimumShadowOpacity, to: DeviceInfoCardView.Constants.defaultShadowOpacity, duration: 0.1)
            UIView.animate(withDuration: 0.2, animations: {
                self.deviceInfoCard.transform = CGAffineTransform.identity.scaledBy(x: 1.05, y: 1.05)
            })
//        case .changed:
        case .ended:
            print("Ended")
            deviceInfoCard.layer.animateShadowOpacity(from: DeviceInfoCardView.Constants.defaultShadowOpacity, to: DeviceInfoCardView.Constants.minimumShadowOpacity, duration: 0.1)
            dynamicAnimator.addBehavior(snapBehavior)
        default: break
        }
        
        let translation = sender.translation(in: self.view)
        deviceInfoCard.center = CGPoint(x: deviceInfoCard.center.x + translation.x, y: deviceInfoCard.center.y + translation.y)
        sender.setTranslation(CGPoint.zero, in: self.view)
    }
    
    // MARK: DEVICE INFO CARD
    
    // MARK: PIE CHART
    func updateChartData() {
        var entries = [PieChartDataEntry]()
        
        for device in self.wifiController.connectedDevices {
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
        chartDataset.colors = colors as [NSUIColor]

        let chartData = PieChartData(dataSet: chartDataset)
        
        DispatchQueue.main.async {
            self.pieChart.data = nil
            self.pieChart.drawEntryLabelsEnabled = false
            self.pieChart.usePercentValuesEnabled = true
            self.pieChart.data = chartData
        }
        
    }
    
    // MARK: NAVIGATION
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let identifier = segue.identifier {
            switch identifier {
            case "toConnectedDeviceDetail":
                if let selectedDevice = self.selectedDevice,
                    let destVc = segue.destination as? ConnectedDeviceDetailViewController {
                    destVc.title = selectedDevice.Name
                    destVc.device = selectedDevice
                    destVc.wifiController = wifiController
                }
            
            default: break
            }
        }
    }
    
    // MARK: WIFI CONTROLLER DELEGATE
    func onPublicIPUpdate(to newIPAddress: String) {
    }
    
    func onConnectedDevicesUpdate(added newDevices: [Device]?, removed oldDevices: [Device]?) {
        updateChartData()
    }
    
    func onDeviceInformationUpdate() {
        deviceInfoCard.focusDevice = selectedDevice
    }
    
    func onFailToChangeWifiStatus(to: Bool) { }
    func onWifiStatusChange(to isWifiOn: Bool) { }
    
    // MARK: CHART VIEW DELEGATE
    func chartValueSelected(_ chartView: ChartViewBase, entry: ChartDataEntry, highlight: Highlight) {
        let newSelectedDevice = self.wifiController.connectedDevices[Int(highlight.x)]
        if newSelectedDevice != selectedDevice {
            selectedDevice = newSelectedDevice
        }
    }
    
    // MARK : COLLECITON VIEW
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.wifiController.connectedDevices.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "deviceInfoCell", for: indexPath) as! DeviceInfoCardView
        
        cell.focusDevice = self.wifiController.connectedDevices[indexPath.row]
        
        return cell
    }
    
}

extension UIColor {
    func lighter(by percentage: CGFloat = 0.3) -> UIColor? {
        return self.adjust(by: abs(percentage) )
    }
    
    func darker(by percentage: CGFloat = 0.3) -> UIColor? {
        return self.adjust(by: -1 * abs(percentage) )
    }
    
    func adjust(by percentage: CGFloat = 0.3) -> UIColor? {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        if self.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            return UIColor(red: min(red + percentage, 1.0),
                           green: min(green + percentage, 1.0),
                           blue: min(blue + percentage, 1.0),
                           alpha: alpha)
        } else {
            return nil
        }
    }
}
