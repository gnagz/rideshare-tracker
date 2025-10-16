//
//  ImageAttachment.swift
//  Rideshare Tracker
//
//  Created by George Knaggs with Claude AI assistance on 9/10/25.
//

import Foundation

struct ImageAttachment: Codable, Identifiable, Hashable, Equatable {
    let id: UUID
    let filename: String
    let createdDate: Date
    let type: AttachmentType
    let description: String?
    
    init(filename: String, type: AttachmentType, description: String? = nil) {
        self.id = UUID()
        self.filename = filename
        self.createdDate = Date()
        self.type = type
        self.description = description
    }
    
    // Computed properties for file paths
    @MainActor
    func fileURL(for parentID: UUID, parentType: AttachmentParentType) -> URL {
        return ImageManager.shared.imageURL(for: parentID, parentType: parentType, filename: filename)
    }
    
    @MainActor
    func thumbnailURL(for parentID: UUID, parentType: AttachmentParentType) -> URL {
        return ImageManager.shared.thumbnailURL(for: parentID, parentType: parentType, filename: filename)
    }
}

enum AttachmentType: String, Codable, CaseIterable {
    case receipt = "Receipt"
    case screenshot = "App Screenshot"
    case gasPump = "Gas Station"
    case damage = "Vehicle Damage"
    case cleaning = "Cleaning Required"
    case maintenance = "Maintenance"
    case importedToll = "Imported Toll Summary"
    case other = "Other"

    var displayName: String {
        return self.rawValue
    }

    var systemImage: String {
        switch self {
        case .receipt: return "receipt"
        case .screenshot: return "iphone"
        case .gasPump: return "fuelpump"
        case .damage: return "exclamationmark.triangle"
        case .cleaning: return "drop"
        case .maintenance: return "wrench"
        case .importedToll: return "doc.text.image"
        case .other: return "photo"
        }
    }

    /// Identifies system-generated attachment types that should not be manually edited
    var isSystemGenerated: Bool {
        return self == .importedToll
    }

    /// Custom decoder with fallback for forward compatibility
    /// If an unknown type is decoded (e.g., from newer app version), defaults to .other
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = AttachmentType(rawValue: rawValue) ?? .other
    }
}

enum AttachmentParentType: String, Codable {
    case expense = "expenses"
    case shift = "shifts"
}