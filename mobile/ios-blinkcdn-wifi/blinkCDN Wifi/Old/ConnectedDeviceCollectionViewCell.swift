//
//  ConnectedDeviceCollectionViewCell.swift
//  blinkCDN Wifi
//
//  Created by Charles Bethin on 9/25/18.
//  Copyright © 2018 Charles Bethin. All rights reserved.
//

import UIKit

class ConnectedDeviceCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var ipAddrLabel: UILabel!
    @IBOutlet weak var macAddrLabel: UILabel!
    @IBOutlet weak var bandwidthLabel: UILabel!
    @IBOutlet weak var statusLight: UIView!
    
//    var touchView: TouchResponsiveView! = TouchResponsiveView()
    var onTap : () -> Void = { }
    
    override func willMove(toSuperview newSuperview: UIView?) {
        nameLabel.adjustsFontSizeToFitWidth = true
        ipAddrLabel.adjustsFontSizeToFitWidth = true
        macAddrLabel.adjustsFontSizeToFitWidth = true
        
        self.layer.roundCorners(radius: 10.0)
        self.layer.addShadow(opacity: Constants.defaultShadowOpacity, radius: Constants.defaultShadowRadius)
        self.layer.cornerRadius = 10
        
//        backgroundColor = #colorLiteral(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0).withAlphaComponent(0.75)
//        layer.borderColor = #colorLiteral(red: 0.8039215803, green: 0.8039215803, blue: 0.8039215803, alpha: 1)
        layer.borderWidth = 1
        
        statusLight.layer.cornerRadius = statusLight.frame.width / 2
    }
    
    var focusDevice: Device? {
        didSet {
            nameLabel.text = focusDevice?.Name
            ipAddrLabel.text = focusDevice?.IP
            macAddrLabel.text = focusDevice?.MAC
            bandwidthLabel.text = String(format: "%.3f", Double(focusDevice?.bandwidth ?? 0)/1e6*8)
            statusLight.backgroundColor = (focusDevice?.IsAlive ?? false) ? #colorLiteral(red: 0.1019607857, green: 0.7575449486, blue: 0.400000006, alpha: 1) : #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 0.7067101884)
        }
    }

    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        UIView.animate(withDuration: Constants.touchTransitionTime, animations: {
            self.transform = CGAffineTransform.identity.scaledBy(x: 0.95, y: 0.95)
        })
        self.layer.animateShadowRadius(from: Constants.defaultShadowRadius, to: Constants.minimumShadowRadius, duration: 0.1)
        self.layer.animateShadowOpacity(from: Constants.defaultShadowOpacity, to: Constants.minimumShadowOpacity, duration: 0.1)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.layer.animateShadowRadius(from: Constants.minimumShadowRadius, to: Constants.defaultShadowRadius, duration: 0.1)
        self.layer.animateShadowOpacity(from: Constants.minimumShadowOpacity, to: Constants.defaultShadowOpacity, duration: 0.1)
        
        if let location = touches.first?.location(in: self),
            self.bounds.contains(location) {
            print("Touch ended.")
            UIView.animate(withDuration: 0.1, delay: 0.1, animations: {
                self.transform = CGAffineTransform.identity.scaledBy(x: 1.0, y: 1.0)
            }, completion: { _ in self.onTap() })
//            onTap()
        } else {
            UIView.animate(withDuration: Constants.touchTransitionTime, delay: 0.1, animations: {
                self.transform = CGAffineTransform.identity.scaledBy(x: 1.0, y: 1.0)
            })
            print("Cancelled")
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.layer.animateShadowOpacity(from: Constants.minimumShadowOpacity, to: Constants.defaultShadowOpacity, duration: 0.1)
        
        UIView.animate(withDuration: 0.25, animations: {
            self.transform = CGAffineTransform.identity.scaledBy(x: 1.0, y: 1.0)
        })
    }
    
    struct Constants {
        static let defaultShadowRadius: CGFloat = 9.0
        static let defaultShadowOpacity: Float = 0.12
        static let minimumShadowRadius: CGFloat = 6.0
        static let minimumShadowOpacity: Float = 0.05
        static let touchTransitionTime: TimeInterval = 0.2
    }
    
}
