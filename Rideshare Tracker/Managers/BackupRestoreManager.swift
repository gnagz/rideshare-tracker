//
//  BackupRestoreManager.swift
//  Rideshare Tracker
//
//  Created by George Knaggs with Claude AI assistance on 10/18/25.
//  Extracted from AppPreferences.swift
//

import Foundation
import SwiftUI

// MARK: - Backup/Restore Error Types

enum BackupRestoreError: LocalizedError {
    case invalidFormat
    case fileReadError
    case fileWriteError
    case encodingFailed(Error)
    case decodingFailed(Error)

    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "Invalid backup file format"
        case .fileReadError:
            return "Unable to read backup file"
        case .fileWriteError:
            return "Unable to write backup file"
        case .encodingFailed(let error):
            return "Failed to encode backup data: \(error.localizedDescription)"
        case .decodingFailed(let error):
            return "Failed to decode backup data: \(error.localizedDescription)"
        }
    }
}

// MARK: - Restore Action Types

enum RestoreAction: String, CaseIterable {
    case replaceAll = "Clear & Restore"
    case skipDuplicates = "Restore Missing"
    case merge = "Merge & Restore"

    var description: String {
        switch self {
        case .replaceAll:
            return "Delete all current data, then restore from backup"
        case .skipDuplicates:
            return "Add only records that don't exist in current data"
        case .merge:
            return "Update existing records and add new ones"
        }
    }
}

// MARK: - Restore Result

struct RestoreResult {
    var shiftsAdded: Int = 0
    var shiftsUpdated: Int = 0
    var shiftsSkipped: Int = 0
    var expensesAdded: Int = 0
    var expensesUpdated: Int = 0
    var expensesSkipped: Int = 0
}

// MARK: - Backup/Restore Manager

@MainActor
class BackupRestoreManager: ObservableObject {
    static let shared = BackupRestoreManager()

    @Published var lastError: BackupRestoreError?

    private init() {}

    // MARK: - Restore from Backup (Full Orchestration)

    func restoreFromBackup(backupData: BackupData, shiftManager: ShiftDataManager, expenseManager: ExpenseDataManager, preferencesManager: PreferencesManager, action: RestoreAction) -> RestoreResult {
        var result = RestoreResult()

        // Capture existing data before restoration (needed for image restoration logic)
        let existingShifts = shiftManager.shifts
        let existingExpenses = expenseManager.expenses

        switch action {
        case .replaceAll:
            // Clear existing data
            shiftManager.shifts.removeAll()
            expenseManager.expenses.removeAll()

            // Restore shifts
            for shift in backupData.shifts {
                shiftManager.addShift(shift)
                result.shiftsAdded += 1
            }

            // Restore expenses
            if let expenses = backupData.expenses {
                for expense in expenses {
                    expenseManager.addExpense(expense)
                    result.expensesAdded += 1
                }
            }

        case .skipDuplicates:
            // Restore shifts, skipping duplicates
            for shift in backupData.shifts {
                if shiftManager.shifts.contains(where: { $0.id == shift.id }) {
                    result.shiftsSkipped += 1
                } else {
                    shiftManager.addShift(shift)
                    result.shiftsAdded += 1
                }
            }

            // Restore expenses, skipping duplicates
            if let expenses = backupData.expenses {
                for expense in expenses {
                    if expenseManager.expenses.contains(where: { $0.id == expense.id }) {
                        result.expensesSkipped += 1
                    } else {
                        expenseManager.addExpense(expense)
                        result.expensesAdded += 1
                    }
                }
            }

        case .merge:
            // Restore shifts, updating existing
            for shift in backupData.shifts {
                if shiftManager.shifts.contains(where: { $0.id == shift.id }) {
                    shiftManager.updateShift(shift)
                    result.shiftsUpdated += 1
                } else {
                    shiftManager.addShift(shift)
                    result.shiftsAdded += 1
                }
            }

            // Restore expenses, updating existing
            if let expenses = backupData.expenses {
                for expense in expenses {
                    if expenseManager.expenses.contains(where: { $0.id == expense.id }) {
                        expenseManager.updateExpense(expense)
                        result.expensesUpdated += 1
                    } else {
                        expenseManager.addExpense(expense)
                        result.expensesAdded += 1
                    }
                }
            }
        }

        // Restore preferences (always)
        preferencesManager.restorePreferences(backupData.preferences)

        // Restore images from backup (if backup contains images)
        restoreImages(
            for: backupData.shifts,
            expenses: backupData.expenses ?? [],
            action: action,
            existingShifts: existingShifts,
            existingExpenses: existingExpenses
        )

        debugMessage("Restore completed: action=\(action), shifts added=\(result.shiftsAdded), updated=\(result.shiftsUpdated), skipped=\(result.shiftsSkipped), expenses added=\(result.expensesAdded), updated=\(result.expensesUpdated), skipped=\(result.expensesSkipped)")
        return result
    }

    // MARK: - Create Backup (ZIP with JSON and Images)

    func createFullBackup(shifts: [RideshareShift], expenses: [ExpenseItem], preferences: AppPreferences, includeImages: Bool = true) throws(BackupRestoreError) -> URL {
        lastError = nil

        let backupData = BackupData(
            shifts: shifts,
            expenses: expenses,
            preferences: BackupPreferences(
                tankCapacity: preferences.tankCapacity,
                gasPrice: preferences.gasPrice,
                standardMileageRate: preferences.standardMileageRate,
                weekStartDay: preferences.weekStartDay,
                dateFormat: preferences.dateFormat,
                timeFormat: preferences.timeFormat,
                timeZoneIdentifier: preferences.timeZoneIdentifier,
                tipDeductionEnabled: preferences.tipDeductionEnabled,
                effectivePersonalTaxRate: preferences.effectivePersonalTaxRate,
                incrementalSyncEnabled: preferences.incrementalSyncEnabled,
                syncFrequency: preferences.syncFrequency,
                lastIncrementalSyncDate: preferences.lastIncrementalSyncDate
            ),
            exportDate: Date(),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        )

        do {
            let timestampFormatter = DateFormatter()
            timestampFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
            let timestamp = timestampFormatter.string(from: Date())

            // Create temp directory for backup contents
            let tempBackupDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("RideshareBackup_\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: tempBackupDir, withIntermediateDirectories: true)

            debugMessage("Creating backup in temp directory: \(tempBackupDir.path)")

            // Write JSON file
            let jsonData = try JSONEncoder().encode(backupData)
            let jsonURL = tempBackupDir.appendingPathComponent("backup.json")
            try jsonData.write(to: jsonURL)
            debugMessage("Wrote backup.json (\(jsonData.count) bytes)")

            // Copy Images and Thumbnails folders if requested
            if includeImages {
                let imageManager = ImageManager.shared
                let imagesDir = imageManager.imagesDirectory
                let thumbnailsDir = imageManager.thumbnailsDirectory
                let destImagesDir = tempBackupDir.appendingPathComponent("Images")
                let destThumbnailsDir = tempBackupDir.appendingPathComponent("Thumbnails")

                // Create destination directories
                try FileManager.default.createDirectory(at: destImagesDir, withIntermediateDirectories: true, attributes: nil)
                try FileManager.default.createDirectory(at: destThumbnailsDir, withIntermediateDirectories: true, attributes: nil)

                var copiedImageCount = 0
                var copiedThumbnailCount = 0

                // Selectively copy images for shifts in backup
                for shift in shifts {
                    let shiftImagesDir = imagesDir.appendingPathComponent("shifts").appendingPathComponent(shift.id.uuidString)
                    let shiftThumbnailsDir = thumbnailsDir.appendingPathComponent("shifts").appendingPathComponent(shift.id.uuidString)

                    if FileManager.default.fileExists(atPath: shiftImagesDir.path) {
                        let destShiftImagesDir = destImagesDir.appendingPathComponent("shifts").appendingPathComponent(shift.id.uuidString)
                        try FileManager.default.createDirectory(at: destShiftImagesDir.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
                        try FileManager.default.copyItem(at: shiftImagesDir, to: destShiftImagesDir)
                        copiedImageCount += 1
                    }

                    if FileManager.default.fileExists(atPath: shiftThumbnailsDir.path) {
                        let destShiftThumbnailsDir = destThumbnailsDir.appendingPathComponent("shifts").appendingPathComponent(shift.id.uuidString)
                        try FileManager.default.createDirectory(at: destShiftThumbnailsDir.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
                        try FileManager.default.copyItem(at: shiftThumbnailsDir, to: destShiftThumbnailsDir)
                        copiedThumbnailCount += 1
                    }
                }

                // Selectively copy images for expenses in backup
                for expense in expenses {
                    let expenseImagesDir = imagesDir.appendingPathComponent("expenses").appendingPathComponent(expense.id.uuidString)
                    let expenseThumbnailsDir = thumbnailsDir.appendingPathComponent("expenses").appendingPathComponent(expense.id.uuidString)

                    if FileManager.default.fileExists(atPath: expenseImagesDir.path) {
                        let destExpenseImagesDir = destImagesDir.appendingPathComponent("expenses").appendingPathComponent(expense.id.uuidString)
                        try FileManager.default.createDirectory(at: destExpenseImagesDir.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
                        try FileManager.default.copyItem(at: expenseImagesDir, to: destExpenseImagesDir)
                        copiedImageCount += 1
                    }

                    if FileManager.default.fileExists(atPath: expenseThumbnailsDir.path) {
                        let destExpenseThumbnailsDir = destThumbnailsDir.appendingPathComponent("expenses").appendingPathComponent(expense.id.uuidString)
                        try FileManager.default.createDirectory(at: destExpenseThumbnailsDir.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
                        try FileManager.default.copyItem(at: expenseThumbnailsDir, to: destExpenseThumbnailsDir)
                        copiedThumbnailCount += 1
                    }
                }

                let imageSize = FileManager.default.directorySize(at: destImagesDir)
                let thumbnailSize = FileManager.default.directorySize(at: destThumbnailsDir)
                debugMessage("Copied \(copiedImageCount) image directories (\(ByteCountFormatter.string(fromByteCount: imageSize, countStyle: .file)))")
                debugMessage("Copied \(copiedThumbnailCount) thumbnail directories (\(ByteCountFormatter.string(fromByteCount: thumbnailSize, countStyle: .file)))")
            }

            // Create ZIP archive
            let zipFilename = "RideshareTracker_Backup_\(timestamp).zip"
            let zipURL = FileManager.default.temporaryDirectory.appendingPathComponent(zipFilename)

            debugMessage("Creating ZIP archive: \(zipFilename)")
            try FileManager.default.zipItem(at: tempBackupDir, to: zipURL)

            let zipSize = try FileManager.default.attributesOfItem(atPath: zipURL.path)[.size] as? Int64 ?? 0
            debugMessage("Created ZIP archive (\(ByteCountFormatter.string(fromByteCount: zipSize, countStyle: .file)))")

            // Clean up temp directory
            try FileManager.default.removeItem(at: tempBackupDir)
            debugMessage("Cleaned up temp directory")

            return zipURL
        } catch let error as EncodingError {
            debugMessage("Error encoding backup data: \(error)")
            lastError = .encodingFailed(error)
            throw .encodingFailed(error)
            // Error handling: Set lastError for UI observation, then throw for caller to handle explicitly
        } catch {
            debugMessage("Error creating backup: \(error)")
            lastError = .fileWriteError
            throw .fileWriteError
            // Error handling: Set lastError for UI observation, then throw for caller to handle explicitly
        }
    }

    // MARK: - Load Backup (ZIP or JSON)

    func loadBackup(from url: URL) throws(BackupRestoreError) -> BackupData {
        lastError = nil
        debugMessage("Starting backup restore from: \(url.lastPathComponent)")

        // Handle security-scoped URLs from document picker
        let hasAccess = url.startAccessingSecurityScopedResource()
        debugMessage("Security-scoped URL access: \(hasAccess)")

        defer {
            if hasAccess {
                url.stopAccessingSecurityScopedResource()
                debugMessage("Released security-scoped URL access")
            }
        }

        do {
            // Check if it's a ZIP file
            let isZip = url.pathExtension.lowercased() == "zip"

            if isZip {
                debugMessage("Detected ZIP backup format")

                // Extract ZIP to temp directory
                let tempExtractDir = FileManager.default.temporaryDirectory
                    .appendingPathComponent("RideshareRestore_\(UUID().uuidString)")

                // Create destination directory first
                try FileManager.default.createDirectory(at: tempExtractDir, withIntermediateDirectories: true, attributes: nil)
                debugMessage("Created temp extraction directory: \(tempExtractDir.path)")

                try FileManager.default.unzipItem(at: url, to: tempExtractDir)
                debugMessage("Extracted ZIP to: \(tempExtractDir.path)")

                // Debug: List contents of extracted directory
                if let contents = try? FileManager.default.contentsOfDirectory(atPath: tempExtractDir.path) {
                    debugMessage("Extracted directory contents: \(contents)")
                } else {
                    debugMessage("ERROR: Could not read extracted directory contents")
                }

                // ZIPFoundation extracts the entire directory structure, so we need to look inside the first subdirectory
                // The ZIP contains: RideshareBackup_XXX/backup.json, RideshareBackup_XXX/Images/, etc.
                let extractedContents = try FileManager.default.contentsOfDirectory(atPath: tempExtractDir.path)
                guard let backupDirName = extractedContents.first else {
                    throw NSError(domain: "BackupRestoreManager", code: 4,
                                 userInfo: [NSLocalizedDescriptionKey: "ZIP extraction resulted in empty directory"])
                }
                let actualBackupDir = tempExtractDir.appendingPathComponent(backupDirName)
                debugMessage("Actual backup directory: \(actualBackupDir.path)")

                // Read backup.json from the actual backup directory
                let jsonURL = actualBackupDir.appendingPathComponent("backup.json")
                let data = try Data(contentsOf: jsonURL)
                let backupData = try JSONDecoder().decode(BackupData.self, from: data)
                debugMessage("Loaded backup.json from ZIP")

                // Store actual backup directory path for later image restoration
                // We'll handle image restoration in restoreFromBackup() based on the action
                lastExtractedBackupDir = actualBackupDir

                return backupData
            } else {
                debugMessage("Detected JSON backup format (legacy)")

                // Legacy JSON backup (no images)
                let data = try Data(contentsOf: url)
                let backupData = try JSONDecoder().decode(BackupData.self, from: data)
                debugMessage("Backup restore completed successfully")

                lastExtractedBackupDir = nil  // No images to restore

                return backupData
            }
        } catch let error as DecodingError {
            debugMessage("ERROR: Backup decoding failed: \(error.localizedDescription)")
            lastError = .decodingFailed(error)
            throw .decodingFailed(error)
            // Error handling: Set lastError for UI observation, then throw for caller to handle explicitly
        } catch {
            debugMessage("ERROR: Backup file read failed: \(error.localizedDescription)")
            lastError = .fileReadError
            throw .fileReadError
            // Error handling: Set lastError for UI observation, then throw for caller to handle explicitly
        }
    }

    // MARK: - Restore Images from Backup

    /// Directory where last backup was extracted (for image restoration)
    private var lastExtractedBackupDir: URL?

    /// Restore images from extracted backup based on restore action
    private func restoreImages(for shifts: [RideshareShift], expenses: [ExpenseItem], action: RestoreAction, existingShifts: [RideshareShift], existingExpenses: [ExpenseItem]) {
        guard let extractedDir = lastExtractedBackupDir else {
            debugMessage("No extracted backup directory, skipping image restoration")
            return
        }

        let backupImagesDir = extractedDir.appendingPathComponent("Images")
        let backupThumbnailsDir = extractedDir.appendingPathComponent("Thumbnails")

        // Only proceed if backup contains images
        guard FileManager.default.fileExists(atPath: backupImagesDir.path) else {
            debugMessage("Backup contains no images, skipping image restoration")
            return
        }

        let imageManager = ImageManager.shared
        let destImagesDir = imageManager.imagesDirectory
        let destThumbnailsDir = imageManager.thumbnailsDirectory

        switch action {
        case .replaceAll:
            // Delete all existing images
            debugMessage("Deleting all existing images (replaceAll)")
            try? FileManager.default.removeItem(at: destImagesDir)
            try? FileManager.default.removeItem(at: destThumbnailsDir)

            // Copy all images from backup
            debugMessage("Copying all images from backup")
            try? FileManager.default.copyItem(at: backupImagesDir, to: destImagesDir)
            if FileManager.default.fileExists(atPath: backupThumbnailsDir.path) {
                try? FileManager.default.copyItem(at: backupThumbnailsDir, to: destThumbnailsDir)
            }

        case .skipDuplicates:
            // Only copy images for newly added shifts/expenses
            debugMessage("Copying images for added items only (skipDuplicates)")
            let addedShiftIDs = Set(shifts.map { $0.id }).subtracting(existingShifts.map { $0.id })
            let addedExpenseIDs = Set(expenses.map { $0.id }).subtracting(existingExpenses.map { $0.id })

            copyImagesForIDs(addedShiftIDs, parentType: .shift, from: backupImagesDir, to: destImagesDir)
            copyImagesForIDs(addedShiftIDs, parentType: .shift, from: backupThumbnailsDir, to: destThumbnailsDir)
            copyImagesForIDs(addedExpenseIDs, parentType: .expense, from: backupImagesDir, to: destImagesDir)
            copyImagesForIDs(addedExpenseIDs, parentType: .expense, from: backupThumbnailsDir, to: destThumbnailsDir)

        case .merge:
            // Copy images for added items AND updated items
            debugMessage("Copying images for added and updated items (merge)")
            let allBackupShiftIDs = Set(shifts.map { $0.id })
            let allBackupExpenseIDs = Set(expenses.map { $0.id })

            // For updated items, delete old images first
            let updatedShiftIDs = allBackupShiftIDs.intersection(existingShifts.map { $0.id })
            let updatedExpenseIDs = allBackupExpenseIDs.intersection(existingExpenses.map { $0.id })

            for shiftID in updatedShiftIDs {
                deleteImagesForID(shiftID, parentType: .shift, from: destImagesDir)
                deleteImagesForID(shiftID, parentType: .shift, from: destThumbnailsDir)
            }
            for expenseID in updatedExpenseIDs {
                deleteImagesForID(expenseID, parentType: .expense, from: destImagesDir)
                deleteImagesForID(expenseID, parentType: .expense, from: destThumbnailsDir)
            }

            // Copy all images for items in backup
            copyImagesForIDs(allBackupShiftIDs, parentType: .shift, from: backupImagesDir, to: destImagesDir)
            copyImagesForIDs(allBackupShiftIDs, parentType: .shift, from: backupThumbnailsDir, to: destThumbnailsDir)
            copyImagesForIDs(allBackupExpenseIDs, parentType: .expense, from: backupImagesDir, to: destImagesDir)
            copyImagesForIDs(allBackupExpenseIDs, parentType: .expense, from: backupThumbnailsDir, to: destThumbnailsDir)
        }

        // Clean up extracted backup directory
        try? FileManager.default.removeItem(at: extractedDir)
        lastExtractedBackupDir = nil
        debugMessage("Cleaned up extracted backup directory")
    }

    private func copyImagesForIDs(_ ids: Set<UUID>, parentType: AttachmentParentType, from sourceDir: URL, to destDir: URL) {
        for id in ids {
            let sourceItemDir = sourceDir.appendingPathComponent(parentType.rawValue).appendingPathComponent(id.uuidString)
            let destItemDir = destDir.appendingPathComponent(parentType.rawValue).appendingPathComponent(id.uuidString)

            if FileManager.default.fileExists(atPath: sourceItemDir.path) {
                // Create parent directories if needed
                try? FileManager.default.createDirectory(at: destItemDir.deletingLastPathComponent(), withIntermediateDirectories: true)

                // Copy the entire folder
                try? FileManager.default.copyItem(at: sourceItemDir, to: destItemDir)
                debugMessage("Copied images for \(parentType.rawValue) \(id)")
            }
        }
    }

    private func deleteImagesForID(_ id: UUID, parentType: AttachmentParentType, from baseDir: URL) {
        let itemDir = baseDir.appendingPathComponent(parentType.rawValue).appendingPathComponent(id.uuidString)
        if FileManager.default.fileExists(atPath: itemDir.path) {
            try? FileManager.default.removeItem(at: itemDir)
            debugMessage("Deleted old images for \(parentType.rawValue) \(id)")
        }
    }
}
