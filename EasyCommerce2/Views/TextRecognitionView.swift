//
//  TextRecognitionView.swift
//  EasyCommerce2
//
//  Created by Gabriele Fiore on 10/12/24.
//

import SwiftUI
import AVFoundation
import Vision

struct TextRecognitionView: View {
    @ObservedObject var viewModel = CameraViewModel()
    @EnvironmentObject var libraryManager: PhotoLibraryManager
    @Binding var isPresented: Bool
    @State private var recognizedText: String = ""
    @State private var capturedImage: UIImage? = nil
    @State private var isShowingPhotoPicker = false
    @State private var selectedPhotoID: String? = nil
    @State private var isTorchOn: Bool = false // Track torch state

    var body: some View {
        ZStack {
            CameraPreview(session: viewModel.captureSession)
                .edgesIgnoringSafeArea(.all)

            VStack {
                Spacer()

                // Torch Button
                Button(action: toggleTorch) {
                    Image(systemName: isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                        .resizable()
                        .frame(width: 30, height: 30)
                        .foregroundColor(.white)
                        .padding(10)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Circle())
                }
                .padding(.bottom, 20)

                if let image = capturedImage, !recognizedText.isEmpty {
                    // Recognized Text Options
                    VStack(spacing: 10) {
                        Text("Recognized Text:")
                            .font(.headline)
                            .foregroundColor(.white)

                        ScrollView {
                            Text(recognizedText)
                                .font(.body)
                                .foregroundColor(.white)
                                .padding()
                        }
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(10)
                        .padding()

                        HStack {
                            Button(action: {
                                isShowingPhotoPicker = true
                            }) {
                                Text("Associate with Clothing Photo")
                                    .fontWeight(.bold)
                                    .padding()
                                    .background(Color.orange)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                            .sheet(isPresented: $isShowingPhotoPicker) {
                                PhotoPickerView(
                                    libraryManager: libraryManager,
                                    selectedPhotoID: $selectedPhotoID
                                ) { selectedPhotoID in
                                    saveTextPhoto(capturedImage!)
                                    isPresented = false
                                }
                            }

                            Button(action: {
                                saveTextPhoto(image)
                                isPresented = false
                                resetView()
                            }) {
                                Text("Save Standalone")
                                    .fontWeight(.bold)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                        }
                        .padding(.horizontal)
                    }
                } else {
                    
                    // Capture Text Button
                    Button(action: {
                        viewModel.capturePhoto { image in
                            if let image = image {
                                capturedImage = image
                                viewModel.recognizeText(from: image) { text in
                                    recognizedText = text
                                }
                            }
                        }
                    }) {
                        Image(systemName: "text.viewfinder")
                            .resizable()
                            .frame(width: 60, height: 60)
                            .foregroundColor(Color.primarycolor)
                            .padding()
                    }
                }
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
    private func saveTextPhoto(_ image: UIImage) {
        let text = recognizedText
        if let photoID = selectedPhotoID, !photoID.isEmpty {
            // Associate with an existing photo
            libraryManager.saveTextPhoto(image, text: text, associatedWith: photoID)
            print("Associated text photo with photo ID: \(photoID)")
        } else {
            // Save as a standalone text photo
            libraryManager.saveTextPhoto(image, text: text)
            print("Saved text photo as standalone.")
        }
        resetView()
    }

    private func resetView() {
        recognizedText = ""
        capturedImage = nil
        selectedPhotoID = nil
        isShowingPhotoPicker = false
    }
}

 
struct PhotoPickerView: View {
    @ObservedObject var libraryManager: PhotoLibraryManager
    @Binding var selectedPhotoID: String?
    var onSelection: (String) -> Void // Closure for handling selection

    var body: some View {
        NavigationView {
            List(libraryManager.photos) { photo in
                HStack {
                    Image(uiImage: photo.image)
                        .resizable()
                        .frame(width: 50, height: 50)
                        .cornerRadius(8)
                    VStack(alignment: .leading) {
                        Text(photo.metadata.object)
                            .font(.headline)
                        Text(photo.metadata.description)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    if selectedPhotoID == photo.id {
                        Image(systemName: "checkmark")
                            .foregroundColor(.blue)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if selectedPhotoID == photo.id {
                   selectedPhotoID = nil // Deselect if tapped again
                    } else {
                        selectedPhotoID = photo.id // Select this photo
                    }
                }
            }
            .navigationTitle("Select Clothing Photo")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        if let selectedPhotoID = selectedPhotoID {
                            print("Selected Photo ID: \(selectedPhotoID)") // Debugging
                            onSelection(selectedPhotoID) // Call the closure
                        }
                    }
                }
            }
        }
    }
}
