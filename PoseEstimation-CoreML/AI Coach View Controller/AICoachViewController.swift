//
//  AICoachViewController.swift
//  PoseEstimation-CoreML
//
//  Created by Hong Jeon on 8/17/19.
//  Copyright © 2019 tucan9389. All rights reserved.
//

import UIKit
import CoreMedia
import Vision

class AICoachViewController: UIViewController {
    // MARK: - UI Property
    @IBOutlet weak var videoPreview: UIView!
    @IBOutlet weak var jointView: DrawingJointView!
    @IBOutlet weak var squatFormView: SquatDepthView!

    var capturedPointsArray: [[CapturedPoint?]?] = []
    
    var startPositionPointsArray: [CapturedPoint?] = []
    
    var started : Bool = false
    
    // MARK: - AV Property
    var videoCapture: VideoCapture!
    
    // MARK: - ML Properties
    // Core ML model
    typealias EstimationModel = model_cpm
    
    // Preprocess and Inference
    var request: VNCoreMLRequest?
    var visionModel: VNCoreMLModel?
    
    // Postprocess
    var postProcessor: HeatmapPostProcessor = HeatmapPostProcessor()
    var mvfilters: [MovingAverageFilter] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // setup model
        setUpModel()

        // setup camera
        setUpCamera()
        
        // controller states
        setUpControllerStates()
    }
    
    func setUpControllerStates() {
        // Initialize startPoisitionPointsArray. Order matters here.
        // Top
        let top_point = CGPoint(x:0.495, y:0.089)
        startPositionPointsArray.append(CapturedPoint(predictedPoint: PredictedPoint(maxPoint: top_point, maxConfidence: 1)))
        // Neck
        let neck_point = CGPoint(x:0.495, y:0.214)
        startPositionPointsArray.append(CapturedPoint(predictedPoint: PredictedPoint(maxPoint: neck_point, maxConfidence: 1)))
        // R Shoulder
        let r_shoulder_point = CGPoint(x:0.578, y:0.255)
        startPositionPointsArray.append(CapturedPoint(predictedPoint: PredictedPoint(maxPoint: r_shoulder_point, maxConfidence: 1)))
        // R Elbow
        startPositionPointsArray.append(nil)
        // R Wrist
        startPositionPointsArray.append(nil)
        // L Shoulder
        let l_shoulder_point = CGPoint(x:0.370, y:0.255)
        startPositionPointsArray.append(CapturedPoint(predictedPoint: PredictedPoint(maxPoint: l_shoulder_point, maxConfidence: 1)))
        // L Elbow
        startPositionPointsArray.append(nil)
        // L Wrist
        startPositionPointsArray.append(nil)
        // R Hip
        startPositionPointsArray.append(nil)
        // R Knee
        startPositionPointsArray.append(nil)
        // R Ankle
        startPositionPointsArray.append(nil)
        // L Hip
        startPositionPointsArray.append(nil)
        // L Knee
        startPositionPointsArray.append(nil)
        // L Ankle
        startPositionPointsArray.append(nil)
    }
    
    // MARK: - Setup Core ML
    func setUpModel() {
        if let visionModel = try? VNCoreMLModel(for: EstimationModel().model) {
            self.visionModel = visionModel
            request = VNCoreMLRequest(model: visionModel, completionHandler: visionRequestDidComplete)
            request?.imageCropAndScaleOption = .scaleFit
        } else {
            fatalError("cannot load the ml model")
        }
    }
    
    // MARK: - SetUp Video
    func setUpCamera() {
        videoCapture = VideoCapture()
        videoCapture.delegate = self
        videoCapture.fps = 30
        videoCapture.setUp(sessionPreset: .vga640x480, cameraPosition: .front) { success in
            
            if success {
                // add preview view on the layer
                if let previewLayer = self.videoCapture.previewLayer {
                    self.videoPreview.layer.addSublayer(previewLayer)
                    self.resizePreviewLayer()
                }
                
                // start video preview when setup is done
                self.videoCapture.start()
            }
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        resizePreviewLayer()
    }
    
    func resizePreviewLayer() {
        videoCapture.previewLayer?.frame = videoPreview.bounds
    }
}

// MARK: - VideoCaptureDelegate
extension AICoachViewController: VideoCaptureDelegate {
    func videoCapture(_ capture: VideoCapture, didCaptureVideoFrame pixelBuffer: CVPixelBuffer?, timestamp: CMTime) {
        // the captured image from camera is contained on pixelBuffer
        if let pixelBuffer = pixelBuffer {
            predictUsingVision(pixelBuffer: pixelBuffer)
        }
    }
}

extension AICoachViewController {
    // MARK: - Inferencing
    func predictUsingVision(pixelBuffer: CVPixelBuffer) {
        guard let request = request else { fatalError() }
        // vision framework configures the input size of image following our model's input configuration automatically
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer)
        try? handler.perform([request])
    }
    
    // MARK: - Postprocessing
    func visionRequestDidComplete(request: VNRequest, error: Error?) {
        guard let observations = request.results as? [VNCoreMLFeatureValueObservation],
            let heatmaps = observations.first?.featureValue.multiArrayValue else { return }
        
        /* =================================================================== */
        /* ========================= post-processing ========================= */
        
        /* ------------------ convert heatmap to point array ----------------- */
        var predictedPoints = postProcessor.convertToPredictedPoints(from: heatmaps, isFlipped: true)
        
        /* --------------------- moving average filter ----------------------- */
        if predictedPoints.count != mvfilters.count {
            mvfilters = predictedPoints.map { _ in MovingAverageFilter(limit: 3) }
        }
        for (predictedPoint, filter) in zip(predictedPoints, mvfilters) {
            filter.add(element: predictedPoint)
        }
        predictedPoints = mvfilters.map { $0.averagedValue() }
        
        /* =================================================================== */
        
        let matchingRatio = startPositionPointsArray.matchVector(with: predictedPoints)
        let predictedStartPoints = startPositionPointsArray.map ({ (capturedPoint) -> PredictedPoint? in
            if (capturedPoint != nil) {
                return PredictedPoint(capturedPoint: capturedPoint!)
            } else {
                return nil
            }
        })
        
        /* =================================================================== */
        /* ======================= display the results ======================= */
        DispatchQueue.main.sync { [weak self] in
            guard let self = self else { return }
            
            if (matchingRatio > 0.994) {
                started = true
//                print("matchingRatio: \(matchingRatio)")
            }
            
            if (!started) {
                self.jointView.bodyPoints = predictedStartPoints
//                print("waiting to match..")
            } else {
                // draw line
                self.jointView.bodyPoints = predictedPoints
                self.squatFormView.startbodyPoints = predictedPoints
//                print("MATCHED")
            }

            // come up with hardcoded sillouete coordinates
            // create a sillouete UIView
            
//            if !started then compare sillouete and update start condition
//            if started, then check squat form


//            // Check squat form
//            self.squatFormView.bodyPoints = predictedPoints

            // if at the bottom, then save the frame from before as bottom frame.
            // in post processing overlay heatmap on the butt and knee joints
        }
        /* =================================================================== */
    }
}
