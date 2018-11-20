//
//  DeviceInfoCardView.swift
//  blinkCDN Wifi
//
//  Created by Charles Bethin on 11/14/18.
//  Copyright © 2018 Charles Bethin. All rights reserved.
//

import UIKit

class DeviceInfoCardView: UICollectionViewCell{
    
    @IBOutlet weak var deviceNameLabel: UILabel!
    @IBOutlet weak var bandwidthLabel: UILabel!
    @IBOutlet weak var ipLabel: UILabel!
    
    var originalCenter: CGPoint!
    
    var focusDevice: Device? {
        didSet {
            DispatchQueue.main.async {
                self.deviceNameLabel.text = self.focusDevice?.Name
                self.bandwidthLabel.text = String(format: "%.2f", WifiController.BandwidthToMbps(self.focusDevice?.bandwidth ?? -1))
                self.ipLabel.text = self.focusDevice?.IP
            }
        }
    }
    
    override func willMove(toSuperview newSuperview: UIView?) {
        self.layer.roundCorners(radius: 5.0)
        self.layer.addShadow(opacity: Constants.minimumShadowOpacity, radius: Constants.defaultShadowRadius)
        
        self.layer.borderColor = UIColor(named: "bgDarkest")?.cgColor
        self.layer.borderWidth = 1
        
        originalCenter = center
    }
    
    func moveDown(completion: @escaping ()->Void ) {
        DispatchQueue.main.async {
            if let superview = self.superview {
                UIView.animate(withDuration: 0.15, animations: {
                    self.center.y = (superview.frame.maxY + self.frame.height/2)
                }, completion: { (_) in
                    usleep(100000)
                    completion()
                })
            }
        }
    }
    
    func moveRight(completion: @escaping ()->Void) {
        DispatchQueue.main.async {
            if let superview = self.superview {
                UIView.animate(withDuration: 0.15, animations: {
                    self.center.x = superview.frame.maxX + self.frame.width/2
                }, completion: { (_) in
                    self.center.x = superview.frame.minX - self.frame.width/2
                    usleep(100000)
                    completion()
                })
            }
        }
    }
    
    func moveUp() {
        DispatchQueue.main.async {
            UIView.animate(withDuration: 0.2) {
                self.center.y = self.originalCenter.y
            }
        }
    }
    
    
    struct Constants {
        static let defaultShadowRadius: CGFloat = 7.0
        static let defaultShadowOpacity: Float = 0.12
        static let minimumShadowRadius: CGFloat = 4.0
        static let minimumShadowOpacity: Float = 0.05
        static let touchTransitionTime: TimeInterval = 0.2
    }
}
