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
import AVFoundation

class AICoachViewController: UIViewController {
    // MARK: - UI Property
    @IBOutlet weak var videoPreview: UIView!
    @IBOutlet weak var jointView: DrawingJointView!
    @IBOutlet weak var squatFormView: SquatDepthView!
    @IBOutlet weak var bufferImageView: UIImageView!
    
    private var workQueue = DispatchQueue(label: "com.apple.VelocityTraining", qos: .userInitiated)

    var capturedPointsArray: [[CapturedPoint?]?] = []
    
    var startPositionPointsArray: [CapturedPoint?] = []
    
    var started : Bool = false
    
    // MARK: - AV Property
    var videoCapture: VideoCapture!
    var videoTrack : AVAssetTrack?
    var reader : AVAssetReader?

    
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
        let captureMode = false
        
        if captureMode {
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
        } else {
            let picker = UIImagePickerController()
            picker.delegate = self
            picker.mediaTypes = UIImagePickerController.availableMediaTypes(for: .savedPhotosAlbum)!
            picker.mediaTypes = ["public.movie"]
            picker.allowsEditing = false
            present(picker, animated: true, completion: nil)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        resizePreviewLayer()
    }
    
    func resizePreviewLayer() {
        if videoCapture != nil && videoPreview != nil {
            videoCapture.previewLayer?.frame = videoPreview.bounds
        }
    }
}

// MARK: - UIImagePickerController
extension AICoachViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        let fileURL: URL = info[UIImagePickerController.InfoKey.mediaURL] as! URL
        let asset = AVAsset(url: fileURL)
        reader = try! AVAssetReader(asset: asset)
        videoTrack = asset.tracks(withMediaType: AVMediaType.video)[0]
        dismiss(animated: true, completion: { self.viewTrackCallback()})
    }
    
    func viewTrackCallback() {
        workQueue.async {
            // Read video frames as BGRA
            let trackReaderOutput = AVAssetReaderTrackOutput(track: self.videoTrack!, outputSettings:[String(kCVPixelBufferPixelFormatTypeKey): NSNumber(value: kCVPixelFormatType_32BGRA)])
            self.reader?.add(trackReaderOutput)
            self.reader?.startReading()
            var frame = 0
            while let sampleBuffer = trackReaderOutput.copyNextSampleBuffer() {
                if let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
                    // This image buffer needs to be transformed, scaled, and cropped into a square.
                    // Run inference and draw joints.
                    self.predictUsingVision(pixelBuffer: imageBuffer)
                    DispatchQueue.main.async {
                        let ciimage : CIImage = CIImage(cvPixelBuffer: imageBuffer).transformed(by: self.videoTrack!.preferredTransform.inverted())

                        // Display buffer frame by frame into image view.
                        let image : UIImage = self.convert(cmage: ciimage)
                        self.bufferImageView.image = image;
                        self.bufferImageView.setNeedsDisplay();
                    }
                    
                    frame += 1
                }
                usleep(useconds_t(10*1000))
            }
        }
    }
    
    // Convert CIImage to CGImage
    func convert(cmage:CIImage) -> UIImage
    {
        let context:CIContext = CIContext.init(options: nil)
        let cgImage:CGImage = context.createCGImage(cmage, from: cmage.extent)!
        let image:UIImage = UIImage.init(cgImage: cgImage)
        return image
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        print("boop")
        dismiss(animated: true, completion: nil)
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
        let affineTransform = self.videoTrack?.preferredTransform.inverted()
        
        let angleInDegrees = atan2(affineTransform!.b, affineTransform!.a) * CGFloat(180) / CGFloat.pi
        var orientation: UInt32 = 1
        switch angleInDegrees {
        case 0:
            orientation = 1 // Recording button is on the right
        case 180:
            orientation = 3 // abs(180) degree rotation recording button is on the right
        case -180:
            orientation = 3 // abs(180) degree rotation recording button is on the right
        case 90:
            orientation = 8 // 90 degree CW rotation recording button is on the top
        case -90:
            orientation = 6 // 90 degree CCW rotation recording button is on the bottom
        default:
            orientation = 1
        }
        
        let orientationProperty = CGImagePropertyOrientation(rawValue: orientation)
        request.imageCropAndScaleOption = .scaleFit
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientationProperty!)
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
        
        // draw joints

        // TODO daryl to draw result onto the actual image? or layer views on top of it?
        /* =================================================================== */
        /* ======================= display the results ======================= */
        DispatchQueue.main.sync {
            
            // Calculate start position match percentage
            if (matchingRatio > 0.994) {
                self.started = true
            }
            self.started = true
            
            if (!self.started) {
                // Display start position sillouette
                self.jointView.bodyPoints = predictedStartPoints
            } else {
                // draw joints
                self.jointView.bodyPoints = predictedPoints

                // calculate velocity in a buffer
                self.squatFormView.startbodyPoints = predictedPoints
                
                // Check squat form
                self.squatFormView.bodyPoints = predictedPoints
            }
        }
        /* =================================================================== */
    }
}
