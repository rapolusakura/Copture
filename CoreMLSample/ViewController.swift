//
//  ViewController.swift
//  CoreMLSimple
//
//  Created by 杨萧玉 on 2017/6/9.
//  Copyright © 2017年 杨萧玉. All rights reserved.
//

import UIKit
import CoreMedia
import Vision
import Firebase
import FirebaseDatabase
import AVFoundation
import MobileCoreServices

class ViewController: UIViewController, UIImagePickerControllerDelegate {
    // Outlets to label and view
    
    @IBOutlet var camPreview: UIView!
    @IBOutlet private weak var predictLabel: UILabel!
    @IBOutlet private weak var previewView: UIView!
    @IBOutlet private weak var visionSwitch: UISwitch!
    @IBOutlet weak var imageView: UIImageView!
    @IBAction func recordButtonPressed(_ sender: Any) {
        VideoHelper.startMediaBrowser(delegate: self, sourceType: .camera)
    }
    
    // some properties used to control the app and store appropriate values
    
    let inceptionv3model = Inceptionv3()
    private var videoCapture: VideoCapture!
    private var requests = [VNRequest]()
    let thresh = 50.0
    var caud: Double = 0.0
    var cvid: Double = 0.0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        var ref: DatabaseReference! = Database.database().reference()
        
        let refHandle = ref.observe(DataEventType.value, with: { (snapshot) in
            let postDict = snapshot.value as? [String : AnyObject] ?? [:]
            var caud = postDict["Predictions"] as! Double
            if (caud >= 50.0 || self.cvid >= 30) {
                AudioServicesPlayAlertSound(SystemSoundID(1322))
                VideoHelper.startMediaBrowser(delegate: self, sourceType: .camera)
            }
            if ((50*caud + 30*self.cvid)/100 > self.thresh){
                AudioServicesPlayAlertSound(SystemSoundID(1322))
                VideoHelper.startMediaBrowser(delegate: self, sourceType: .camera)
            }
        })
        
        let singleTap = UITapGestureRecognizer(target: self,action:Selector("imageTapped"))
        imageView.isUserInteractionEnabled = true
        imageView.addGestureRecognizer(singleTap)
        self.imageView.image = UIImage(named: "lol.png")
        setupVision()
        let spec = VideoSpec(fps: 100, size: CGSize(width: 299, height: 299))
        videoCapture = VideoCapture(cameraType: .back,
                                    preferredSpec: spec,
                                    previewContainer: previewView.layer)
        
        videoCapture.imageBufferHandler = {[unowned self] (imageBuffer) in
            if self.visionSwitch.isOn {
                // Use Vision
                self.handleImageBufferWithVision(imageBuffer: imageBuffer)
            }
            else {
                // Use Core ML
                self.handleImageBufferWithCoreML(imageBuffer: imageBuffer)
            }
        }
    }
    
    func handleImageBufferWithCoreML(imageBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(imageBuffer) else {
            return
        }
        do {
            let prediction = try self.inceptionv3model.prediction(image: self.resize(pixelBuffer: pixelBuffer)!)
            DispatchQueue.main.async {
                if let prob = prediction.classLabelProbs[prediction.classLabel] {
                    self.predictLabel.text = "\(prediction.classLabel) \(String(describing: prob))"
                }
            }
        }
        catch let error as NSError {
            fatalError("Unexpected error ocurred: \(error.localizedDescription).")
        }
    }
    
    @objc func imageTapped() {
        performSegue(withIdentifier: "clickedMap", sender: self)
    }
    
    func handleImageBufferWithVision(imageBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(imageBuffer) else {
            return
        }
        
        var requestOptions:[VNImageOption : Any] = [:]
        
        if let cameraIntrinsicData = CMGetAttachment(imageBuffer, kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, nil) {
            requestOptions = [.cameraIntrinsics:cameraIntrinsicData]
        }
        
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: CGImagePropertyOrientation(rawValue: UInt32(self.exifOrientationFromDeviceOrientation))!, options: requestOptions)
        do {
            try imageRequestHandler.perform(self.requests)
        } catch {
            print(error)
        }
    }
    
    func setupVision() {
        let weapons: Set = ["gun", "revolver", "six-gun", "six-shooter", "pistol", "holster", "knife", "weapon", "rifle", "cleaver", "chopper", "paperknife", "paper knife", "assault rife", "assault gun", "hatchet", "scabbard", "guillotine", "letter opener, paper knife, paperknife", "revolver, six-gun, six-shooter", "assault rifle, assault gun"]
        guard let visionModel = try? VNCoreMLModel(for: inceptionv3model.model) else {
            fatalError("can't load Vision ML model")
        }
        let classificationRequest = VNCoreMLRequest(model: visionModel) { (request: VNRequest, error: Error?) in
            guard let observations = request.results else {
                print("no results:\(error!)")
                return
            }
            
            let classifications = observations[0...4]
                .compactMap({ $0 as? VNClassificationObservation })
                .filter({ $0.confidence >= 0.05 })
                .filter({ weapons.contains($0.identifier)})
                .map({ "\($0.identifier) \($0.confidence)" })
            if (classifications.count >= 1 ) {print((classifications[0] as? VNClassificationObservation)?.confidence)}
            
            if (classifications.count >= 1) {
                let strArray = classifications[0].components(separatedBy: " ")
                let confidence = strArray[strArray.count - 1]
                print(confidence)
                
                if let confidence = Double(confidence) {
                    if (confidence >= 0.35) {
                        AudioServicesPlayAlertSound(SystemSoundID(1322))
                        VideoHelper.startMediaBrowser(delegate: self, sourceType: .camera)
                    }
                }
            }
            DispatchQueue.main.async {
                self.predictLabel.text = classifications.joined(separator: "\n")
//                if(classifications.count >= 1) {
//                    var confidence = (classifications[classifications.count-1] as? VNClassificationObservation)?.confidence
//                    print("confidence: \(confidence)")
//                    guard case let self.caud = confidence as! Double
//                        else {self.caud = 5}
//                    print("confidence: \(confidence)")
//                }
            }
            
        }
        classificationRequest.imageCropAndScaleOption = VNImageCropAndScaleOption.centerCrop
        
        self.requests = [classificationRequest]
    }
    
    @objc func video(_ videoPath: String, didFinishSavingWithError error: Error?, contextInfo info: AnyObject) {
        let title = (error == nil) ? "Success" : "Error"
        let message = (error == nil) ? "Video was saved" : "Video failed to save"
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
    /// only support back camera
    var exifOrientationFromDeviceOrientation: Int32 {
        let exifOrientation: DeviceOrientation
        enum DeviceOrientation: Int32 {
            case top0ColLeft = 1
            case top0ColRight = 2
            case bottom0ColRight = 3
            case bottom0ColLeft = 4
            case left0ColTop = 5
            case right0ColTop = 6
            case right0ColBottom = 7
            case left0ColBottom = 8
        }
        switch UIDevice.current.orientation {
        case .portraitUpsideDown:
            exifOrientation = .left0ColBottom
        case .landscapeLeft:
            exifOrientation = .top0ColLeft
        case .landscapeRight:
            exifOrientation = .bottom0ColRight
        default:
            exifOrientation = .right0ColTop
        }
        return exifOrientation.rawValue
    }
    
    
    /// resize CVPixelBuffer
    ///
    /// - Parameter pixelBuffer: CVPixelBuffer by camera output
    /// - Returns: CVPixelBuffer with size (299, 299)
    func resize(pixelBuffer: CVPixelBuffer) -> CVPixelBuffer? {
        let imageSide = 299
        var ciImage = CIImage(cvPixelBuffer: pixelBuffer, options: nil)
        let transform = CGAffineTransform(scaleX: CGFloat(imageSide) / CGFloat(CVPixelBufferGetWidth(pixelBuffer)), y: CGFloat(imageSide) / CGFloat(CVPixelBufferGetHeight(pixelBuffer)))
        ciImage = ciImage.transformed(by: transform).cropped(to: CGRect(x: 0, y: 0, width: imageSide, height: imageSide))
        let ciContext = CIContext()
        var resizeBuffer: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault, imageSide, imageSide, CVPixelBufferGetPixelFormatType(pixelBuffer), nil, &resizeBuffer)
        ciContext.render(ciImage, to: resizeBuffer!)
        return resizeBuffer
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard let videoCapture = videoCapture else {return}
        videoCapture.startCapture()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard let videoCapture = videoCapture else {return}
        videoCapture.resizePreview()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        guard let videoCapture = videoCapture else {return}
        videoCapture.stopCapture()
        
        navigationController?.setNavigationBarHidden(false, animated: true)
        super.viewWillDisappear(animated)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        dismiss(animated: true, completion: nil)
        
        guard let mediaType = info[UIImagePickerControllerMediaType] as? String,
            mediaType == (kUTTypeMovie as String),
            let url = info[UIImagePickerControllerMediaURL] as? URL,
            UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(url.path)
            else { return }
        
        // Handle a movie capture
        UISaveVideoAtPathToSavedPhotosAlbum(url.path, self, #selector(video(_:didFinishSavingWithError:contextInfo:)), nil)
    }
}

extension ViewController: UINavigationControllerDelegate {
}
