//
//  ImageManager.swift
//  Rideshare Tracker
//
//  Created by George Knaggs with Claude AI assistance on 9/10/25.
//

import Foundation
import UIKit
import SwiftUI

@MainActor
class ImageManager: ObservableObject {
    static let shared = ImageManager()
    
    private let fileManager = FileManager.default
    private let maxImageSize: CGFloat = 2048
    private let thumbnailSize: CGFloat = 150
    private let compressionQuality: CGFloat = 0.8
    
    private init() {}
    
    // MARK: - Directory Management
    
    private var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    private var imagesDirectory: URL {
        documentsDirectory.appendingPathComponent("Images")
    }
    
    private var thumbnailsDirectory: URL {
        documentsDirectory.appendingPathComponent("Thumbnails")
    }
    
    private func parentDirectory(for parentID: UUID, parentType: AttachmentParentType) -> URL {
        imagesDirectory.appendingPathComponent(parentType.rawValue).appendingPathComponent(parentID.uuidString)
    }
    
    private func thumbnailParentDirectory(for parentID: UUID, parentType: AttachmentParentType) -> URL {
        thumbnailsDirectory.appendingPathComponent(parentType.rawValue).appendingPathComponent(parentID.uuidString)
    }
    
    // MARK: - File URLs
    
    func imageURL(for parentID: UUID, parentType: AttachmentParentType, filename: String) -> URL {
        parentDirectory(for: parentID, parentType: parentType).appendingPathComponent(filename)
    }
    
    func thumbnailURL(for parentID: UUID, parentType: AttachmentParentType, filename: String) -> URL {
        thumbnailParentDirectory(for: parentID, parentType: parentType).appendingPathComponent(filename)
    }
    
    // MARK: - Directory Creation
    
    private func createDirectories(for parentID: UUID, parentType: AttachmentParentType) throws {
        let imageDir = parentDirectory(for: parentID, parentType: parentType)
        let thumbnailDir = thumbnailParentDirectory(for: parentID, parentType: parentType)
        
        try fileManager.createDirectory(at: imageDir, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: thumbnailDir, withIntermediateDirectories: true)
    }
    
    // MARK: - Image Processing
    
    private func processImage(_ image: UIImage) -> (fullSize: Data?, thumbnail: Data?) {
        // Resize image if needed
        let processedImage = resizeImage(image, maxSize: maxImageSize)
        let thumbnailImage = resizeImage(image, maxSize: thumbnailSize)
        
        // Convert to JPEG with compression
        let fullSizeData = processedImage.jpegData(compressionQuality: compressionQuality)
        let thumbnailData = thumbnailImage.jpegData(compressionQuality: 0.9) // Higher quality for thumbnails
        
        return (fullSizeData, thumbnailData)
    }
    
    private func resizeImage(_ image: UIImage, maxSize: CGFloat) -> UIImage {
        let size = image.size
        let aspectRatio = size.width / size.height
        
        var newSize: CGSize
        if size.width > size.height {
            newSize = CGSize(width: maxSize, height: maxSize / aspectRatio)
        } else {
            newSize = CGSize(width: maxSize * aspectRatio, height: maxSize)
        }
        
        // Only resize if the image is larger than the target size
        if size.width <= maxSize && size.height <= maxSize {
            return image
        }
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let newImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
        UIGraphicsEndImageContext()
        
        return newImage
    }
    
    // MARK: - Save Image
    
    func saveImage(_ image: UIImage, for parentID: UUID, parentType: AttachmentParentType, type: AttachmentType, description: String? = nil) throws -> ImageAttachment {
        let filename = "\(UUID().uuidString).jpg"

        debugMessage("=== SAVING IMAGE ===")
        debugMessage("Parent ID: \(parentID)")
        debugMessage("Parent Type: \(parentType.rawValue)")
        debugMessage("Filename: \(filename)")
        debugMessage("Type: \(type.rawValue)")
        debugMessage("Description: \(description ?? "nil")")

        // Create directories if needed
        try createDirectories(for: parentID, parentType: parentType)

        // Process image
        let (fullSizeData, thumbnailData) = processImage(image)

        guard let fullSizeData = fullSizeData,
              let thumbnailData = thumbnailData else {
            debugMessage("ERROR: Image processing failed")
            throw ImageManagerError.imageProcessingFailed
        }

        // Save full-size image
        let imageURL = self.imageURL(for: parentID, parentType: parentType, filename: filename)
        try fullSizeData.write(to: imageURL)
        debugMessage("Saved full image: \(imageURL.path)")

        // Save thumbnail
        let thumbnailURL = self.thumbnailURL(for: parentID, parentType: parentType, filename: filename)
        try thumbnailData.write(to: thumbnailURL)
        debugMessage("Saved thumbnail: \(thumbnailURL.path)")

        // Create attachment
        let attachment = ImageAttachment(filename: filename, type: type, description: description)
        debugMessage("Created ImageAttachment: ID=\(attachment.id)")
        debugMessage("=== IMAGE SAVE COMPLETE ===")

        return attachment
    }
    
    // MARK: - Load Images
    
    func loadImage(for parentID: UUID, parentType: AttachmentParentType, filename: String) -> UIImage? {
        let url = imageURL(for: parentID, parentType: parentType, filename: filename)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }
    
    func loadThumbnail(for parentID: UUID, parentType: AttachmentParentType, filename: String) -> UIImage? {
        let url = thumbnailURL(for: parentID, parentType: parentType, filename: filename)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }
    
    // MARK: - Delete Images
    
    func deleteImage(_ attachment: ImageAttachment, for parentID: UUID, parentType: AttachmentParentType) {
        let imageURL = self.imageURL(for: parentID, parentType: parentType, filename: attachment.filename)
        let thumbnailURL = self.thumbnailURL(for: parentID, parentType: parentType, filename: attachment.filename)
        
        try? fileManager.removeItem(at: imageURL)
        try? fileManager.removeItem(at: thumbnailURL)
    }
    
    func deleteAllImages(for parentID: UUID, parentType: AttachmentParentType) {
        let imageDir = parentDirectory(for: parentID, parentType: parentType)
        let thumbnailDir = thumbnailParentDirectory(for: parentID, parentType: parentType)
        
        try? fileManager.removeItem(at: imageDir)
        try? fileManager.removeItem(at: thumbnailDir)
    }
    
    // MARK: - Storage Info

    func calculateStorageUsage() -> (images: Int64, thumbnails: Int64) {
        let imagesDirSize = directorySize(imagesDirectory)
        let thumbnailsDirSize = directorySize(thumbnailsDirectory)
        return (imagesDirSize, thumbnailsDirSize)
    }

    // MARK: - Diagnostics

    func debugImageStorage() {
        debugMessage("=== IMAGE STORAGE DEBUG ===")
        debugMessage("Documents Directory: \(documentsDirectory.path)")
        debugMessage("Images Directory: \(imagesDirectory.path)")
        debugMessage("Thumbnails Directory: \(thumbnailsDirectory.path)")

        debugMessage("Images Directory Exists: \(fileManager.fileExists(atPath: imagesDirectory.path))")
        debugMessage("Thumbnails Directory Exists: \(fileManager.fileExists(atPath: thumbnailsDirectory.path))")

        if fileManager.fileExists(atPath: imagesDirectory.path) {
            if let contents = try? fileManager.contentsOfDirectory(atPath: imagesDirectory.path) {
                debugMessage("Images Directory Contents: \(contents)")
            } else {
                debugMessage("Could not read Images Directory contents")
            }
        }

        if fileManager.fileExists(atPath: thumbnailsDirectory.path) {
            if let contents = try? fileManager.contentsOfDirectory(atPath: thumbnailsDirectory.path) {
                debugMessage("Thumbnails Directory Contents: \(contents)")
            } else {
                debugMessage("Could not read Thumbnails Directory contents")
            }
        }

        let (imagesSize, thumbnailsSize) = calculateStorageUsage()
        debugMessage("Images Storage: \(imagesSize) bytes")
        debugMessage("Thumbnails Storage: \(thumbnailsSize) bytes")
        debugMessage("=== END IMAGE STORAGE DEBUG ===")
    }

    func debugImageAttachment(_ attachment: ImageAttachment, for parentID: UUID, parentType: AttachmentParentType) {
        let imageURL = self.imageURL(for: parentID, parentType: parentType, filename: attachment.filename)
        let thumbnailURL = self.thumbnailURL(for: parentID, parentType: parentType, filename: attachment.filename)

        debugMessage("=== IMAGE ATTACHMENT DEBUG ===")
        debugMessage("Parent ID: \(parentID)")
        debugMessage("Parent Type: \(parentType.rawValue)")
        debugMessage("Filename: \(attachment.filename)")
        debugMessage("Full Image Path: \(imageURL.path)")
        debugMessage("Thumbnail Path: \(thumbnailURL.path)")
        debugMessage("Full Image Exists: \(fileManager.fileExists(atPath: imageURL.path))")
        debugMessage("Thumbnail Exists: \(fileManager.fileExists(atPath: thumbnailURL.path))")

        if fileManager.fileExists(atPath: imageURL.path) {
            if let attributes = try? fileManager.attributesOfItem(atPath: imageURL.path) {
                debugMessage("Full Image Size: \(attributes[.size] ?? "unknown") bytes")
                debugMessage("Full Image Modified: \(attributes[.modificationDate] ?? "unknown")")
            }
        }

        if fileManager.fileExists(atPath: thumbnailURL.path) {
            if let attributes = try? fileManager.attributesOfItem(atPath: thumbnailURL.path) {
                debugMessage("Thumbnail Size: \(attributes[.size] ?? "unknown") bytes")
                debugMessage("Thumbnail Modified: \(attributes[.modificationDate] ?? "unknown")")
            }
        }
        debugMessage("=== END IMAGE ATTACHMENT DEBUG ===")
    }
    
    private func directorySize(_ url: URL) -> Int64 {
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }
        
        var totalSize: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                  let fileSize = resourceValues.fileSize else { continue }
            totalSize += Int64(fileSize)
        }
        
        return totalSize
    }
}

// MARK: - Error Handling

enum ImageManagerError: LocalizedError {
    case imageProcessingFailed
    case directoryCreationFailed
    case fileWriteFailed
    
    var errorDescription: String? {
        switch self {
        case .imageProcessingFailed:
            return "Failed to process image"
        case .directoryCreationFailed:
            return "Failed to create image directory"
        case .fileWriteFailed:
            return "Failed to save image file"
        }
    }
}