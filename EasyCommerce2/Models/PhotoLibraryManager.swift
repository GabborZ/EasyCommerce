//
//  PhotoLibraryManager.swift
//  EasyCommerce2
//
//  Created by Gabriele Fiore on 09/12/24.
//

import SwiftUI

class PhotoLibraryManager: ObservableObject {
    @Published var photos: [PhotoItem] = []

    private let metadataKey = "photoLibraryMetadata" // Key for UserDefaults

    init() {
        loadPhotos() // Load photos and metadata on app startup
    }
    // MARK: - Save Photo
    func savePhoto(_ image: UIImage, metadata: PhotoMetadata) {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            print("Failed to convert image to JPEG.")
            return
        }

        let filePath = getDocumentsDirectory().appendingPathComponent("\(metadata.id).jpg")

        do {
            // Save image to file
            try imageData.write(to: filePath)
            print("Photo saved to file: \(filePath)")

            // Save metadata to the library
            let photo = PhotoItem(id: metadata.id, image: image, metadata: metadata)
            photos.append(photo)

            // Save metadata to UserDefaults
            saveMetadata()
        } catch {
            print("Failed to save photo: \(error)")
        }
    }
    // MARK: - Save Text Photo
    func saveTextPhoto(_ image: UIImage, text: String, associatedWith id: String? = nil) {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            print("Failed to convert image to JPEG.")
            return
        }

        let uniqueID = UUID().uuidString
        let associatedPhoto = AssociatedPhoto(id: uniqueID, imageData: imageData, text: text)

        if let id = id {
            // Associate photo with an existing PhotoItem
            if let index = photos.firstIndex(where: { $0.id == id }) {
                photos[index].associatedPhotos.append(associatedPhoto) // Append associated photo
                saveMetadata() // Save changes to UserDefaults
                print("Photo associated with \(id).")
            }
        } else {
            // Save as a standalone text photo
            let metadata = PhotoMetadata(id: uniqueID, description: text, object: "Detected Text")
            let photoItem = PhotoItem(id: uniqueID, image: image, metadata: metadata, associatedPhotos: [])
            photos.append(photoItem)
            saveMetadata()
            print("Text photo saved independently.")
        }
    }

    // MARK: - Load Photos
    private func loadPhotos() {
        guard let metadataData = UserDefaults.standard.data(forKey: metadataKey),
              let decodedJSON = try? JSONSerialization.jsonObject(with: metadataData, options: []) as? [[String: Any]] else {
            print("No saved metadata found.")
            return
        }

        photos = decodedJSON.compactMap { item in
            guard
                let id = item["id"] as? String,
                let description = item["description"] as? String,
                let object = item["object"] as? String,
                let generatedDescription = item["generatedDescription"] as? String?,
                let associatedPhotosArray = item["associatedPhotos"] as? [[String: Any]]
            else {
                print("Failed to parse photo metadata.")
                return nil
            }

            let associatedPhotos: [AssociatedPhoto] = associatedPhotosArray.compactMap { associatedPhotoDict in
                guard
                    let id = associatedPhotoDict["id"] as? String,
                    let text = associatedPhotoDict["text"] as? String,
                    let imageDataString = associatedPhotoDict["imageData"] as? String,
                    let imageData = Data(base64Encoded: imageDataString)
                else {
                    print("Failed to parse associated photo.")
                    return nil
                }

                return AssociatedPhoto(id: id, imageData: imageData, text: text)
            }

            let filePath = getDocumentsDirectory().appendingPathComponent("\(id).jpg")
            guard let image = UIImage(contentsOfFile: filePath.path) else {
                print("Failed to load image for \(id).")
                return nil
            }

            let metadata = PhotoMetadata(id: id, description: description, object: object, generatedDescription: generatedDescription)
            return PhotoItem(id: id, image: image, metadata: metadata, associatedPhotos: associatedPhotos)
        }

        print("Loaded \(photos.count) photos from storage.")
    }
    
    // MARK: - Save Metadata
     func saveMetadata() {
        let metadata = photos.map { item -> [String: Any] in
            [
                "id": item.id,
                "description": item.metadata.description,
                "object": item.metadata.object,
                "generatedDescription": item.metadata.generatedDescription ?? "", // Save generated description
                "associatedPhotos": item.associatedPhotos.map { associatedPhoto in
                                [
                                    "id": associatedPhoto.id,
                                    "text": associatedPhoto.text,
                                    "imageData": associatedPhoto.imageData.base64EncodedString() // Encode to Base64
                                    ]
                }
            ]
        }

        if let encodedData = try? JSONSerialization.data(withJSONObject: metadata, options: []) {
            UserDefaults.standard.set(encodedData, forKey: metadataKey)
            print("Metadata saved to UserDefaults.")
            objectWillChange.send() // Notify SwiftUI of changes
        } else {
            print("Failed to encode metadata.")
        }
    }
    // MARK: - Remove Associated Photos
    func removeAssociatedPhotos(_ associatedPhotoIDs: Set<String>, from parentPhotoID: String) {
        if let parentIndex = photos.firstIndex(where: { $0.id == parentPhotoID }) {
            _ = photos[parentIndex]

            // Filter out the associated photos to remove
            photos[parentIndex].associatedPhotos.removeAll { associatedPhotoIDs.contains($0.id) }

            // Save updated metadata
            saveMetadata()

            print("Removed associated photos from parent photo \(parentPhotoID).")
        } else {
            print("Parent photo not found for ID \(parentPhotoID).")
        }
    }
    // MARK: - Remove Photos
    func removePhotos(_ photosToRemove: Set<PhotoMetadata>) {
        photosToRemove.forEach { photoMetadata in
            if let index = photos.firstIndex(where: { $0.metadata.id == photoMetadata.id }) {
                // Remove the photo from the array
                photos.remove(at: index)

                // Delete the photo file from disk
                let filePath = getDocumentsDirectory().appendingPathComponent("\(photoMetadata.id).jpg")
                do {
                    try FileManager.default.removeItem(at: filePath)
                    print("Deleted photo file: \(filePath)")
                } catch {
                    print("Failed to delete photo file: \(error)")
                }
            }
        }

        // Save updated metadata
        saveMetadata()
    }
    // MARK: - Helper: Get Documents Directory
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}

// MARK: - Data Models
class PhotoItem: Identifiable {
    let id: String
    let image: UIImage
    var metadata: PhotoMetadata
    var associatedPhotos: [AssociatedPhoto] = [] // New property for associated photos
    init(id: String, image: UIImage, metadata: PhotoMetadata, associatedPhotos: [AssociatedPhoto] = []) {
        self.id = id
        self.image = image
        self.metadata = metadata
        self.associatedPhotos = associatedPhotos
    }
}

struct AssociatedPhoto: Identifiable, Codable {
    let id: String
    let imageData: Data
    let text: String

    var image: UIImage? {
        UIImage(data: imageData)
        
    }
}

struct PhotoMetadata: Identifiable, Codable, Hashable {
    let id: String // Unique identifier
    var description: String
    var object: String
    var generatedDescription: String? // Optional field for generated descriptions
    // Add `Hashable` conformance
    static func == (lhs: PhotoMetadata, rhs: PhotoMetadata) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
