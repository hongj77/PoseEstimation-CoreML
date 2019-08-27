//
//  VideoPlayback.swift
//  PoseEstimation-CoreML
//
//  Created by Daryl Sew on 8/25/19.
//  Copyright © 2019 tucan9389. All rights reserved.
//

import Foundation
import AVFoundation
import CoreVideo
import UIKit

public class VideoPlayback : NSObject {
    
    var reader: AVAssetReader!
    var videoTrack: AVAssetTrack!
    var trackReaderOutput: AVAssetReaderTrackOutput!
    var frame: Int = 0
    var lastFrame: CMSampleBuffer?
    let session = AVCaptureSession()
    let queue = DispatchQueue(label: "com.daryl.camera-queue")
    public var previewLayer: AVSampleBufferDisplayLayer!


    public init(fileURL: URL) {
        let asset = AVAsset(url: fileURL)
        reader = try! AVAssetReader(asset: asset)
        videoTrack = asset.tracks(withMediaType: AVMediaType.video)[0]
        
        // read video frames as BGRA
        trackReaderOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings:[String(kCVPixelBufferPixelFormatTypeKey): NSNumber(value: kCVPixelFormatType_32BGRA)])
        
        reader.add(trackReaderOutput)
        reader.startReading()
        previewLayer = AVSampleBufferDisplayLayer()
    }
    
    public func advanceFrame() -> CVImageBuffer? {
        if let sampleBuffer = trackReaderOutput.copyNextSampleBuffer() {
            lastFrame = sampleBuffer
            if let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
                print("Reading frame number \(frame)")
                frame += 1
                return imageBuffer
            }
        }
        return nil
    }
    
    public func displayFrame() {
        print("Displaying frame \(frame)")
        queue.sync {
            previewLayer.enqueue(lastFrame!)
        }
    }
}
/*
extension Video: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Because lowering the capture device's FPS looks ugly in the preview,
        // we capture at full speed but only call the delegate at its desired
        // framerate.
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let deltaTime = timestamp - lastTimestamp
        if deltaTime >= CMTimeMake(value: 1, timescale: Int32(fps)) {
            lastTimestamp = timestamp
            let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
            delegate?.videoCapture(self, didCaptureVideoFrame: imageBuffer, timestamp: timestamp)
        }
    }
    
    public func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        //print("dropped frame")
    }
}

*/
