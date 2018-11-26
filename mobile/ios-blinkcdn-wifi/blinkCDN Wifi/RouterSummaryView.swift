////
////  RouterSummaryView.swift
////  blinkCDN Wifi
////
////  Created by Charles Bethin on 9/26/18.
////  Copyright © 2018 Charles Bethin. All rights reserved.
////
//
//import UIKit
//
//class RouterSummaryView: UIView {
//
//    @IBOutlet weak var routerNameLabel: UILabel!
//    @IBOutlet weak var routerIPLabel: UILabel!
//    @IBOutlet weak var routerMACLabel: UILabel!
//    @IBOutlet weak var routerImageView: UIImageView! {
//        didSet {
//            let image = UIImage(named: "RouterImage.png")
//            routerImageView.image = image
//        }
//    }
//    @IBOutlet weak var scrollView: UIScrollView!
//    @IBOutlet var connectedToBottomConstraint: NSLayoutConstraint!
//    @IBOutlet var heightOfView: NSLayoutConstraint!
//    
//    var routerName: String? {
//        get {
//            return routerNameLabel.text
//        }
//        set {
//            routerNameLabel.text? = routerName ?? "BlinkCDN Wifi"
//        }
//    }
//    
//    var routerIPAddress: String? {
//        get {
//            return routerIPLabel.text
//        }
//        set {
//            routerIPLabel.text = newValue
//        }
//    }
//    
//    var routerMACAddress: String? {
//        get {
//            return routerMACLabel.text
//        }
//        set {
//            routerMACLabel.text = newValue
//        }
//    }
//    
//    override func willMove(toSuperview newSuperview: UIView?) {
//        layer.shadowColor = UIColor.black.cgColor
//        layer.shadowOffset = CGSize(width: 0, height: 4)
//        layer.shadowRadius = 5
//        layer.shadowOpacity = 0.12
//    }
//    
////    override func didMoveToSuperview() {
////        scrollView.heightAnchor.constraint(equalToConstant: 0).isActive = true
////    }
//    
//    func updateView() {
//        setNeedsLayout()
//        setNeedsDisplay()
//    }
//    
//    /*
//    // Only override draw() if you perform custom drawing.
//    // An empty implementation adversely affects performance during animation.
//    override func draw(_ rect: CGRect) {
//        // Drawing code
//    }
//    */
//
//}
