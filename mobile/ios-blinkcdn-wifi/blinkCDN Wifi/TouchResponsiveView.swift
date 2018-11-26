//
//  TouchResponsiveView.swift
//  blinkCDN Wifi
//
//  Created by Charles Bethin on 10/1/18.
//  Copyright © 2018 Charles Bethin. All rights reserved.
//

import UIKit

class TouchResponsiveView: UIView {
    
    struct ShadowValues {
        var radius: CGFloat = 9.0
        var opacity: Float = 0.12
        var color: CGColor = UIColor.black.cgColor
        var offset: CGSize = CGSize(width: -4.0, height: 6.0)
    }
    
    var shadow = ShadowValues()
    
    func setup() {
        self.layer.roundCorners(radius: 10.0)
        self.layer.addShadow(opacity: 0.3, radius: 15.0)
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        UIView.animate(withDuration: 0.2, animations: {
            self.transform = CGAffineTransform.identity.scaledBy(x: 0.95, y: 0.95)
        })
        self.layer.animateShadowRadius(from: self.layer.shadowRadius, to: 1.0, duration: 0.2)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        UIView.animate(withDuration: 0.2, delay: 0.1, animations: {
            self.transform = CGAffineTransform.identity.scaledBy(x: 1.0, y: 1.0)
        })
        self.layer.animateShadowRadius(from: self.layer.shadowRadius, to: self.shadow.radius, duration: 0.2)
        
        if let location = touches.first?.location(in: self),
            self.bounds.contains(location) {
            print("Ended.")
        } else {
            print("Cancelled")
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        UIView.animate(withDuration: 0.25, animations: {
            self.transform = CGAffineTransform.identity.scaledBy(x: 1.0, y: 1.0)
        })
    }
    
}

extension CALayer {
    
    func animateShadowOpacity(from fromValue: Float, to toValue: Float, duration: TimeInterval) {
        let animation = CABasicAnimation(keyPath: #keyPath(CALayer.shadowOpacity))
        animation.duration = duration
        animation.fromValue = fromValue
        animation.toValue = toValue
        
        self.shadowOpacity = toValue
        self.add(animation, forKey: #keyPath(CALayer.shadowOpacity))
    }
    
    func animateShadowRadius(from fromValue: CGFloat, to toValue: CGFloat, duration: TimeInterval) {
        let animation = CABasicAnimation(keyPath: #keyPath(CALayer.shadowRadius))
        animation.duration = duration
        animation.fromValue = fromValue
        animation.toValue = toValue
        
        self.shadowRadius = toValue
        self.add(animation, forKey: #keyPath(CALayer.shadowRadius))
    }
    
    func addShadow(offset: CGSize = CGSize(width: -4.0, height: 6.0), opacity: Float = 0.2, radius: CGFloat = 9.0, color: UIColor = .black) {
        self.shadowOffset = offset
        self.shadowOpacity = opacity
        self.shadowRadius = radius
        self.shadowColor = color.cgColor
        self.masksToBounds = false
        
        if cornerRadius != 0 {
            addShadowWithRoundedCorners()
        }
    }
    
    func roundCorners(radius: CGFloat) {
        self.cornerRadius = radius
        
        if shadowOpacity != 0 {
            addShadowWithRoundedCorners()
        }
    }
    
    struct Constants {
        static let x: Int = 12
    }
    
    private func addShadowWithRoundedCorners() {
        if let contents = self.contents {
            masksToBounds = false
            sublayers?.filter { $0.frame.equalTo(self.bounds) }
                .forEach { $0.roundCorners(radius: self.cornerRadius) }
            
            self.contents = nil
            
            if let sublayer = sublayers?.first {
                sublayer.removeFromSuperlayer()
            }
            
            let contentLayer = CALayer()
            contentLayer.contents = contents
            contentLayer.frame = bounds
            contentLayer.cornerRadius = cornerRadius
            contentLayer.masksToBounds = true
            
            insertSublayer(contentLayer, at: 0)
        }
    }
}

