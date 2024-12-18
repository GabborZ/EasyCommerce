//
//  GoogleGeminiManager.swift
//  EasyCommerce2
//
//  Created by Gabriele Fiore on 13/12/24.
//

import Foundation
import GoogleGenerativeAI

class GoogleGeminiManager {
    private let model: GenerativeModel

    init() {
        guard let apiKey = GoogleGeminiManager.fetchAPIKey() else {
            fatalError("API Key not found. Ensure GenerativeAI-Info.plist contains the 'API_KEY'.")
        }
        model = GenerativeModel(name: "gemini-1.5-flash-latest", apiKey: apiKey)
    }

    private static func fetchAPIKey() -> String? {
        guard let path = Bundle.main.path(forResource: "GenerativeAI-Info", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path) as? [String: Any],
              let apiKey = plist["API_KEY"] as? String else {
            return nil
        }
        return apiKey
    }
    /// Fetches clothing descriptions using PhotoLibraryManager data
    func fetchClothingDescription(for photoID: String, libraryManager: PhotoLibraryManager, completion: @escaping (Result<String, Error>) -> Void) {
        guard let photoItem = libraryManager.photos.first(where: { $0.id == photoID }) else {
            completion(.failure(NSError(domain: "GeminiError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Photo not found"])))
            return
        }

        // Extract relevant data
        let color = photoItem.metadata.description // Assuming color is stored in `description`
        let clothingType = photoItem.metadata.object // Type of clothing
        let associatedTexts = photoItem.associatedPhotos.map { $0.text }.joined(separator: "; ")

        let prompt = """
        Describe a \(color) \(clothingType) with the following details: \(associatedTexts.isEmpty ? "No additional details" : associatedTexts).
        """

        Task {
            do {
                // Make the API call
                let response = try await model.generateContent([prompt])

                // Debugging: Print response to inspect structure
                print("Full Response: \(response)")

                // Extract the first candidate's content text
                if let firstCandidate = response.candidates.first {
                    // Access the first part of the content
                    if let textPart = firstCandidate.content.parts.first?.text {
                        completion(.success(textPart))
                    } else {
                        completion(.failure(NSError(domain: "GeminiError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No text in candidate response"])))
                    }
                } else {
                    completion(.failure(NSError(domain: "GeminiError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No candidates in response"])))
                }
            } catch {
                completion(.failure(error)) // Pass the error to the caller
            }
        }
    }
}
