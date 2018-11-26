//
//  LoginViewController.swift
//  blinkCDN Wifi
//
//  Created by Charles Bethin on 11/17/18.
//  Copyright © 2018 Charles Bethin. All rights reserved.
//

import UIKit

@IBDesignable
class LoginViewController: UIViewController, UITextFieldDelegate {

    @IBOutlet weak var keyField: UITextField!
    @IBOutlet weak var doneButton: UIButton!
    
    var wifiController: WifiController?
    var presentedBy: UIViewController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.modalPresentationStyle = .none

        // Do any additional setup after loading the view.
        doneButton.layer.cornerRadius = 4
        
        keyField.borderStyle = .none
        keyField.underlined()
        keyField.becomeFirstResponder()
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        if let wifiController = wifiController,
            let key = textField.text {
            
            wifiController.tryKey(key: key, completion: { (isSuccess) in
                if (!isSuccess) {
                    DispatchQueue.main.async {
                        textField.text = ""
                        textField.placeholder = "Try Again"
                    }
                } else {
                    DispatchQueue.main.async{
                        if let presentedBy = self.presentedBy as? DeviceListViewController {
                            presentedBy.setupWifiController()
                        } else {
                            print("NOPE")
                        }
                        
                        self.dismiss(animated: true, completion: nil)
                    }
                    
                }
            })
        }
    }
    
    @IBAction func doneEditing(_ sender: Any) {
        keyField.resignFirstResponder()
    }
    
    @IBAction func onTapHiddenButton(_ sender: Any) {
        if let pv = self.presentedBy as? DeviceListViewController {
            pv.setupWifiController()
            pv.updateChartData()
        } else {
            print("NAH")
        }
        
        self.dismiss(animated: true, completion: nil)
    }
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segue.identifier {
        case "keySuccess":
            if let destination = segue.destination as? DeviceListViewController {
                destination.setupWifiController()
            }
        default: break
            
        }
    }

}

extension UITextField {
    func underlined(){
        let border = CALayer()
        let width = CGFloat(1.0)
        border.borderColor = UIColor.lightGray.cgColor
        border.frame = CGRect(x: 0, y: self.frame.size.height - width, width:  self.frame.size.width, height: self.frame.size.height)
        border.borderWidth = width
        self.layer.addSublayer(border)
        self.layer.masksToBounds = true
    }
}
