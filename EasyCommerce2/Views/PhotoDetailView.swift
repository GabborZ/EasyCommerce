//
//  PhotoDetailView.swift
//  EasyCommerce2
//
//  Created by Gabriele Fiore on 11/12/24.
//

import SwiftUI

struct PhotoDetailView: View {
    @Binding var photo: PhotoItem
    @EnvironmentObject var libraryManager: PhotoLibraryManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var isSelectionMode = false
    @State private var selectedAssociatedPhotos: Set<String> = []
    @State private var generatedDescription: String? = nil
    @State private var isLoading: Bool = false
    @State private var isEditingDescription: Bool = false
    @FocusState private var isTextEditorFocused: Bool // Focus state for the TextEditor
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Main Photo Section
                    VStack {
                        Image(uiImage: photo.image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 300)
                            .cornerRadius(10)
                        
                        Text("\(photo.metadata.object)")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("\(photo.metadata.description)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        // Editable Saved Description
                        if let savedDescription = photo.metadata.generatedDescription, !savedDescription.isEmpty {
                                if isEditingDescription {
                                    ZStack {
                                        TextEditor(text: Binding(
                                            get: { photo.metadata.generatedDescription ?? "" },
                                            set: { photo.metadata.generatedDescription = $0 }
                                        ))
                                        .focused($isTextEditorFocused) // Focus state for the editor
                                        .padding(8)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(8)
                                        .frame(minHeight: 150) // Ensure it’s large enough to avoid scrolling
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.gray)
                                        )
                                    }
                                    .onAppear {
                                        // Focus the TextEditor when edit mode begins
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                            isTextEditorFocused = true
                                        }
                                    }
                                } else {
                                    Text(savedDescription)
                                        .font(.body)
                                        .foregroundColor(.primary)
                                        .padding()
                                        .background(Color(.systemGray6))
                                        .cornerRadius(8)
                                }
                            }
                        }
                    
                    // Generated Description Section
                    if let description = generatedDescription {
                        // Description successfully generated
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Generated Description:")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text(description)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            
                            // Save Description Button
                            Button("Save Description") {
                                saveGeneratedDescription(description)
                                generatedDescription = nil // Clear the generated description to prevent duplication
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color.primarycolor)
                        }
                        .padding(.horizontal)
                    } else if isLoading {
                        // Loading state
                        ProgressView("Generating Description...")
                            .padding()
                    } else {
                        // Initial state - no description and not loading
                        Button("Generate Description") {
                            isLoading = true
                            let geminiManager = GoogleGeminiManager()
                            geminiManager.fetchClothingDescription(for: photo.id, libraryManager: libraryManager) { result in
                                DispatchQueue.main.async {
                                    isLoading = false
                                    switch result {
                                    case .success(let description):
                                        generatedDescription = description
                                    case .failure(let error):
                                        generatedDescription = "Error: \(error.localizedDescription)"
                                    }
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.horizontal)
                        .tint(Color.primarycolor)
                    }
                    
                    
                    Divider()
                    
                    // Associated Photos Section
                    if !photo.associatedPhotos.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Associated Photos:")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                if !selectedAssociatedPhotos.isEmpty {
                                    // Trash Button for Selected Photos
                                    Button(action: deleteSelectedAssociatedPhotos) {
                                        Image(systemName: "trash")
                                            .foregroundColor(.red)
                                            .imageScale(.large)
                                    }
                                }
                            }
                            
                            ForEach(photo.associatedPhotos) { associated in
                                ZStack(alignment: .topTrailing) {
                                    VStack {
                                        if let associatedImage = associated.image {
                                            Image(uiImage: associatedImage)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(maxHeight: 150)
                                                .cornerRadius(8)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .stroke(selectedAssociatedPhotos.contains(associated.id) ? Color.red : Color.clear, lineWidth: 3)
                                                )
                                        }
                                        
                                        Text("Text: \(associated.text)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    if selectedAssociatedPhotos.contains(associated.id) {
                                        // Checkmark for Selected Photos
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(Color.primarycolor)
                                            .padding(5)
                                            .background(Circle().fill(Color.white))
                                    }
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if !selectedAssociatedPhotos.isEmpty {
                                        toggleSelection(for: associated.id)
                                    }
                                }
                                .onLongPressGesture {
                                    if selectedAssociatedPhotos.isEmpty {
                                        toggleSelection(for: associated.id)
                                    }
                                }
                            }
                        }
                    } else {
                        Text("No associated photos.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
            .scrollDisabled(isEditingDescription) // Disable scrolling when editing
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Photo Details")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .tint(Color.primarycolor)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        if isEditingDescription {
                            saveGeneratedDescription(photo.metadata.generatedDescription ?? "")
                        }
                        isEditingDescription.toggle()
                    }) {
                        Image(systemName: isEditingDescription ? "checkmark" : "square.and.pencil")
                    }
                    .tint(Color.primarycolor)
                }
            }
        }
    }
    
    private func toggleSelection(for id: String) {
        if selectedAssociatedPhotos.contains(id) {
            selectedAssociatedPhotos.remove(id)
        } else {
            selectedAssociatedPhotos.insert(id)
        }
    }
    
    private func deleteSelectedAssociatedPhotos() {
        guard !selectedAssociatedPhotos.isEmpty else { return }
        
        // Remove selected associated photos
        photo.associatedPhotos.removeAll { selectedAssociatedPhotos.contains($0.id) }
        
        // Update the photo in the library manager
        if let index = libraryManager.photos.firstIndex(where: { $0.id == photo.id }) {
            libraryManager.photos[index] = photo
            libraryManager.objectWillChange.send() // Notify SwiftUI of the change
            libraryManager.saveMetadata()         // Persist the changes
        }
        
        // Clear selection
        selectedAssociatedPhotos.removeAll()
    }
    
    private func saveGeneratedDescription(_ description: String) {
        photo.metadata.generatedDescription = description
        
        // Update the photo in the library manager
        if let index = libraryManager.photos.firstIndex(where: { $0.id == photo.id }) {
            libraryManager.photos[index] = photo
            libraryManager.objectWillChange.send()
            libraryManager.saveMetadata()
        }
    }
    
    private func calculateDynamicHeight(for text: String) -> CGFloat {
        let font = UIFont.systemFont(ofSize: 17) // Match TextEditor font size
        let textAttributes = [NSAttributedString.Key.font: font]
        let textBoundingRect = text.boundingRect(
            with: CGSize(width: UIScreen.main.bounds.width - 40, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: textAttributes,
            context: nil
        )
        return min(max(150, ceil(textBoundingRect.height) + 32), UIScreen.main.bounds.height * 0.4) // Add padding and cap height
    }
}
