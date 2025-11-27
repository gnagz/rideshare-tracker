//
//  ExpenseItem.swift
//  Rideshare Tracker
//
//  Created by George Knaggs with Claude AI assistance on 8/23/25.
//

import Foundation
import UIKit

enum ExpenseCategory: String, CaseIterable, Codable {
    case vehicle = "Vehicle"
    case equipment = "Equipment" 
    case supplies = "Supplies"
    case amenities = "Amenities"
    
    var systemImage: String {
        switch self {
        case .vehicle: return "car.fill"
        case .equipment: return "duffle.bag.fill"
        case .supplies: return "questionmark.square.fill"
        case .amenities: return "waterbottle.fill"
        }
    }
}

// ⚠️ IMPORTANT: When adding new stored properties to this struct, you MUST also update:
// 1. CodingKeys enum (at bottom of file) - add the property name
// 2. init(from decoder:) - add decoding logic with backward compatibility
// Failure to do so will cause DATA LOSS during backup/restore and cloud sync!
struct ExpenseItem: Codable, Identifiable, Equatable, Hashable {
    var id = UUID()

    // Sync metadata
    var createdDate: Date = Date()
    var modifiedDate: Date = Date()
    var deviceID: String = "unknown"
    var isDeleted: Bool = false
    
    var date: Date
    var category: ExpenseCategory
    var description: String
    var amount: Double
    var imageAttachments: [ImageAttachment] = []
    
    init(date: Date = Date(), category: ExpenseCategory, description: String, amount: Double) {
        self.date = date
        self.category = category
        self.description = description
        self.amount = amount
        self.imageAttachments = []
    }
}

// MARK: - Backward Compatibility for Decoding
extension ExpenseItem {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode required fields
        id = try container.decode(UUID.self, forKey: .id)
        date = try container.decode(Date.self, forKey: .date)
        category = try container.decode(ExpenseCategory.self, forKey: .category)
        description = try container.decode(String.self, forKey: .description)
        amount = try container.decode(Double.self, forKey: .amount)
        
        // Decode sync metadata with backward compatibility
        createdDate = try container.decodeIfPresent(Date.self, forKey: .createdDate) ?? date
        modifiedDate = try container.decodeIfPresent(Date.self, forKey: .modifiedDate) ?? date
        deviceID = try container.decodeIfPresent(String.self, forKey: .deviceID) ?? "unknown"
        isDeleted = try container.decodeIfPresent(Bool.self, forKey: .isDeleted) ?? false
        
        // Decode image attachments with backward compatibility
        imageAttachments = try container.decodeIfPresent([ImageAttachment].self, forKey: .imageAttachments) ?? []
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, createdDate, modifiedDate, deviceID, isDeleted
        case date, category, description, amount, imageAttachments
    }
}