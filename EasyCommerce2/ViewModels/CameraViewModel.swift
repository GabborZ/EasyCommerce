//
//  CameraViewModel.swift
//  EasyCommerce2
//
//  Created by Gabriele Fiore on 08/12/24.
//

import AVFoundation
import Vision
import SwiftUI
import CoreImage

class CameraViewModel: NSObject, ObservableObject {
    @Published var detectedObject: String?
    @Published var detectedObjectwithoutconfidence: String?
    @Published var detectedColor: String = "Unknown Color" // For displaying detected color
    @Published var extractedRGB: (red: CGFloat, green: CGFloat, blue: CGFloat) = (0.0, 0.0, 0.0)
    @Published var recognizedText: String = ""

    
    // Add a method for text recognition
    func recognizeText(from image: UIImage, completion: @escaping (String) -> Void) {
        guard let cgImage = image.cgImage else {
            completion("Failed to process image.")
            return
        }

        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let request = VNRecognizeTextRequest { request, error in
            if let error = error {
                print("Text recognition error: \(error)")
                completion("Text recognition failed.")
                return
            }

            let recognizedStrings = request.results?
                .compactMap { $0 as? VNRecognizedTextObservation }
                .compactMap { $0.topCandidates(1).first?.string }
                ?? []

            DispatchQueue.main.async {
                self.recognizedText = recognizedStrings.joined(separator: "\n")
                completion(self.recognizedText)
            }
        }

        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        do {
            try requestHandler.perform([request])
        } catch {
            print("Failed to perform text recognition: \(error)")
            completion("Text recognition failed.")
        }
    }
    
    // MARK: - Capture Session Components
    let captureSession = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput() // Photo capture output
    private let videoOutput = AVCaptureVideoDataOutput()
    private var lastProcessedTime = Date()
    
    // Retain the photo capture processor
    private var photoCaptureProcessor: PhotoCaptureProcessor?

    // MARK: - CoreML Model
    private let objectDetectionModel: VNCoreMLModel = {
        do {
            let config = MLModelConfiguration()
            let model = try MyObjectDetector_1(configuration: config).model
            return try VNCoreMLModel(for: model)
        } catch {
            fatalError("Failed to load CoreML model: \(error)")
        }
    }()
    // MARK: - Initialization
    override init() {
        super.init()
        setupCamera()
        observeSessionRuntimeErrors()
    }
    // MARK: - Session Management
    func startSession() {
        checkCameraPermissions { granted in
            guard granted else {
                print("Camera access denied.")
                return
            }

            DispatchQueue.global(qos: .userInitiated).async {
                self.captureSession.startRunning()
                print("Capture session is running: \(self.captureSession.isRunning)")
            }
        }
    }
    // MARK: - Camera Configuration
    private func setupCamera() {
        guard let device = AVCaptureDevice.default(for: .video) else {
            print("No video device available.")
            return
        }
        do {
            // Add Input
            let input = try AVCaptureDeviceInput(device: device)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
                print("Camera input added: \(input.device.localizedName)")
            } else {
                print("Failed to add camera input.")
            }
            // Add Video Output
            videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
            if captureSession.canAddOutput(videoOutput) {
                captureSession.addOutput(videoOutput)
                print("Video output added.")
            } else {
                print("Failed to add video output.")
            }
            // Add photo output
                    if captureSession.canAddOutput(photoOutput) {
                        captureSession.addOutput(photoOutput)
                        print("Photo output added to capture session.")
                    } else {
                        print("Unable to add photo output.")
                    }
            // Set Session Preset
            captureSession.sessionPreset = .photo
            print("Session preset set to photo.")
        } catch {
            print("Error setting up camera input: \(error)")
        }
    }

    private func observeSessionRuntimeErrors() {
        NotificationCenter.default.addObserver(
            forName: AVCaptureSession.runtimeErrorNotification,
            object: captureSession,
            queue: .main
        ) { notification in
            guard let error = notification.userInfo?[AVCaptureSessionErrorKey] as? AVError else {
                print("Unknown runtime error occurred.")
                return
            }
            self.handleSessionError(error)
        }
    }

    private func handleSessionError(_ error: AVError) {
        print("Runtime error: \(error.localizedDescription)")

        if !captureSession.isRunning && error.code == .mediaServicesWereReset {
            DispatchQueue.global(qos: .userInitiated).async {
                self.captureSession.startRunning()
                print("Capture session restarted after runtime error.")
            }
        }
    }

    private func checkCameraPermissions(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async { completion(granted) }
            }
        default:
            completion(false)
        }
    }

    func enableTorch(enable: Bool) {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            device.torchMode = enable ? .on : .off
            device.unlockForConfiguration()
        } catch {
            print("Torch could not be used: \(error)")
        }
    }
}

//Photo Capture
private var photoCaptureProcessor: PhotoCaptureProcessor?
extension CameraViewModel {
    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        guard let connection = photoOutput.connection(with: .video), connection.isActive, connection.isEnabled else {
            print("No active and enabled video connection.")
            completion(nil)
            return
        }

        let settings = AVCapturePhotoSettings()
        settings.flashMode = .off

        print("Attempting to capture photo...")

        // Retain the processor until the photo is processed
        let processor = PhotoCaptureProcessor { [weak self] image in
            self?.photoCaptureProcessor = nil // Release after processing
            completion(image)
        }
        photoCaptureProcessor = processor

        photoOutput.capturePhoto(with: settings, delegate: processor)
    }
}

// Helper class to process captured photos
class PhotoCaptureProcessor: NSObject, AVCapturePhotoCaptureDelegate {
    private let completion: (UIImage?) -> Void

    init(completion: @escaping (UIImage?) -> Void) {
        self.completion = completion
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("Error capturing photo: \(error.localizedDescription)")
            completion(nil)
            return
        }

        if let data = photo.fileDataRepresentation(), let image = UIImage(data: data) {
            print("Photo captured successfully!")
            completion(image)
        } else {
            print("Failed to process photo.")
            completion(nil)
        }
    }
}

extension CameraViewModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("Failed to get pixel buffer.")
            return
        }

        // Extract the center color
        let color = getColorFromCenter(of: pixelBuffer)
        DispatchQueue.main.async {
            self.detectedColor = color
        }

        // Object detection
        let orientation = imageOrientationForCurrentDeviceOrientation()
        let request = VNCoreMLRequest(model: objectDetectionModel) { request, error in
            if let error = error {
                print("CoreML request error: \(error)")
                return
            }

            guard let results = request.results as? [VNRecognizedObjectObservation], !results.isEmpty else {
                return
            }

            DispatchQueue.main.async {
                if let firstObject = results.first {
                    let identifier = firstObject.labels.first?.identifier ?? "Unknown"
                    let confidence = Int((firstObject.labels.first?.confidence ?? 0) * 100)
                    self.detectedObject = "\(identifier) (\(confidence)%)"
                    self.detectedObjectwithoutconfidence = "\(identifier)"
                }
            }
        }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
        try? handler.perform([request])
    }

    private func getColorFromCenter(of pixelBuffer: CVPixelBuffer) -> String {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        // Define the area for sampling (10x10 pixels around the center)
        let sampleSize = 10
        let centerX = width / 2 - sampleSize / 2
        let centerY = height / 2 - sampleSize / 2
        let bounds = CGRect(x: centerX, y: centerY, width: sampleSize, height: sampleSize)

        // Create a bitmap buffer large enough to hold the sampled area
        var bitmap = [UInt8](repeating: 0, count: Int(bounds.width * bounds.height * 4)) // RGBA
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        // Render the image to the bitmap buffer
        context.render(ciImage,
                       toBitmap: &bitmap,
                       rowBytes: Int(bounds.width) * 4,
                       bounds: bounds,
                       format: .RGBA8,
                       colorSpace: colorSpace)

        // Calculate the average color from the sampled area
        var totalRed: CGFloat = 0
        var totalGreen: CGFloat = 0
        var totalBlue: CGFloat = 0

        let pixelCount = Int(bounds.width * bounds.height)
        for i in stride(from: 0, to: bitmap.count, by: 4) {
            totalRed += CGFloat(bitmap[i])
            totalGreen += CGFloat(bitmap[i + 1])
            totalBlue += CGFloat(bitmap[i + 2])
        }

        let avgRed = totalRed / CGFloat(pixelCount) / 255.0
        let avgGreen = totalGreen / CGFloat(pixelCount) / 255.0
        let avgBlue = totalBlue / CGFloat(pixelCount) / 255.0

        // Dispatch to update the detected color and return the color name
        DispatchQueue.main.async {
            self.extractedRGB = (avgRed, avgGreen, avgBlue)
        }

        return determineColorName(red: avgRed, green: avgGreen, blue: avgBlue)
    }
    private func hexToRGB(_ hex: String) -> (r: CGFloat, g: CGFloat, b: CGFloat)? {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        if hexSanitized.hasPrefix("#") {
            hexSanitized.remove(at: hexSanitized.startIndex)
        }
        
        guard hexSanitized.count == 6, let hexNumber = Int(hexSanitized, radix: 16) else {
            return nil // Invalid hex input
        }
        
        let red = CGFloat((hexNumber >> 16) & 0xFF) / 255.0
        let green = CGFloat((hexNumber >> 8) & 0xFF) / 255.0
        let blue = CGFloat(hexNumber & 0xFF) / 255.0
        
        return (r: red, g: green, b: blue)
    }

    private func determineColorName(red: CGFloat, green: CGFloat, blue: CGFloat) -> String {
        /// Weighted Euclidean distance calculation
        func calculateDistance(from r: CGFloat, g: CGFloat, b: CGFloat) -> CGFloat {
            let redWeight: CGFloat = 0.3
            let greenWeight: CGFloat = 0.59
            let blueWeight: CGFloat = 0.11
            
            return sqrt(
                redWeight * pow(red - r, 2) +
                greenWeight * pow(green - g, 2) +
                blueWeight * pow(blue - b, 2)
            )
        }
        
        // Color dictionary with hex codes
        let colorDictionary: [(name: String, hex: String)] = [
            // Basic Colors
            ("White", "#FFFFFF"),
            ("Black", "#000000"),
            ("Red", "#FF0000"),
            ("Green", "#00FF00"),
            ("Blue", "#0000FF"),
            ("Yellow", "#FFFF00"),
            ("Cyan", "#00FFFF"),
            ("Magenta", "#FF00FF"),
            
            // Red Shades
            ("Crimson", "#DC143C"),
            ("Firebrick", "#B22222"),
            ("Scarlet", "#FF2400"),
            ("Ruby", "#E0115F"),
            ("Maroon", "#800000"),
            ("Burgundy", "#800020"),
            ("Cherry", "#DE3163"),
            ("Rosewood", "#65000B"),
            ("Coral Red", "#FF4040"),
            ("Indian Red", "#CD5C5C"),
            ("Salmon", "#FA8072"),
            ("Light Coral", "#F08080"),
            
            // Green Shades
            ("Forest Green", "#228B22"),
            ("Lime Green", "#32CD32"),
            ("Olive Green", "#6B8E23"),
            ("Mint Green", "#98FF98"),
            ("Pale Green", "#98FB98"),
            ("Emerald", "#50C878"),
            ("Sea Green", "#2E8B57"),
            ("Jade", "#00A86B"),
            ("Neon Green", "#39FF14"),
            
            // Blue Shades
            ("Sky Blue", "#87CEEB"),
            ("Dodger Blue", "#1E90FF"),
            ("Deep Sky Blue", "#00BFFF"),
            ("Cobalt Blue", "#0047AB"),
            ("Navy", "#000080"),
            ("Steel Blue", "#4682B4"),
            ("Powder Blue", "#B0E0E6"),
            ("Electric Blue", "#7DF9FF"),
            ("Cerulean", "#007BA7"),
            ("Azure", "#007FFF"),
            ("Arctic Blue", "#E0FFFF"),
            
            // Yellow Shades
            ("Light Yellow", "#FFFFE0"),
            ("Lemon", "#FFF44F"),
            ("Goldenrod", "#DAA520"),
            ("Mustard", "#FFDB58"),
            ("Bright Yellow", "#FFEA00"),
            ("Canary Yellow", "#FFEF00"),
            
            // Orange Shades
            ("Orange", "#FFA500"),
            ("Dark Orange", "#FF8C00"),
            ("Peach", "#FFDAB9"),
            ("Coral", "#FF7F50"),
            ("Tangerine", "#F28500"),
            ("Pumpkin", "#FF7518"),
            ("Amber", "#FFBF00"),
            
            // Purple Shades
            ("Purple", "#800080"),
            ("Violet", "#EE82EE"),
            ("Indigo", "#4B0082"),
            ("Lavender", "#E6E6FA"),
            ("Amethyst", "#9966CC"),
            ("Orchid", "#DA70D6"),
            ("Mauve", "#E0B0FF"),
            ("Lilac", "#C8A2C8"),
            ("Plum", "#DDA0DD"),
            ("Deep Purple", "#673AB7"),
            
            // Pink Shades
            ("Pink", "#FFC0CB"),
            ("Hot Pink", "#FF69B4"),
            ("Deep Pink", "#FF1493"),
            ("Bubblegum", "#FF85C1"),
            ("Blush", "#DE5D83"),
            
            // Neutral Shades
            ("Gray", "#808080"),
            ("Light Gray", "#D3D3D3"),
            ("Beige", "#F5F5DC")
        ]
        
        var closestColorName = "Unknown"
        var smallestDistance = CGFloat.infinity

        // Convert each hex color to RGB and calculate distance
        for color in colorDictionary {
            if let rgb = hexToRGB(color.hex) {
                let distance = calculateDistance(from: rgb.r, g: rgb.g, b: rgb.b)
                if distance < smallestDistance {
                    smallestDistance = distance
                    closestColorName = color.name
                }
            }
        }

        // Optional: Threshold for "unclassified" color
        if smallestDistance > 0.4 {
            return "Unclassified Color"
        }

        return closestColorName
    }

    private func imageOrientationForCurrentDeviceOrientation() -> CGImagePropertyOrientation {
        switch UIDevice.current.orientation {
        case .portrait:
            return .right
        case .landscapeRight:
            return .down
        case .landscapeLeft:
            return .up
        case .portraitUpsideDown:
            return .left
        default:
            return .right
        }
    }
}
