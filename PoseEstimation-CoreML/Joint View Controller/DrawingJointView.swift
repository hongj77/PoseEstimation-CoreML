//
//  PoseView.swift
//  PoseEstimation-CoreML
//
//  Created by GwakDoyoung on 15/07/2018.
//  Copyright © 2018 tucan9389. All rights reserved.
//

import UIKit

class DrawingJointView: UIView {
    
    static let threshold = 0.7
    
    // the count of array may be <#14#> when use PoseEstimationForMobile's model
    private var keypointLabelBGViews: [UIView] = []

    public var bodyPoints: [PredictedPoint?] = [] {
        didSet {
            self.setNeedsDisplay()
            self.drawKeypoints(with: bodyPoints)
        }
    }
    
    private func setUpLabels(with keypointsCount: Int) {
        self.subviews.forEach({ $0.removeFromSuperview() })
        
        let pointSize = CGSize(width: 12, height: 12)
        keypointLabelBGViews = (0..<keypointsCount).map { index in
            let color = PoseEstimationForMobileConstant.colors[index%PoseEstimationForMobileConstant.colors.count]
            let view = UIView(frame: CGRect(x: 0, y: 0, width: pointSize.width, height: pointSize.height))
            view.backgroundColor = color
            view.clipsToBounds = false
            view.layer.cornerRadius = 3
            view.layer.borderColor = UIColor.black.cgColor
            view.layer.borderWidth = 1.4
            
            // Joint labels
            let label = UILabel(frame: CGRect(x: pointSize.width * 1.4, y: 0, width: 100, height: pointSize.height))
            label.text = PoseEstimationForMobileConstant.pointLabels[index%PoseEstimationForMobileConstant.colors.count]
            label.textColor = color
            label.font = UIFont.preferredFont(forTextStyle: .caption2)
            view.addSubview(label)
            
//            // Draw x y coordinates for the points that we have
//            if (bodyPoints.count > 0 && index < bodyPoints.count && bodyPoints[index] != nil) {
//                let x_pos = String(format: "%.3f", Double(bodyPoints[index]!.maxPoint.x))
//                let y_pos = String(format: "%.3f", Double(bodyPoints[index]!.maxPoint.y))
//                let position_label = UILabel(frame: CGRect(x: pointSize.width, y: 0, width: 200, height: pointSize.height + 30))
//                position_label.text = "[\(x_pos), \(y_pos)]"
//                position_label.textColor = color
//                position_label.font = UIFont.preferredFont(forTextStyle: .caption2)
//                view.addSubview(position_label)
//                
//                let confidence = String(format: "%.3f", Double(bodyPoints[index]!.maxConfidence))
//                let confidence_label = UILabel(frame: CGRect(x: pointSize.width, y: 0, width: 200, height: pointSize.height + 60))
//                confidence_label.text = "\(confidence)"
//                confidence_label.textColor = color
//                confidence_label.font = UIFont.preferredFont(forTextStyle: .caption2)
//                view.addSubview(confidence_label)
//                
////                print("\(label.text) | [\(x_pos), \(y_pos)] | \(confidence)")
//            }
        
            self.addSubview(view)
            return view
        }
        
        //var x: CGFloat = 0.0
        //let y: CGFloat = self.frame.size.height - 24
        //let _ = (0..<keypointsCount).map { index in
        //    let color = Constant.colors[index%Constant.colors.count]
        //    if index == 2 || index == 8 { x += 28 }
        //    else { x += 14 }
        //    let view = UIView(frame: CGRect(x: x, y: y + 10, width: 4, height: 4))
        //    view.backgroundColor = color
        //
        //    self.addSubview(view)
        //    return
        //}
    }
    
    override func draw(_ rect: CGRect) {
        if let ctx = UIGraphicsGetCurrentContext() {
            
            ctx.clear(rect);
            
            let size = self.bounds.size
            
            let color = PoseEstimationForMobileConstant.jointLineColor.cgColor
            if PoseEstimationForMobileConstant.pointLabels.count == bodyPoints.count {
                let _ = PoseEstimationForMobileConstant.connectedPointIndexPairs.map { pIndex1, pIndex2 in
                    if let bp1 = self.bodyPoints[pIndex1], bp1.maxConfidence > DrawingJointView.threshold,
                        let bp2 = self.bodyPoints[pIndex2], bp2.maxConfidence > DrawingJointView.threshold {
                        let p1 = bp1.maxPoint
                        let p2 = bp2.maxPoint
//                        print("p1 x:", p1.x, " y:", p1.y)
//                        print("p2 x:", p2.x, " y:", p2.y)
//                        print(size.width, size.height)

                        let point1 = CGPoint(x: p1.x * size.width, y: p1.y*size.height)
                        let point2 = CGPoint(x: p2.x * size.width, y: p2.y*size.height)
                        drawLine(ctx: ctx, from: point1, to: point2, color: color)
                    }
                }
            }
        }
    }
    
    private func drawLine(ctx: CGContext, from p1: CGPoint, to p2: CGPoint, color: CGColor) {
        ctx.setStrokeColor(color)
        ctx.setLineWidth(3.0)
        
        ctx.move(to: p1)
        ctx.addLine(to: p2)
        
        ctx.strokePath();
    }
    
    private func drawKeypoints(with n_kpoints: [PredictedPoint?]) {
        let imageFrame = keypointLabelBGViews.first?.superview?.frame ?? .zero
        
        let minAlpha: CGFloat = 0.4
        let maxAlpha: CGFloat = 1.0
        let maxC: Double = 0.6
        let minC: Double = 0.1
        
        if n_kpoints.count != keypointLabelBGViews.count {
            setUpLabels(with: n_kpoints.count)
        }
        
        for (index, kp) in n_kpoints.enumerated() {
            if let n_kp = kp {
//                print("n_kp.maxPoint.x: ", n_kp.maxPoint.x)
//                print("n_kp.maxPoint.y: ", n_kp.maxPoint.y)

                let x = n_kp.maxPoint.x * imageFrame.width
                let y = n_kp.maxPoint.y * imageFrame.height
                
//                print("x", x)
//                print("y",y)
                
                keypointLabelBGViews[index].center = CGPoint(x: x, y: y)
                let cRate = (n_kp.maxConfidence - minC)/(maxC - minC)
                keypointLabelBGViews[index].alpha = (maxAlpha - minAlpha) * CGFloat(cRate) + minAlpha
            } else {
                keypointLabelBGViews[index].center = CGPoint(x: -4000, y: -4000)
                keypointLabelBGViews[index].alpha = minAlpha
            }
        }
    }
}

// MARK: - Constant for edvardHua/PoseEstimationForMobile
struct PoseEstimationForMobileConstant {
    static let pointLabels = [
        "top",          //0
        "neck",         //1
        
        "R shoulder",   //2
        "R elbow",      //3
        "R wrist",      //4
        "L shoulder",   //5
        "L elbow",      //6
        "L wrist",      //7
        
        "R hip",        //8
        "R knee",       //9
        "R ankle",      //10
        "L hip",        //11
        "L knee",       //12
        "L ankle",      //13
    ]
    
    static let connectedPointIndexPairs: [(Int, Int)] = [
        (0, 1),     // top-neck
        
        (1, 2),     // neck-rshoulder
        (2, 3),     // rshoulder-relbow
        (3, 4),     // relbow-rwrist
        (1, 8),     // neck-rhip
        (8, 9),     // rhip-rknee
        (9, 10),    // rknee-rankle
        
        (1, 5),     // neck-lshoulder
        (5, 6),     // lshoulder-lelbow
        (6, 7),     // lelbow-lwrist
        (1, 11),    // neck-lhip
        (11, 12),   // lhip-lknee
        (12, 13),   // lknee-lankle
    ]
    static let jointLineColor: UIColor = UIColor(red: 26.0/255.0, green: 187.0/255.0, blue: 229.0/255.0, alpha: 0.8)
    
    static var colors: [UIColor] = [
        .red,
        .green,
        .blue,
        .cyan,
        .yellow,
        .magenta,
        .orange,
        .purple,
        .brown,
        .black,
        .darkGray,
        .lightGray,
        .white,
        .gray,
    ]

        
}
