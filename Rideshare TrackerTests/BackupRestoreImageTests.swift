//
//  BackupRestoreImageTests.swift
//  Rideshare TrackerTests
//
//  Created by Claude on 11/6/25.
//

import XCTest
import Foundation
import SwiftUI
import UIKit
@testable import Rideshare_Tracker

/// Tests for backup restore with image attachments
/// Verifies ZIP creation, extraction, and selective image restoration
@MainActor
final class BackupRestoreImageTests: RideshareTrackerTestBase {

    // MARK: - Test Helpers

    /// Helper to create clean manager instances for testing
    private func createCleanManagers() -> (ShiftDataManager, ExpenseDataManager, PreferencesManager, BackupRestoreManager, ImageManager) {
        let shiftManager = ShiftDataManager(forEnvironment: true)
        let expenseManager = ExpenseDataManager(forEnvironment: true)

        // Clear any existing data from UserDefaults
        shiftManager.shifts.removeAll()
        expenseManager.expenses.removeAll()

        return (shiftManager, expenseManager, PreferencesManager.shared, BackupRestoreManager.shared, ImageManager.shared)
    }

    /// Creates a test shift with image attachment
    private func createTestShiftWithImage(id: UUID, imageManager: ImageManager) throws -> RideshareShift {
        var shift = RideshareShift(
            startDate: Date(),
            startMileage: 100.0,
            startTankReading: 8.0,
            hasFullTankAtStart: true,
            gasPrice: 2.00,
            standardMileageRate: 0.67
        )
        shift.id = id
        shift.endDate = Date().addingTimeInterval(3600)
        shift.endMileage = 150.0
        shift.endTankReading = 6.0
        shift.netFare = 50.0

        // Create a test image
        let testImage = createTestImage()
        let attachment = try imageManager.saveImage(testImage, for: id, parentType: .shift, type: .receipt, description: "Test Receipt")
        shift.imageAttachments.append(attachment)

        return shift
    }

    /// Creates a simple test image
    private func createTestImage(color: UIColor = .red, size: CGSize = CGSize(width: 100, height: 100)) -> UIImage {
        UIGraphicsBeginImageContext(size)
        color.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let image = UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
        UIGraphicsEndImageContext()
        return image
    }

    /// Checks if image files exist for a shift
    private func imageFilesExist(for shiftID: UUID, filename: String, imageManager: ImageManager) -> Bool {
        let imageURL = imageManager.imageURL(for: shiftID, parentType: .shift, filename: filename)
        let thumbnailURL = imageManager.thumbnailURL(for: shiftID, parentType: .shift, filename: filename)
        return FileManager.default.fileExists(atPath: imageURL.path) &&
               FileManager.default.fileExists(atPath: thumbnailURL.path)
    }

    // MARK: - ZIP Backup Creation Tests

    func testCreateBackupWithImages() async throws {
        let (shiftManager, expenseManager, preferencesManager, backupRestoreManager, imageManager) = createCleanManagers()

        // Given: A shift with an image attachment
        let shiftID = UUID()
        let shift = try createTestShiftWithImage(id: shiftID, imageManager: imageManager)
        shiftManager.addShift(shift)

        XCTAssertEqual(shift.imageAttachments.count, 1, "Shift should have 1 image attachment")
        let imageFilename = shift.imageAttachments[0].filename
        XCTAssertTrue(imageFilesExist(for: shiftID, filename: imageFilename, imageManager: imageManager), "Image files should exist")

        // When: Create backup with images
        let backupURL = try backupRestoreManager.createFullBackup(
            shifts: shiftManager.shifts,
            expenses: expenseManager.expenses,
            preferences: preferencesManager.preferences,
            includeImages: true
        )

        // Then: Backup should be a ZIP file
        XCTAssertEqual(backupURL.pathExtension.lowercased(), "zip", "Backup should be a ZIP file")
        XCTAssertTrue(FileManager.default.fileExists(atPath: backupURL.path), "Backup ZIP should exist")

        // Verify ZIP contains expected structure
        let tempExtractDir = FileManager.default.temporaryDirectory.appendingPathComponent("TestExtract_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempExtractDir, withIntermediateDirectories: true, attributes: nil)
        try FileManager.default.unzipItem(at: backupURL, to: tempExtractDir)

        // ZIP extraction creates a subdirectory with the backup folder name
        let extractedContents = try FileManager.default.contentsOfDirectory(atPath: tempExtractDir.path)
        XCTAssertEqual(extractedContents.count, 1, "Should have exactly one subdirectory")
        let backupDir = tempExtractDir.appendingPathComponent(extractedContents[0])

        let backupJSONExists = FileManager.default.fileExists(atPath: backupDir.appendingPathComponent("backup.json").path)
        XCTAssertTrue(backupJSONExists, "ZIP should contain backup.json")

        let imagesDirExists = FileManager.default.fileExists(atPath: backupDir.appendingPathComponent("Images").path)
        XCTAssertTrue(imagesDirExists, "ZIP should contain Images folder")

        // Clean up
        try FileManager.default.removeItem(at: tempExtractDir)
        try FileManager.default.removeItem(at: backupURL)
    }

    func testCreateBackupWithoutImages() async throws {
        let (shiftManager, expenseManager, preferencesManager, backupRestoreManager, imageManager) = createCleanManagers()

        // Given: A shift with an image attachment
        let shiftID = UUID()
        let shift = try createTestShiftWithImage(id: shiftID, imageManager: imageManager)
        shiftManager.addShift(shift)

        // When: Create backup WITHOUT images
        let backupURL = try backupRestoreManager.createFullBackup(
            shifts: shiftManager.shifts,
            expenses: expenseManager.expenses,
            preferences: preferencesManager.preferences,
            includeImages: false
        )

        // Then: Backup should still be a ZIP (for consistency) but without Images folder
        XCTAssertTrue(FileManager.default.fileExists(atPath: backupURL.path), "Backup should exist")

        // Clean up
        try FileManager.default.removeItem(at: backupURL)
    }

    // MARK: - Image Restoration Tests

    func testRestoreImagesWithReplaceAll() async throws {
        let (shiftManager, expenseManager, preferencesManager, backupRestoreManager, imageManager) = createCleanManagers()

        // Given: Current shift with image
        let currentShiftID = UUID()
        let currentShift = try createTestShiftWithImage(id: currentShiftID, imageManager: imageManager)
        shiftManager.addShift(currentShift)
        let currentImageFilename = currentShift.imageAttachments[0].filename

        XCTAssertTrue(imageFilesExist(for: currentShiftID, filename: currentImageFilename, imageManager: imageManager), "Current image should exist")

        // Create backup with different shift with image
        let backupShiftID = UUID()
        let backupShift = try createTestShiftWithImage(id: backupShiftID, imageManager: imageManager)
        let backupImageFilename = backupShift.imageAttachments[0].filename

        // Create the backup
        let tempShiftManager = ShiftDataManager(forEnvironment: true)
        tempShiftManager.shifts.removeAll()
        tempShiftManager.addShift(backupShift)

        let backupURL = try backupRestoreManager.createFullBackup(
            shifts: tempShiftManager.shifts,
            expenses: [],
            preferences: preferencesManager.preferences,
            includeImages: true
        )

        // When: Restore with replaceAll
        let backupData = try backupRestoreManager.loadBackup(from: backupURL)

        _ = backupRestoreManager.restoreFromBackup(
            backupData: backupData,
            shiftManager: shiftManager,
            expenseManager: expenseManager,
            preferencesManager: preferencesManager,
            action: .replaceAll
        )

        // Then: Current image should be deleted, backup image should exist
        XCTAssertFalse(imageFilesExist(for: currentShiftID, filename: currentImageFilename, imageManager: imageManager), "Current shift image should be deleted")
        XCTAssertTrue(imageFilesExist(for: backupShiftID, filename: backupImageFilename, imageManager: imageManager), "Backup shift image should exist")

        // Clean up
        try FileManager.default.removeItem(at: backupURL)
        imageManager.deleteAllImages(for: backupShiftID, parentType: .shift)
    }

    func testRestoreImagesWithSkipDuplicates() async throws {
        let (shiftManager, expenseManager, preferencesManager, backupRestoreManager, imageManager) = createCleanManagers()

        // Given: Current shift with image
        let sharedShiftID = UUID()
        let currentShift = try createTestShiftWithImage(id: sharedShiftID, imageManager: imageManager)
        shiftManager.addShift(currentShift)
        let currentImageFilename = currentShift.imageAttachments[0].filename

        // Create backup with SAME shift ID (duplicate) plus a new shift
        let newShiftID = UUID()
        let newShift = try createTestShiftWithImage(id: newShiftID, imageManager: imageManager)
        let newImageFilename = newShift.imageAttachments[0].filename

        // Create backup with duplicate shift (has NO images in metadata) + new shift (has images)
        let tempShiftManager = ShiftDataManager(forEnvironment: true)
        tempShiftManager.shifts.removeAll()

        // Create duplicate shift with same ID but no image attachments
        var duplicateShift = RideshareShift(
            startDate: Date(),
            startMileage: 100.0,
            startTankReading: 8.0,
            hasFullTankAtStart: true,
            gasPrice: 2.00,
            standardMileageRate: 0.67
        )
        duplicateShift.id = sharedShiftID
        duplicateShift.imageAttachments = [] // No images in backup for duplicate

        tempShiftManager.addShift(duplicateShift)
        tempShiftManager.addShift(newShift)

        let backupURL = try backupRestoreManager.createFullBackup(
            shifts: tempShiftManager.shifts,
            expenses: [],
            preferences: preferencesManager.preferences,
            includeImages: true
        )

        // When: Restore with skipDuplicates
        let backupData = try backupRestoreManager.loadBackup(from: backupURL)

        _ = backupRestoreManager.restoreFromBackup(
            backupData: backupData,
            shiftManager: shiftManager,
            expenseManager: expenseManager,
            preferencesManager: preferencesManager,
            action: .skipDuplicates
        )

        // Then: Current shift image preserved, new shift image added
        XCTAssertTrue(imageFilesExist(for: sharedShiftID, filename: currentImageFilename, imageManager: imageManager), "Current shift image should be preserved")
        XCTAssertTrue(imageFilesExist(for: newShiftID, filename: newImageFilename, imageManager: imageManager), "New shift image should be added")

        // Clean up
        try FileManager.default.removeItem(at: backupURL)
        imageManager.deleteAllImages(for: sharedShiftID, parentType: .shift)
        imageManager.deleteAllImages(for: newShiftID, parentType: .shift)
    }

    // MARK: - Legacy JSON Backup Compatibility

    func testLoadLegacyJSONBackup() async throws {
        let (_, _, _, backupRestoreManager, _) = createCleanManagers()

        // Given: A legacy JSON backup (no images)
        let legacyBackup = BackupData(
            shifts: [],
            expenses: [],
            uberTransactions: nil,
            preferences: BackupPreferences(
                tankCapacity: 15.0,
                gasPrice: 2.50,
                standardMileageRate: 0.67,
                weekStartDay: 1,
                dateFormat: "MM/dd/yyyy",
                timeFormat: "h:mm a",
                timeZoneIdentifier: "America/New_York",
                tipDeductionEnabled: true,
                effectivePersonalTaxRate: 0.22,
                incrementalSyncEnabled: false,
                syncFrequency: "daily",
                lastIncrementalSyncDate: nil
            ),
            exportDate: Date(),
            appVersion: "1.0"
        )

        let jsonData = try JSONEncoder().encode(legacyBackup)
        let jsonURL = FileManager.default.temporaryDirectory.appendingPathComponent("legacy_backup.json")
        try jsonData.write(to: jsonURL)

        // When: Load legacy JSON backup
        let loadedBackup = try backupRestoreManager.loadBackup(from: jsonURL)

        // Then: Should load successfully
        XCTAssertEqual(loadedBackup.shifts.count, 0, "Should load shifts correctly")
        XCTAssertEqual(loadedBackup.preferences.tankCapacity, 15.0, accuracy: 0.01, "Should load preferences correctly")

        // Clean up
        try FileManager.default.removeItem(at: jsonURL)
    }
}
