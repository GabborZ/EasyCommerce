//
//  ContentView.swift
//  EasyCommerce2
//
//  Created by Gabriele Fiore on 08/12/24.
//
import SwiftUI
import DotLottie
import SwiftUI

//UI Colors
extension Color {
    static let primarycolor = Color(red: 137 / 255, green: 87 / 255, blue: 244 / 255)
    static let secondarycolor = Color(red: 243 / 255, green: 173 / 255, blue: 122 / 255)
    static let thirdcolor = Color(red: 228 / 255, green: 51 / 255, blue: 141 / 255)
}
struct ContentView: View {
    @EnvironmentObject var libraryManager: PhotoLibraryManager
    @State private var isCameraViewPresented = false
    @State private var isTextRecognitionPresented = false
    
    var body: some View {
        TabView {
            // Camera Tab
            CameraPlaceholderView()
                .tabItem {
                    Image(systemName: "magnifyingglass")
                    Text("Scan")
                }

            // Library Tab
            PhotoLibraryView()
                .tabItem {
                    Image(systemName: "photo.stack")
                    Text("Gallery")
                }
        }
        .tint(Color.primarycolor)
    }
}

struct CameraPlaceholderView: View {
    @State private var isCameraViewPresented = false
    @State private var isTextRecognitionViewPresented = false

    var body: some View {
        ZStack {
            // Animation and Chat Bubble at the Top
            VStack {
                AnimationView()
                    .frame(width: 300, height: 300)
                    .padding(.top, 30) // Adjust animation padding

                //Chat Bubble with Triangle
                                ZStack(alignment: .topTrailing) {
                                    // Chat Bubble
                                    VStack {
                                        Text("Welcome to EasyCommerce, what would you like to scan?")
                                            .font(.system(size: 24, weight: .bold))
                                            .multilineTextAlignment(.center)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 20)
                                            .padding(.vertical, 10)
                                    }
                                    .background(
                                        RoundedRectangle(cornerRadius: 15)
                                            .fill(Color.primarycolor)
                                    )
                                    .padding(.horizontal, 40)
                                    .offset(y: 20) // Lower the bubble slightly

                                    // Triangle (Bubble Tail)
                                    Triangle()
                                        .fill(Color.primarycolor)
                                        .frame(width: 30, height: 60)
                                        .offset(x: -80, y: -65) // Align to top-right of the bubble
                                        .rotationEffect(.degrees(-45), anchor: .topLeading) // Rotates 45 degrees around top-left corner
                                }

                Spacer() // Push everything else down
            }

            // Buttons at the Bottom
            VStack {
                Spacer()

                // Scan Clothing Button
                Button(action: {
                    isCameraViewPresented = true
                }) {
                    Text("Step 1: Scan Clothing")
                        .font(.system(size: 18, weight: .bold))
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal)

                Spacer().frame(height: 20)

                // Text Recognition Button
                Button(action: {
                    isTextRecognitionViewPresented = true
                }) {
                    Text("Step 2: Label Recognition")
                        .font(.system(size: 18, weight: .bold))
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.thirdcolor)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal)

                Spacer().frame(height: 50)
            }
        }
        .sheet(isPresented: $isCameraViewPresented) {
            CameraView(isPresented: $isCameraViewPresented)
        }
        .sheet(isPresented: $isTextRecognitionViewPresented) {
            TextRecognitionView(isPresented: $isTextRecognitionViewPresented)
        }
    }
}

// Triangle Shape
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY)) // Top point of the triangle
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY)) // Bottom-left corner
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY)) // Bottom-right corner
        path.closeSubpath() // Complete the triangle
        return path
    }
}

// Lottie Animation View
struct AnimationView: View {
    var body: some View {
        DotLottieAnimation(
            webURL: "https://lottie.host/d1487400-e785-484a-83d2-fa4a5763e906/ve12RNVVnQ.lottie", config: AnimationConfig(autoplay: true, loop: true)
        ).view()
    }
}
