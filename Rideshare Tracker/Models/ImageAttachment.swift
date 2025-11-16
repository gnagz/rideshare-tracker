//
//  ImageAttachment.swift
//  Rideshare Tracker
//
//  Created by George Knaggs with Claude AI assistance on 9/10/25.
//

import Foundation
import CoreGraphics

struct ImageAttachment: Codable, Identifiable, Hashable, Equatable {
    let id: UUID
    let filename: String  // Internal filename (UUID-based) - not shown to user
    let dateAttached: Date  // Date when photo was attached to shift/expense
    let type: AttachmentType
    let description: String?

    init(filename: String, type: AttachmentType, description: String? = nil, dateAttached: Date = Date()) {
        self.id = UUID()
        self.filename = filename
        self.dateAttached = dateAttached
        self.type = type
        self.description = description
    }

    // Init that preserves existing ID (for metadata edits)
    init(id: UUID, filename: String, type: AttachmentType, description: String? = nil, dateAttached: Date) {
        self.id = id
        self.filename = filename
        self.dateAttached = dateAttached
        self.type = type
        self.description = description
    }
}

enum AttachmentType: String, Codable, CaseIterable {
    case receipt = "Receipt"
    case screenshot = "App Screenshot"
    case gasPump = "Gas Pump"
    case dashboard = "Dashboard"
    case damage = "Vehicle Damage"
    case cleaning = "Cleaning Required"
    case maintenance = "Maintenance"
    case importedToll = "Imported Toll Summary"
    case importedUberTxns = "Imported Uber Transactions"
    case other = "Other"

    var displayName: String {
        return self.rawValue
    }

    var systemImage: String {
        switch self {
        case .receipt: return "receipt"
        case .screenshot: return "iphone"
        case .gasPump: return "fuelpump"
        case .dashboard: return "gauge.with.dots.needle.bottom.50percent"
        case .damage: return "exclamationmark.triangle"
        case .cleaning: return "drop"
        case .maintenance: return "wrench"
        case .importedToll: return "dollarsign.circle"
        case .importedUberTxns: return "car.fill"
        case .other: return "camera"
        }
    }

    /// Identifies system-generated attachment types that should not be manually edited
    var isSystemGenerated: Bool {
        return self == .importedToll || self == .importedUberTxns
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
