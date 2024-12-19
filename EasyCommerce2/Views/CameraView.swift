//
//  CameraView.swift
//  EasyCommerce2
//
//  Created by Gabriele Fiore on 08/12/24.
//

import SwiftUI
import AVFoundation
import Vision

struct CameraView: View {
    @ObservedObject var viewModel = CameraViewModel()
    @EnvironmentObject var libraryManager: PhotoLibraryManager
    @Binding var isPresented: Bool // Binding to track presentation state
    @State private var isTorchOn: Bool = false // Track torch state

    var body: some View {
        ZStack {
            // Camera Preview
            CameraPreview(session: viewModel.captureSession)
                .edgesIgnoringSafeArea(.all)

            // Center Circle for Color Detection
            Circle()
                .strokeBorder(Color.white.opacity(0.8), lineWidth: 2)
                .frame(width: 30, height: 30)

            // Bottom Controls
            VStack {
                Spacer()

         
                // Detected Clothing and Color Info
                VStack(spacing: 10) {
                    if let detectedObject = viewModel.detectedObject {
                        Text("Object: \(detectedObject)")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                    Text("Color: \(viewModel.detectedColor)")
                        .font(.title)
                        .foregroundColor(.white)
                }
                .padding()
                .background(
                    Color(
                        red: viewModel.extractedRGB.red,
                        green: viewModel.extractedRGB.green,
                        blue: viewModel.extractedRGB.blue
                    )
                    .opacity(0.8)
                )
                .cornerRadius(10)
                .padding()

                // Take Photo Button with Torch Button
                HStack {
                    Spacer()

                    Button(action: {
                        viewModel.capturePhoto { image in
                            if let image = image {
                                let uniqueID = UUID().uuidString
                                let metadata = PhotoMetadata(
                                    id: uniqueID,
                                    description: viewModel.detectedColor,
                                    object: viewModel.detectedObjectwithoutconfidence ?? "Unknown"
                                )
                                libraryManager.savePhoto(image, metadata: metadata)
                                isPresented = false // Dismiss the view
                            } else {
                                print("Failed to capture photo.")
                            }
                        }
                    }) {
                        Image(systemName: "camera.circle")
                            .resizable()
                            .frame(width: 70, height: 70)
                            .foregroundColor(Color.primarycolor)
                            .padding()
                    }

                    // Torch Button
                    Button(action: toggleTorch) {
                        Image(systemName: isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                            .resizable()
                            .frame(width: 20, height: 20) // Keep dimensions as before
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }

                    Spacer()
                }
                .padding(.horizontal)
            }
        }
        .onAppear {
            viewModel.startSession()
        }
        .onDisappear {
            viewModel.captureSession.stopRunning()
            turnOffTorch()
        }
    }
    private func toggleTorch() {
           guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else {
               print("Torch not available")
               return
           }
           do {
               try device.lockForConfiguration()
               device.torchMode = isTorchOn ? .off : .on
               isTorchOn.toggle()
               device.unlockForConfiguration()
           } catch {
               print("Torch could not be used: \(error.localizedDescription)")
           }
       }

       private func turnOffTorch() {
           guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
           do {
               try device.lockForConfiguration()
               device.torchMode = .off
               device.unlockForConfiguration()
           } catch {
               print("Failed to turn off torch: \(error.localizedDescription)")
           }
       }
   }
// CameraPreview Implementation

struct CameraPreview: UIViewRepresentable {
    var session: AVCaptureSession

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)

        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)

        // Ensure the preview layer frame is updated properly
        DispatchQueue.main.async {
            previewLayer.frame = view.bounds
        }

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        guard let previewLayer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer else {
            print("Failed to retrieve preview layer")
            return
        }

        DispatchQueue.main.async {
            previewLayer.frame = uiView.bounds
        }
    }
}
