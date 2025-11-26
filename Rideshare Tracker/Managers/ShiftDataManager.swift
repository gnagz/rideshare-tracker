//
//  ShiftDataManager.swift
//  Rideshare Tracker
//
//  Created by George Knaggs with Claude AI assistance on 8/10/25.
//

import Foundation

@MainActor
class ShiftDataManager: ObservableObject {
    static let shared = ShiftDataManager()

    @Published var shifts: [RideshareShift] = []
    @Published var lastError: ShiftDataError?

    private let preferencesManager = PreferencesManager.shared
    private var preferences: AppPreferences { preferencesManager.preferences }

    private init() {
        loadShifts()
        migrateImportedTollImages() // One-time migration: convert old toll images to .importedToll type
    }
    
    // MARK: - Error Types

    enum ShiftDataError: LocalizedError {
        case decodingFailed(Error)
        case encodingFailed(Error)
        case userDefaultsUnavailable

        var errorDescription: String? {
            switch self {
            case .decodingFailed(let error):
                return "Failed to load saved shifts: \(error.localizedDescription)"
            case .encodingFailed(let error):
                return "Failed to save shifts: \(error.localizedDescription)"
            case .userDefaultsUnavailable:
                return "Settings storage is unavailable"
            }
        }
    }
    
    // Public initializer for SwiftUI environment object usage
    convenience init(forEnvironment: Bool = false) {
        if forEnvironment {
            self.init()
        } else {
            fatalError("Use ShiftDataManager.shared")
        }
    }
    
    private func loadShifts() {
        debugMessage("=== LOADING SHIFTS FROM USERDEFAULTS ===")
        if let data = UserDefaults.standard.data(forKey: "shifts") {
            debugMessage("Found shifts data in UserDefaults: \(data.count) bytes")
            do {
                shifts = try JSONDecoder().decode([RideshareShift].self, from: data)
                debugMessage("Successfully decoded \(shifts.count) shifts")

                var totalAttachments = 0
                for (index, shift) in shifts.enumerated().prefix(5) {
                    let attachmentCount = shift.imageAttachments.count
                    totalAttachments += attachmentCount
                    debugMessage("  Shift \(index): ID=\(shift.id), attachments=\(attachmentCount)")
                }
                debugMessage("Total attachments loaded: \(totalAttachments)")
            } catch {
                debugMessage("ERROR: Failed to decode shifts from UserDefaults data")
                lastError = .decodingFailed(error)
                // Set lastError for UI observation; do not throw to allow app startup even with corrupted data.
            }
        } else {
            debugMessage("No shifts data found in UserDefaults")
        }
        debugMessage("=== SHIFT LOADING COMPLETE ===")
    }
    
    
    func saveShifts() {
        do {
            let encodedData = try JSONEncoder().encode(shifts)
            UserDefaults.standard.set(encodedData, forKey: "shifts")
        } catch {
            lastError = .encodingFailed(error)
            // Set lastError for UI observation; do not throw to avoid crashing during save operations; no debugMessage to avoid log clutter during frequent saves.
        }
    }

    func addShift(_ shift: RideshareShift) {
        debugMessage("=== ADDING SHIFT ===")
        debugMessage("Shift ID: \(shift.id)")
        debugMessage("Image attachments count: \(shift.imageAttachments.count)")
        for (index, attachment) in shift.imageAttachments.enumerated() {
            debugMessage("  Attachment \(index): \(attachment.filename) (\(attachment.type.rawValue))")
        }

        shifts.append(shift)
        saveShifts()

        debugMessage("Shift added and saved. Total shifts: \(shifts.count)")
        debugMessage("=== SHIFT ADD COMPLETE ===")
    }
    
    func updateShift(_ shift: RideshareShift) {
        debugMessage("=== UPDATING SHIFT ===")
        debugMessage("Shift ID: \(shift.id)")
        debugMessage("Image attachments count: \(shift.imageAttachments.count)")
        for (index, attachment) in shift.imageAttachments.enumerated() {
            debugMessage("  Attachment \(index): \(attachment.filename) (\(attachment.type.rawValue))")
        }

        if let index = shifts.firstIndex(where: { $0.id == shift.id }) {
            shifts[index] = shift
            saveShifts()
            debugMessage("Shift updated and saved at index \(index)")
        } else {
            debugMessage("ERROR: Could not find shift to update")
        }
        debugMessage("=== SHIFT UPDATE COMPLETE ===")
    }
    
    func deleteShift(_ shift: RideshareShift) {
        if preferences.incrementalSyncEnabled {
            // Cloud sync enabled: soft delete for sync propagation
            if let index = shifts.firstIndex(where: { $0.id == shift.id }) {
                shifts[index].isDeleted = true
                shifts[index].modifiedDate = Date()
                saveShifts()
            }
        } else {
            // Cloud sync disabled: permanent delete
            shifts.removeAll { $0.id == shift.id }
            saveShifts()
        }
    }
    
    // Clean up soft-deleted records after successful sync
    func cleanupDeletedShifts() {
        shifts.removeAll { $0.isDeleted }
        saveShifts()
    }
    
    // Permanently delete soft-deleted records when sync is disabled
    func permanentlyDeleteSoftDeletedRecords() {
        let deletedCount = shifts.filter { $0.isDeleted }.count
        if deletedCount > 0 {
            shifts.removeAll { $0.isDeleted }
            saveShifts()
        }
    }
    
    // Filtered access methods (always exclude soft-deleted)
    var activeShifts: [RideshareShift] {
        return shifts.filter { !$0.isDeleted }
    }
    
    func importShifts(_ importedShifts: [RideshareShift], replaceExisting: Bool) {
        debugMessage("ShiftDataManager importShifts: \(importedShifts.count) shifts, replaceExisting=\(replaceExisting)")
        
        if replaceExisting {
            let oldCount = shifts.count
            shifts = importedShifts
            debugMessage("REPLACE: Replaced \(oldCount) existing shifts with \(importedShifts.count) imported shifts")
        } else {
            // Add only new shifts (avoid duplicates by ID)
            let existingIDs = Set(shifts.map { $0.id })
            let newShifts = importedShifts.filter { !existingIDs.contains($0.id) }
            shifts.append(contentsOf: newShifts)
            debugMessage("MERGE: Added \(newShifts.count) new shifts (filtered \(importedShifts.count - newShifts.count) duplicates by ID)")
        }
        
        debugMessage("Final shift count: \(shifts.count) total shifts")
        saveShifts()
    }

    // MARK: - Data Migration

    /// One-time migration: Convert old toll summary images from .receipt to .importedToll type
    /// Identifies toll images by checking if type is .receipt AND description starts with "Toll Summary"
    func migrateImportedTollImages() {
        // Check if migration has already run
        guard !UserDefaults.standard.bool(forKey: "didMigrateTollImages_v1") else {
            debugMessage("Migration already completed, skipping")
            return
        }

        debugMessage("=== STARTING TOLL IMAGE MIGRATION ===")
        var needsSave = false
        var migratedCount = 0

        for i in 0..<shifts.count {
            for j in 0..<shifts[i].imageAttachments.count {
                let attachment = shifts[i].imageAttachments[j]

                // Detect old imported toll images (type: .receipt, description starts with "Toll Summary")
                if attachment.type == .receipt,
                   let description = attachment.description,
                   description.starts(with: "Toll Summary") {

                    // Create migrated attachment with .importedToll type
                    let migratedAttachment = ImageAttachment(
                        filename: attachment.filename,
                        type: .importedToll,
                        description: description
                    )

                    // Replace old attachment with migrated version
                    shifts[i].imageAttachments[j] = migratedAttachment
                    needsSave = true
                    migratedCount += 1

                    debugMessage("Migrated toll image: \(attachment.filename) -> .importedToll")
                }
            }
        }

        if needsSave {
            saveShifts()
            debugMessage("✅ Migration complete: \(migratedCount) toll images migrated to .importedToll type")
        } else {
            debugMessage("No toll images found to migrate")
        }

        // Set flag to prevent re-running migration
        UserDefaults.standard.set(true, forKey: "didMigrateTollImages_v1")
        debugMessage("=== TOLL IMAGE MIGRATION COMPLETE ===")
    }
    

}
