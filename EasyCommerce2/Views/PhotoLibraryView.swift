//
//  PhotoLibraryView.swift
//  EasyCommerce2
//
//  Created by Gabriele Fiore on 09/12/24.
//
import SwiftUI

struct PhotoLibraryView: View {
    @EnvironmentObject var libraryManager: PhotoLibraryManager
    @State private var isSelectionMode = false
    @State private var selectedPhotos: Set<PhotoMetadata> = []

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(libraryManager.photos) { photo in
                        ZStack {
                            VStack {
                                // Photo Thumbnail
                                Image(uiImage: photo.image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 150)
                                    .clipped()
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(selectedPhotos.contains(photo.metadata) ? Color.red : Color.clear, lineWidth: 3)
                                    )
                                    .onTapGesture {
                                        if isSelectionMode {
                                            toggleSelection(for: photo.metadata)
                                        } else {
                                            // Navigate to PhotoDetailView
                                            navigateToDetail(photo: photo)
                                        }
                                    }
                                    .onLongPressGesture {
                                        if !isSelectionMode {
                                            isSelectionMode = true
                                        }
                                        toggleSelection(for: photo.metadata)
                                    }

                                // Photo Metadata
                                Text(photo.metadata.object)
                                    .font(.headline)
                                    .foregroundColor(.primary)

                                Text(photo.metadata.description)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1) // Restrict to two lines
                                    .truncationMode(.tail) // Show ellipsis for overflowing text
                            }

                            // Checkmark for Selected Photos
                            if selectedPhotos.contains(photo.metadata) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(Color.primarycolor)
                                    .padding(5)
                                    .background(Circle().fill(Color.white))
                                    .offset(x: 70, y: -80)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Photo Library")
            .toolbar {
                if isSelectionMode {
                    Button(action: deleteSelectedPhotos) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                }
            }
            .onChange(of: selectedPhotos) { oldValue, newValue in
                if newValue.isEmpty {
                    isSelectionMode = false
                }
            }
        }
    }

    private func toggleSelection(for metadata: PhotoMetadata) {
        if selectedPhotos.contains(metadata) {
            selectedPhotos.remove(metadata)
        } else {
            selectedPhotos.insert(metadata)
        }
    }

    private func deleteSelectedPhotos() {
        guard !selectedPhotos.isEmpty else { return }
        libraryManager.removePhotos(selectedPhotos)
        selectedPhotos.removeAll()
        isSelectionMode = false
    }

    private func navigateToDetail(photo: PhotoItem) {
        guard let index = libraryManager.photos.firstIndex(where: { $0.id == photo.id }) else { return }

        let detailView = PhotoDetailView(photo: $libraryManager.photos[index])
            .environmentObject(libraryManager)
        let hostingController = UIHostingController(rootView: detailView)

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }) {
            keyWindow.rootViewController?.present(hostingController, animated: true, completion: nil)
        }
    }
}
