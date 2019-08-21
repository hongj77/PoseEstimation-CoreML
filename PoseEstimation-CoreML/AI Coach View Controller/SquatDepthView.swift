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
    var pointsHistory: Queue<[PredictedPoint?]> = Queue<[PredictedPoint?]>()
    let maxHistoryFrames: Int = 100
    enum PointLabels: Int {
        case top = 0, neck, rightShoulder, rightElbow, rightWrist, leftElbow, leftWrist,
        rightHip, rightKnee, rightAnkle, leftHip, leftKnee, leftAnkle
    }
    
    // There's 14 of these returned from the model.
    public var bodyPoints: [PredictedPoint?] = [] {
        didSet {
            self.setNeedsDisplay()
            self.checkSquatDepth(with: bodyPoints)
        }
    }
    
    // There's 14 of these returned from the model.
    public var startbodyPoints: [PredictedPoint?] = [] {
        didSet {
            self.setNeedsDisplay()
            self.checkVelocity(with: startbodyPoints)
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

            if (l_hip!.maxPoint.y >= l_knee!.maxPoint.y
                && r_hip!.maxPoint.y >= r_knee!.maxPoint.y) {
                belowKnees = true
            } else {
                belowKnees = false
            }
        }
    }

    private func checkVelocity(with n_kpoints: [PredictedPoint?]) {
        // Assumes the set starts as soon as the recording starts
        // and ends after 100 frames have been processed
        
        let userHeightInMeters : CGFloat = 1.7272
        // Approximate time between frames; TODO keep track of exact time between frames
        let dt: CGFloat = 0.1
        if pointsHistory.count > maxHistoryFrames {
            var roi : [[PredictedPoint?]] = []
            while (pointsHistory.count > 0) {
                if let frame = pointsHistory.dequeue() {
                    print("Frame count: \(frame.count)")
                    if frame.count > PointLabels.neck.rawValue {
                        roi.append(frame)
                    }
                }
            }
            // Find bottom of squat
            var minIndex: Int = -1
            // Minimum neck height is actually maximum in image coords
            var minNeckPoint: CGFloat = 0
            for frameIndex in 0..<roi.count {
                let frame = roi[frameIndex]
                if let newNeckPoint = frame[PointLabels.neck.rawValue] {
                    if newNeckPoint.maxPoint.y > minNeckPoint {
                        minNeckPoint = newNeckPoint.maxPoint.y
                        minIndex = frameIndex
                    }
                }
            }
            // Now that we have height of the bottom of the squat, let's get the first max before the min
            var firstMaxIndex: Int = -1
            var firstMaxNeckPoint: CGFloat = 99999
            if minIndex < 0 {
                print("Error computing velocity, can't find minimum neck position")
                return
            }
            for frameIndex in 0..<minIndex {
                let frame = roi[frameIndex]
                if let newNeckPoint = frame[PointLabels.neck.rawValue] {
                    if newNeckPoint.maxPoint.y < firstMaxNeckPoint {
                        firstMaxNeckPoint = newNeckPoint.maxPoint.y
                        firstMaxIndex = frameIndex
                    }
                }
            }
            var secondMaxIndex: Int = -1
            var secondMaxNeckPoint: CGFloat = 99999
            for frameIndex in minIndex..<roi.count {
                let frame = roi[frameIndex]
                if let newNeckPoint = frame[PointLabels.neck.rawValue] {
                    if newNeckPoint.maxPoint.y < secondMaxNeckPoint {
                        secondMaxNeckPoint = newNeckPoint.maxPoint.y
                        secondMaxIndex = frameIndex
                    }
                }
            }
            // TODO estimate pixel-distance height from distance between top and ankles. Assuming height is 1 for now
            let pixelDistance: CGFloat = minNeckPoint - secondMaxNeckPoint
            let metersDistance: CGFloat = pixelDistance * userHeightInMeters
            let time: CGFloat = CGFloat(secondMaxIndex - minIndex) * dt
            let velocity: CGFloat = metersDistance / time
            print("Upwards squat velocity: \(velocity)")
        }
        print("Original frame count: \(n_kpoints.count)")
    
        pointsHistory.enqueue(n_kpoints)
    }

    override func draw(_ rect: CGRect) {
        if let ctx = UIGraphicsGetCurrentContext() {
            if belowKnees {
                self.backgroundColor = UIColor(named: "Green")!
            } else {
                self.backgroundColor = UIColor(named: "Red")!
            }
        }
    }
}
