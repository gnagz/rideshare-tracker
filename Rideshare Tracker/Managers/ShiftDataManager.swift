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
    
    private init() {
        loadShifts()
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
            if let decodedShifts = try? JSONDecoder().decode([RideshareShift].self, from: data) {
                shifts = decodedShifts
                debugMessage("Successfully decoded \(decodedShifts.count) shifts")

                var totalAttachments = 0
                for (index, shift) in decodedShifts.enumerated().prefix(5) {
                    let attachmentCount = shift.imageAttachments.count
                    totalAttachments += attachmentCount
                    debugMessage("  Shift \(index): ID=\(shift.id), attachments=\(attachmentCount)")
                }
                debugMessage("Total attachments loaded: \(totalAttachments)")
            } else {
                debugMessage("ERROR: Failed to decode shifts from UserDefaults data")
            }
        } else {
            debugMessage("No shifts data found in UserDefaults")
        }
        debugMessage("=== SHIFT LOADING COMPLETE ===")
    }
    
    
    func saveShifts() {
        if let encodedData = try? JSONEncoder().encode(shifts) {
            UserDefaults.standard.set(encodedData, forKey: "shifts")
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
        if AppPreferences.shared.incrementalSyncEnabled {
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
}
