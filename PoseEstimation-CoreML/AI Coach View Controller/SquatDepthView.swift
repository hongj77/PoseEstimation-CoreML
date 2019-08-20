//
//  SquatDepthView.swift
//  PoseEstimation-CoreML
//
//  Created by Hong Jeon on 8/18/19.
//  Copyright © 2019 tucan9389. All rights reserved.
//

import UIKit

class SquatDepthView: UIView {
    
    var belowKnees = false
    
    // There's 14 of these returned from the model.
    public var bodyPoints: [PredictedPoint?] = [] {
        didSet {
            self.setNeedsDisplay()
            self.checkSquatDepth(with: bodyPoints)
        }
    }
    
    private func checkSquatDepth(with n_kpoints: [PredictedPoint?]) {
        var l_hip : PredictedPoint? = nil
        var r_hip : PredictedPoint? = nil
        var l_knee : PredictedPoint? = nil
        var r_knee : PredictedPoint? = nil
        for (index, kp) in n_kpoints.enumerated() {
            // R_hip
            if index == 8 {
                r_hip = kp
            }
            // R_knee
            if index == 9 {
                r_knee = kp
            }
            if index == 11 {
                l_hip = kp
            }
            if index == 12 {
                l_knee = kp
            }
        }
        
        // Check if the hips are parallel/below the knees
        if (l_hip != nil && r_hip != nil && l_knee != nil && r_knee != nil) {
            print("l_hip!.maxPoint.y: ", l_hip!.maxPoint.y)
            print("l_knee!.maxPoint.y: ", l_knee!.maxPoint.y)
            print("r_hip!.maxPoint.y: ", r_hip!.maxPoint.y)
            print("r_knee!.maxPoint.y: ", r_knee!.maxPoint.y)
            
            if (l_hip!.maxPoint.y >= l_knee!.maxPoint.y
                && r_hip!.maxPoint.y >= r_knee!.maxPoint.y) {
                belowKnees = true
            } else {
                belowKnees = false
            }
        }
    }

    override func draw(_ rect: CGRect) {
        if let ctx = UIGraphicsGetCurrentContext() {
            if belowKnees {
                self.backgroundColor = UIColor(named: "Green")!
                print("below knees = true")
            } else {
                self.backgroundColor = UIColor(named: "Red")!
                print("below knees = false")
            }
        }
    }
}
