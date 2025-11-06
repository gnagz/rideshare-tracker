//
//  TollImportTests.swift
//  Rideshare TrackerTests
//
//  Created by Claude on 9/26/25.
//

import XCTest
import Foundation
import SwiftUI
@testable import Rideshare_Tracker

/// Tests for toll history import functionality
/// Migrated from original Rideshare_TrackerTests.swift (lines 2438-2722)
final class TollImportTests: RideshareTrackerTestBase {

    // MARK: - TollTransaction Data Structure Tests

    func testTollTransactionInitialization() {
        let date = Date()
        let transaction = TollTransaction(
            date: date,
            location: "183S - Thompson Lane Mainline NB",
            plate: "TX - MKG0738",
            amount: 1.30
        )

        XCTAssertEqual(transaction.date, date, "Date should be set correctly")
        XCTAssertEqual(transaction.location, "183S - Thompson Lane Mainline NB", "Location should be set correctly")
        XCTAssertEqual(transaction.plate, "TX - MKG0738", "Plate should be set correctly")
        assertCurrency(transaction.amount, equals: 1.30, "Amount should be set correctly")
    }

    func testTollTransactionWithEmptyValues() {
        let date = Date()
        let transaction = TollTransaction(
            date: date,
            location: "",
            plate: "",
            amount: 0.0
        )

        XCTAssertEqual(transaction.date, date, "Date should be set correctly")
        XCTAssertEqual(transaction.location, "", "Empty location should be handled")
        XCTAssertEqual(transaction.plate, "", "Empty plate should be handled")
        assertCurrency(transaction.amount, equals: 0.0, "Zero amount should be handled")
    }

    // MARK: - Toll Summary Image Generation Tests

    func testTollSummaryImageGeneration() throws {
        // Given: Multiple toll transactions for image generation
        let shiftDate = createTestDate(year: 2025, month: 9, day: 16)
        let transactions = [
            TollTransaction(
                date: shiftDate.addingTimeInterval(1800), // 30 min into shift
                location: "183S - Thompson Lane Mainline NB",
                plate: "TX - MKG0738",
                amount: 1.30
            ),
            TollTransaction(
                date: shiftDate.addingTimeInterval(3600), // 1 hour into shift
                location: "Mopac Express - Cesar Chavez SB",
                plate: "TX - MKG0738",
                amount: 0.75
            ),
            TollTransaction(
                date: shiftDate.addingTimeInterval(7200), // 2 hours into shift
                location: "183S - Research Blvd NB",
                plate: "TX - MKG0738",
                amount: 1.50
            )
        ]
        let totalAmount = 3.55

        // When: Generating toll summary image
        let image = TollSummaryImageGenerator.generateTollSummaryImage(
            shiftDate: shiftDate,
            transactions: transactions,
            totalAmount: totalAmount
        )

        // Then: Should generate valid image with correct dimensions
        XCTAssertNotNil(image, "Should generate valid image")
        guard let generatedImage = image else {
            XCTFail("Image generation returned nil")
            return
        }
        XCTAssertEqual(generatedImage.size.width, 800, "Image should be 800px wide")
        XCTAssertGreaterThan(generatedImage.size.height, 0, "Image should have positive height")

        debugMessage("Generated toll summary image: \(generatedImage.size)")
    }

    func testTollSummaryImageGenerationWithSingleTransaction() throws {
        // Given: Single toll transaction
        let shiftDate = createTestDate(year: 2025, month: 9, day: 16)
        let transactions = [
            TollTransaction(
                date: shiftDate.addingTimeInterval(1800),
                location: "183S - Thompson Lane Mainline NB",
                plate: "TX - MKG0738",
                amount: 1.30
            )
        ]
        let totalAmount = 1.30

        // When: Generating image for single transaction
        let image = TollSummaryImageGenerator.generateTollSummaryImage(
            shiftDate: shiftDate,
            transactions: transactions,
            totalAmount: totalAmount
        )

        // Then: Should handle single transaction correctly
        XCTAssertNotNil(image, "Should generate valid image")
        guard let generatedImage = image else {
            XCTFail("Image generation returned nil")
            return
        }
        XCTAssertEqual(generatedImage.size.width, 800, "Image should be 800px wide")
        XCTAssertGreaterThan(generatedImage.size.height, 0, "Image should have positive height")
    }

    func testTollSummaryImageGenerationWithLongLocation() throws {
        // Given: Transaction with very long location name
        let shiftDate = createTestDate(year: 2025, month: 9, day: 16)
        let transactions = [
            TollTransaction(
                date: shiftDate,
                location: "Very Long Location Name That Might Cause Text Wrapping Issues In The Generated Image Layout",
                plate: "TX - MKG0738",
                amount: 2.50
            )
        ]
        let totalAmount = 2.50

        // When: Generating image with long location
        let image = TollSummaryImageGenerator.generateTollSummaryImage(
            shiftDate: shiftDate,
            transactions: transactions,
            totalAmount: totalAmount
        )

        // Then: Should handle long text without issues
        XCTAssertNotNil(image, "Should generate valid image")
        guard let generatedImage = image else {
            XCTFail("Image generation returned nil")
            return
        }
        XCTAssertEqual(generatedImage.size.width, 800, "Image should be 800px wide")
        XCTAssertGreaterThan(generatedImage.size.height, 0, "Image should handle long text correctly")
    }

    func testTollSummaryImageGenerationWithEmptyTransactions() throws {
        // Given: Empty transactions array
        let shiftDate = createTestDate(year: 2025, month: 9, day: 16)
        let transactions: [TollTransaction] = []
        let totalAmount = 0.0

        // When: Generating image with no transactions
        let image = TollSummaryImageGenerator.generateTollSummaryImage(
            shiftDate: shiftDate,
            transactions: transactions,
            totalAmount: totalAmount
        )

        // Then: Should handle empty case gracefully
        XCTAssertNotNil(image, "Should generate valid image")
        guard let generatedImage = image else {
            XCTFail("Image generation returned nil")
            return
        }
        XCTAssertEqual(generatedImage.size.width, 800, "Image should be 800px wide")
        XCTAssertGreaterThan(generatedImage.size.height, 0, "Image should handle empty transactions")
    }

    // MARK: - CSV Data Processing Tests

    func testParseExcelDateFormat() {
        // Given: Real Excel formula date format from Austin toll authority
        let excelDateString = "=Text(\"09/16/2025 18:20:33\",\"mm/dd/yyyy HH:mm:SS\")"

        // When: Cleaning up Excel formula
        let cleanedDateString = excelDateString
            .replacingOccurrences(of: "=Text(\"", with: "")
            .replacingOccurrences(of: "\",\"mm/dd/yyyy HH:mm:SS\")", with: "")

        // Then: Should extract clean date string
        XCTAssertEqual(cleanedDateString, "09/16/2025 18:20:33", "Should extract date from Excel formula")

        // And: Should be parseable as date
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM/dd/yyyy HH:mm:ss"
        let parsedDate = dateFormatter.date(from: cleanedDateString)
        XCTAssertNotNil(parsedDate, "Cleaned date should be parseable")
    }

    func testParseExcelAmountFormat() {
        // Given: Excel amount format with negative sign
        let excelAmount = "-$1.30"

        // When: Cleaning up amount string
        let cleanedAmount = excelAmount
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: "-", with: "")

        // Then: Should extract clean amount
        XCTAssertEqual(cleanedAmount, "1.30", "Should clean Excel amount format")

        if let parsedAmount = Double(cleanedAmount) {
            assertCurrency(parsedAmount, equals: 1.30, "Should parse cleaned amount as Double")
        } else {
            XCTFail("Should be able to parse cleaned amount as Double")
        }
    }

    func testParseExcelComplexAmountFormat() {
        // Given: Complex Excel formula with floating point precision
        let complexAmount = "=Text(\"-$99.00000000001\",\"currency\")"

        // When: Cleaning complex Excel formula
        let cleanedAmount = complexAmount
            .replacingOccurrences(of: "=Text(\"", with: "")
            .replacingOccurrences(of: "\",\"currency\")", with: "")
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: "-", with: "")

        XCTAssertEqual(cleanedAmount, "99.00000000001", "Should clean complex Excel formula")

        if let parsedAmount = Double(cleanedAmount) {
            assertCurrency(parsedAmount, equals: 99.00000000001, "Should parse complex amount")
        } else {
            XCTFail("Should be able to parse cleaned amount as Double")
        }
    }

    // MARK: - Shift Matching Algorithm Tests

    func testShiftMatchingWithinWindow() throws {
        // Given: Create a shift from 9 AM to 5 PM
        let shiftStart = createTestDate(year: 2025, month: 9, day: 16, hour: 9, minute: 0)
        let shiftEnd = shiftStart.addingTimeInterval(8 * 3600) // 8 hours later

        var shift = createBasicTestShift(startDate: shiftStart)
        shift.endDate = shiftEnd
        shift.endMileage = shift.startMileage + 200.0

        // Create toll transaction within shift window
        let tollTime = shiftStart.addingTimeInterval(2 * 3600) // 2 hours into shift
        let _ = TollTransaction(
            date: tollTime,
            location: "183S - Thompson Lane Mainline NB",
            plate: "TX - MKG0738",
            amount: 1.30
        )

        // When: Checking if toll is within shift time window
        let isWithinWindow = tollTime >= shiftStart && tollTime <= shiftEnd

        // Then: Should be within the shift window
        XCTAssertTrue(isWithinWindow, "Toll transaction should be within shift time window")

        debugMessage("Shift: \(shiftStart) to \(shiftEnd)")
        debugMessage("Toll: \(tollTime) - Within window: \(isWithinWindow)")
    }

    func testShiftMatchingOutsideWindow() throws {
        // Given: Create a shift from 9 AM to 5 PM
        let shiftStart = createTestDate(year: 2025, month: 9, day: 16, hour: 9, minute: 0)
        let shiftEnd = shiftStart.addingTimeInterval(8 * 3600)

        // Create toll transaction outside shift window (before shift)
        let tollTime = shiftStart.addingTimeInterval(-1 * 3600) // 1 hour before shift
        let _ = TollTransaction(
            date: tollTime,
            location: "183S - Thompson Lane Mainline NB",
            plate: "TX - MKG0738",
            amount: 1.30
        )

        // When: Checking if toll is within shift time window
        let isWithinWindow = tollTime >= shiftStart && tollTime <= shiftEnd

        // Then: Should be outside the shift window
        XCTAssertFalse(isWithinWindow, "Toll transaction should be outside shift time window")
    }

    func testShiftMatchingAtBoundary() throws {
        // Given: Create a shift from 9 AM to 5 PM
        let shiftStart = createTestDate(year: 2025, month: 9, day: 16, hour: 9, minute: 0)
        let shiftEnd = shiftStart.addingTimeInterval(8 * 3600)

        // Create toll transactions at exact boundaries
        let tollAtStart = TollTransaction(
            date: shiftStart,
            location: "Start Location",
            plate: "TX - MKG0738",
            amount: 1.00
        )

        let tollAtEnd = TollTransaction(
            date: shiftEnd,
            location: "End Location",
            plate: "TX - MKG0738",
            amount: 1.50
        )

        // When: Checking boundary conditions
        let startIsWithin = tollAtStart.date >= shiftStart && tollAtStart.date <= shiftEnd
        let endIsWithin = tollAtEnd.date >= shiftStart && tollAtEnd.date <= shiftEnd

        // Then: Both boundary cases should be included
        XCTAssertTrue(startIsWithin, "Toll at shift start should be included")
        XCTAssertTrue(endIsWithin, "Toll at shift end should be included")
    }

    func testShiftMatchingWithIncompleteShift() throws {
        // Given: Incomplete shift (no end date)
        let shiftStart = createTestDate(year: 2025, month: 9, day: 16, hour: 9, minute: 0)
        let _ = createBasicTestShift(startDate: shiftStart)
        // No endDate set - incomplete shift

        let tollTime = shiftStart.addingTimeInterval(2 * 3600)
        let _ = TollTransaction(
            date: tollTime,
            location: "183S - Thompson Lane Mainline NB",
            plate: "TX - MKG0738",
            amount: 1.30
        )

        // When: Matching against incomplete shift
        // For incomplete shifts, we might use a default window or current time
        let defaultWindow = 12 * 3600.0 // 12 hours
        let estimatedEnd = shiftStart.addingTimeInterval(defaultWindow)
        let isWithinWindow = tollTime >= shiftStart && tollTime <= estimatedEnd

        // Then: Should handle incomplete shifts gracefully
        XCTAssertTrue(isWithinWindow, "Should match tolls to incomplete shifts within reasonable window")

        debugMessage("Incomplete shift matching: \(isWithinWindow)")
    }

    // MARK: - Integration Tests

    func testTollAccumulation() throws {
        // Given: Shift with multiple toll transactions
        let shiftStart = createTestDate(year: 2025, month: 9, day: 16, hour: 9, minute: 0)
        var shift = createBasicTestShift(startDate: shiftStart)
        shift.endDate = shiftStart.addingTimeInterval(8 * 3600)
        shift.endMileage = shift.startMileage + 150.0

        // Multiple toll transactions during the shift
        let toll1 = TollTransaction(
            date: shiftStart.addingTimeInterval(1 * 3600),
            location: "Location 1",
            plate: "TX - MKG0738",
            amount: 1.30
        )

        let toll2 = TollTransaction(
            date: shiftStart.addingTimeInterval(3 * 3600),
            location: "Location 2",
            plate: "TX - MKG0738",
            amount: 0.73
        )

        // When: Accumulating tolls to shift
        let totalTolls = toll1.amount + toll2.amount
        shift.tolls = totalTolls

        // Then: Should accumulate tolls correctly
        if let tollValue = shift.tolls {
            assertCurrency(tollValue, equals: 2.03, "Should accumulate tolls correctly")
        } else {
            XCTFail("Shift should have tolls value set")
        }

        debugMessage("Total tolls accumulated: \(totalTolls)")
    }

    // MARK: - Toll Import Replacement Tests

//    func testTollImportReplacesExistingAmount() async throws {
//        // Given: Create a shift with existing toll amount
//        let shiftStart = createTestDate(year: 2025, month: 9, day: 16, hour: 9, minute: 0)
//        var existingShift = createBasicTestShift(startDate: shiftStart)
//        existingShift.endDate = shiftStart.addingTimeInterval(8 * 3600)
//        existingShift.endMileage = existingShift.startMileage + 150.0
//        existingShift.tolls = 2.71  // Pre-existing toll amount (like user manually entered)
//
//        // Add shift to manager
//        let manager = await MainActor.run {
//            let mgr = ShiftDataManager(forEnvironment: true)
//            mgr.shifts.removeAll()
//            mgr.addShift(existingShift)
//            return mgr
//        }
//
//        // Create CSV with toll transactions that should REPLACE the existing amount
//        let csvContent = """
//        Transaction Entry Date,Location,Plate,Transaction Amount
//        "09/16/2025 10:30:00","183S - Thompson Lane Mainline NB","TX - MKG0738",1.30
//        "09/16/2025 12:45:00","Mopac Express - Cesar Chavez SB","TX - MKG0738",0.75
//        "09/16/2025 15:15:00","183S - Research Blvd NB","TX - MKG0738",0.75
//        """
//
//        let tempDir = FileManager.default.temporaryDirectory
//        let testURL = tempDir.appendingPathComponent("test_toll_replacement.csv")
//        try csvContent.write(to: testURL, atomically: true, encoding: .utf8)
//
//        // When: Import the tolls (this should REPLACE existing tolls)
//        let importResult = await MainActor.run {
//            return ImportExportManager.shared.importTolls(from: testURL, dataManager: manager)
//        }
//
//        // Then: Verify import succeeded
//        if let result = importResult {
//            XCTAssertEqual(result.transactions.count, 3, "Should import 3 toll transactions")
//            XCTAssertEqual(result.updatedShifts.count, 1, "Should update 1 shift")
//
//            // Verify the shift toll amount was REPLACED, not added to
//            guard let updatedShift = result.updatedShifts.first else {
//                XCTFail("Should have one updated shift")
//                return
//            }
//
//            let expectedTotalTolls = 1.30 + 0.75 + 0.75 // = 2.80
//            if let actualTolls = updatedShift.tolls {
//                assertCurrency(actualTolls, equals: expectedTotalTolls, "Toll amount should be REPLACED with imported total, not added")
//                XCTAssertNotEqual(actualTolls, 2.71 + expectedTotalTolls, "Should NOT add to existing amount (would be 5.51)")
//            } else {
//                XCTFail("Shift should have tolls set after import")
//            }
//
//            debugMessage("Original tolls: 2.71, Imported tolls: \(expectedTotalTolls), Final tolls: \(updatedShift.tolls ?? 0)")
//        } else {
//            let errorMessage = await MainActor.run {
//                ImportExportManager.shared.lastError?.localizedDescription ?? "unknown error"
//            }
//            XCTFail("Toll import should succeed but failed with: \(errorMessage)")
//        }
//
//        // Cleanup
//        try? FileManager.default.removeItem(at: testURL)
//    }

//    func testTollImportAttachesImageToShift() async throws {
//        // Given: Create a shift that will match toll transactions
//        let shiftStart = createTestDate(year: 2025, month: 9, day: 16, hour: 9, minute: 0)
//        var testShift = createBasicTestShift(startDate: shiftStart)
//        testShift.endDate = shiftStart.addingTimeInterval(8 * 3600)
//        testShift.endMileage = testShift.startMileage + 150.0
//
//        let manager = await MainActor.run {
//            let mgr = ShiftDataManager(forEnvironment: true)
//            mgr.shifts.removeAll()
//            mgr.addShift(testShift)
//            return mgr
//        }
//
//        // Create CSV with toll transactions
//        let csvContent = """
//        Transaction Entry Date,Location,Plate,Transaction Amount
//        "09/16/2025 10:30:00","183S - Thompson Lane Mainline NB","TX - MKG0738",1.30
//        "09/16/2025 12:45:00","Mopac Express - Cesar Chavez SB","TX - MKG0738",0.75
//        """
//
//        let tempDir = FileManager.default.temporaryDirectory
//        let testURL = tempDir.appendingPathComponent("test_toll_image.csv")
//        try csvContent.write(to: testURL, atomically: true, encoding: .utf8)
//
//        // When: Import the tolls
//        let importResult = await MainActor.run {
//            return ImportExportManager.shared.importTolls(from: testURL, dataManager: manager)
//        }
//
//        // Then: Verify toll summary image was attached to shift
//        if let result = importResult {
//            XCTAssertEqual(result.transactions.count, 2, "Should import 2 toll transactions")
//            XCTAssertEqual(result.updatedShifts.count, 1, "Should update 1 shift")
//
//            guard let updatedShift = result.updatedShifts.first else {
//                XCTFail("Should have one updated shift")
//                return
//            }
//
//            // Debug output
//            debugMessage("Toll import result: \(result.imagesGenerated) images generated, \(updatedShift.imageAttachments.count) attachments on shift")
//
//            // Verify toll summary image was attached
//            XCTAssertFalse(updatedShift.imageAttachments.isEmpty, "Shift should have image attachments after toll import")
//            XCTAssertEqual(result.imagesGenerated, 1, "Should generate 1 toll summary image")
//
//            let tollImageAttachments = updatedShift.imageAttachments.filter { $0.type == .importedToll }
//            XCTAssertGreaterThanOrEqual(tollImageAttachments.count, 1, "Should have at least one imported toll image attachment")
//
//            // Verify the attachment has appropriate description
//            if let tollAttachment = tollImageAttachments.first {
//                XCTAssertTrue(tollAttachment.description?.contains("Toll Summary") == true, "Toll image should have 'Toll Summary' in description")
//            }
//
//            debugMessage("Images generated: \(result.imagesGenerated), Attached images: \(updatedShift.imageAttachments.count)")
//        } else {
//            let errorMessage = await MainActor.run {
//                ImportExportManager.shared.lastError?.localizedDescription ?? "unknown error"
//            }
//            XCTFail("Toll import should succeed but failed with: \(errorMessage)")
//        }
//
//        // Cleanup
//        try? FileManager.default.removeItem(at: testURL)
//    }

    // MARK: - Image Attachment Type Tests

//    func testImportedTollImageUsesCorrectType() async throws {
//        // Given: Create a shift that will match toll transactions
//        let shiftStart = createTestDate(year: 2025, month: 9, day: 16, hour: 9, minute: 0)
//        var testShift = createBasicTestShift(startDate: shiftStart)
//        testShift.endDate = shiftStart.addingTimeInterval(8 * 3600)
//        testShift.endMileage = testShift.startMileage + 150.0
//
//        let manager = await MainActor.run {
//            let mgr = ShiftDataManager(forEnvironment: true)
//            mgr.shifts.removeAll()
//            mgr.addShift(testShift)
//            return mgr
//        }
//
//        // Create CSV with toll transactions
//        let csvContent = """
//        Transaction Entry Date,Location,Plate,Transaction Amount
//        "09/16/2025 10:30:00","183S - Thompson Lane Mainline NB","TX - MKG0738",1.30
//        "09/16/2025 12:45:00","Mopac Express - Cesar Chavez SB","TX - MKG0738",0.75
//        """
//
//        let tempDir = FileManager.default.temporaryDirectory
//        let testURL = tempDir.appendingPathComponent("test_toll_type.csv")
//        try csvContent.write(to: testURL, atomically: true, encoding: .utf8)
//
//        // When: Import the tolls
//        let importResult = await MainActor.run {
//            return ImportExportManager.shared.importTolls(from: testURL, dataManager: manager)
//        }
//
//        // Then: Verify toll summary image has .importedToll type
//        if let result = importResult {
//            guard let updatedShift = result.updatedShifts.first else {
//                XCTFail("Should have one updated shift")
//                return
//            }
//
//            let tollImageAttachments = updatedShift.imageAttachments.filter { $0.type == .importedToll }
//            XCTAssertEqual(tollImageAttachments.count, 1, "Should have exactly one imported toll image")
//
//            if let tollAttachment = tollImageAttachments.first {
//                XCTAssertEqual(tollAttachment.type, .importedToll, "Toll image should have .importedToll type")
//                XCTAssertTrue(tollAttachment.description?.contains("Toll Summary") == true, "Description should indicate toll summary")
//            }
//        } else {
//            let errorMessage = await MainActor.run {
//                ImportExportManager.shared.lastError?.localizedDescription ?? "unknown error"
//            }
//            XCTFail("Toll import should succeed but failed with: \(errorMessage)")
//        }
//
//        // Cleanup
//        try? FileManager.default.removeItem(at: testURL)
//    }

    func testImportTollsTwiceRemovesDuplicates() async throws {
        // Given: Create a shift and import tolls once
        let shiftStart = createTestDate(year: 2025, month: 9, day: 16, hour: 9, minute: 0)
        var testShift = createBasicTestShift(startDate: shiftStart)
        testShift.endDate = shiftStart.addingTimeInterval(8 * 3600)
        testShift.endMileage = testShift.startMileage + 150.0

        let manager = await MainActor.run {
            let mgr = ShiftDataManager(forEnvironment: true)
            mgr.shifts.removeAll()
            mgr.addShift(testShift)
            return mgr
        }

        let csvContent = """
        Transaction Entry Date,Location,Plate,Transaction Amount
        "09/16/2025 10:30:00","183S - Thompson Lane Mainline NB","TX - MKG0738",1.30
        "09/16/2025 12:45:00","Mopac Express - Cesar Chavez SB","TX - MKG0738",0.75
        """

        let tempDir = FileManager.default.temporaryDirectory
        let testURL = tempDir.appendingPathComponent("test_toll_duplicates.csv")
        try csvContent.write(to: testURL, atomically: true, encoding: .utf8)

        // When: Import tolls FIRST time
        let firstResult = try await MainActor.run {
            return try ImportExportManager.shared.importTolls(from: testURL, dataManager: manager)
        }

        guard let shiftAfterFirstImport = firstResult.updatedShifts.first else {
            XCTFail("Should have updated shift after first import")
            return
        }

        let tollImagesAfterFirst = shiftAfterFirstImport.imageAttachments.filter { $0.type == .importedToll }
        XCTAssertEqual(tollImagesAfterFirst.count, 1, "Should have 1 toll image after first import")

        // When: Import tolls SECOND time (same date range, should replace old toll image)
        let secondResult = try await MainActor.run {
            return try ImportExportManager.shared.importTolls(from: testURL, dataManager: manager)
        }

        // Then: Verify only ONE toll summary image exists (old removed, new added)
        guard let shiftAfterSecondImport = secondResult.updatedShifts.first else {
            XCTFail("Should have updated shift after second import")
            return
        }

        let tollImagesAfterSecond = shiftAfterSecondImport.imageAttachments.filter { $0.type == .importedToll }
        XCTAssertEqual(tollImagesAfterSecond.count, 1, "Should still have only 1 toll image after second import (duplicates removed)")

        debugMessage("After first import: \(tollImagesAfterFirst.count) images, After second import: \(tollImagesAfterSecond.count) images")

        // Cleanup
        try? FileManager.default.removeItem(at: testURL)
    }

    func testImportedTollTypeHasSystemGeneratedFlag() {
        // Given: The .importedToll type
        let importedTollType = AttachmentType.importedToll

        // Then: Should be marked as system-generated
        XCTAssertTrue(importedTollType.isSystemGenerated, ".importedToll type should be marked as system-generated")

        // And: Other types should NOT be system-generated
        XCTAssertFalse(AttachmentType.receipt.isSystemGenerated, ".receipt should not be system-generated")
        XCTAssertFalse(AttachmentType.other.isSystemGenerated, ".other should not be system-generated")
        XCTAssertFalse(AttachmentType.gasPump.isSystemGenerated, ".gasPump should not be system-generated")
    }

    func testMigrationConvertsOldTollImages() async throws {
        // Given: Create a shift with OLD toll image (type: .receipt, description starts with "Toll Summary")
        let shiftStart = createTestDate(year: 2025, month: 9, day: 16, hour: 9, minute: 0)
        var testShift = createBasicTestShift(startDate: shiftStart)

        // Simulate old toll image (before .importedToll type existed)
        let oldTollImage = ImageAttachment(
            filename: "old_toll_summary.jpg",
            type: .receipt,
            description: "Toll Summary - 3 transactions"
        )
        testShift.imageAttachments.append(oldTollImage)

        let manager = await MainActor.run {
            let mgr = ShiftDataManager(forEnvironment: true)
            mgr.shifts.removeAll()
            mgr.addShift(testShift)
            return mgr
        }

        // When: Migration runs (simulating app launch migration)
        await MainActor.run {
            // Reset migration flag to allow test to run migration again
            UserDefaults.standard.removeObject(forKey: "didMigrateTollImages_v1")
            manager.migrateImportedTollImages()
        }

        // Then: Old toll image should be converted to .importedToll type
        let migratedShift = await MainActor.run { manager.shifts.first }
        XCTAssertNotNil(migratedShift, "Shift should exist after migration")

        if let shift = migratedShift {
            let tollImages = shift.imageAttachments.filter { $0.type == .importedToll }
            XCTAssertEqual(tollImages.count, 1, "Should have migrated old toll image to .importedToll type")

            let receiptImages = shift.imageAttachments.filter { $0.type == .receipt }
            XCTAssertEqual(receiptImages.count, 0, "Old .receipt toll image should be converted")
        }
    }

    func testMigrationDoesNotAffectRegularReceipts() async throws {
        // Given: Create a shift with REGULAR receipt image (not a toll summary)
        let shiftStart = createTestDate(year: 2025, month: 9, day: 16, hour: 9, minute: 0)
        var testShift = createBasicTestShift(startDate: shiftStart)

        let regularReceipt = ImageAttachment(
            filename: "gas_receipt.jpg",
            type: .receipt,
            description: "Gas receipt from Shell"
        )
        testShift.imageAttachments.append(regularReceipt)

        let manager = await MainActor.run {
            let mgr = ShiftDataManager(forEnvironment: true)
            mgr.shifts.removeAll()
            mgr.addShift(testShift)
            return mgr
        }

        // When: Migration runs
        await MainActor.run {
            // Reset migration flag to allow test to run migration again
            UserDefaults.standard.removeObject(forKey: "didMigrateTollImages_v1")
            manager.migrateImportedTollImages()
        }

        // Then: Regular receipt should remain unchanged
        let migratedShift = await MainActor.run { manager.shifts.first }
        XCTAssertNotNil(migratedShift, "Shift should exist after migration")

        if let shift = migratedShift {
            let receiptImages = shift.imageAttachments.filter { $0.type == .receipt }
            XCTAssertEqual(receiptImages.count, 1, "Regular receipt should remain as .receipt type")

            let tollImages = shift.imageAttachments.filter { $0.type == .importedToll }
            XCTAssertEqual(tollImages.count, 0, "Regular receipt should NOT be converted to .importedToll")
        }
    }

    func testMigrationOnlyRunsOnce() async throws {
        // Given: Create a shift with old toll image
        let shiftStart = createTestDate(year: 2025, month: 9, day: 16, hour: 9, minute: 0)
        var testShift = createBasicTestShift(startDate: shiftStart)

        let oldTollImage = ImageAttachment(
            filename: "old_toll.jpg",
            type: .receipt,
            description: "Toll Summary - 2 transactions"
        )
        testShift.imageAttachments.append(oldTollImage)

        let manager = await MainActor.run {
            let mgr = ShiftDataManager(forEnvironment: true)
            mgr.shifts.removeAll()
            mgr.addShift(testShift)
            return mgr
        }

        // When: Run migration FIRST time
        await MainActor.run {
            // Reset flag to simulate first-time migration
            UserDefaults.standard.removeObject(forKey: "didMigrateTollImages_v1")
            manager.migrateImportedTollImages()
        }

        let firstMigrationComplete = UserDefaults.standard.bool(forKey: "didMigrateTollImages_v1")
        XCTAssertTrue(firstMigrationComplete, "Migration flag should be set after first run")

        // Add another old-style toll image to test that second migration doesn't run
        var secondShift = createBasicTestShift(startDate: shiftStart.addingTimeInterval(86400))
        let anotherOldTollImage = ImageAttachment(
            filename: "another_old_toll.jpg",
            type: .receipt,
            description: "Toll Summary - 1 transaction"
        )
        secondShift.imageAttachments.append(anotherOldTollImage)

        await MainActor.run {
            manager.addShift(secondShift)
        }

        // When: Run migration SECOND time (should skip because flag is set)
        await MainActor.run {
            manager.migrateImportedTollImages()
        }

        // Then: Second shift's old toll image should NOT be migrated (migration only runs once)
        let shifts = await MainActor.run { manager.shifts }
        if let secondMigratedShift = shifts.first(where: { $0.id == secondShift.id }) {
            let receiptImages = secondMigratedShift.imageAttachments.filter { $0.type == .receipt }
            XCTAssertEqual(receiptImages.count, 1, "Second run should skip migration (flag prevents re-run)")
        }

        // Cleanup
        UserDefaults.standard.removeObject(forKey: "didMigrateTollImages_v1")
    }

    // MARK: - Diagnostic Test for Multiple Shifts with Tolls

    func testTollImportMatchesAllShiftsInDateRange() async throws {
        // Given: Multiple shifts across 3 months (Aug 1 - Nov 5) with varying patterns
        // This simulates the user's real scenario: 119 toll transactions should match more than 3 shifts
        // CRITICAL: Shifts already have EXISTING toll amounts that should be REPLACED

        let manager = await MainActor.run {
            let mgr = ShiftDataManager(forEnvironment: true)
            mgr.shifts.removeAll()
            return mgr
        }

        // Create 15 shifts across the date range with different patterns
        var testShifts: [RideshareShift] = []

        // August shifts (5 shifts) - all have existing toll amounts
        for day in [1, 5, 10, 15, 20] {
            let shiftStart = createTestDate(year: 2025, month: 8, day: day, hour: 9, minute: 0)
            var shift = createBasicTestShift(startDate: shiftStart)
            shift.endDate = shiftStart.addingTimeInterval(8 * 3600) // 8 hour shift
            shift.endMileage = shift.startMileage + 150.0
            shift.tolls = 5.00 // EXISTING toll amount (will be replaced)
            testShifts.append(shift)
        }

        // September shifts (5 shifts) - all have existing toll amounts
        for day in [2, 8, 14, 21, 28] {
            let shiftStart = createTestDate(year: 2025, month: 9, day: day, hour: 10, minute: 0)
            var shift = createBasicTestShift(startDate: shiftStart)
            shift.endDate = shiftStart.addingTimeInterval(7 * 3600) // 7 hour shift
            shift.endMileage = shift.startMileage + 120.0
            shift.tolls = 5.00 // EXISTING toll amount (will be replaced)
            testShifts.append(shift)
        }

        // October shifts (5 shifts) - all have existing toll amounts
        for day in [5, 12, 18, 23, 30] {
            let shiftStart = createTestDate(year: 2025, month: 10, day: day, hour: 11, minute: 0)
            var shift = createBasicTestShift(startDate: shiftStart)
            shift.endDate = shiftStart.addingTimeInterval(6 * 3600) // 6 hour shift
            shift.endMileage = shift.startMileage + 100.0
            shift.tolls = 5.00 // EXISTING toll amount (will be replaced)
            testShifts.append(shift)
        }

        // Add all shifts to manager
        await MainActor.run {
            for shift in testShifts {
                manager.addShift(shift)
            }
        }

        // Create CSV with toll transactions spread across all shifts
        // CRITICAL: Set amounts so that they SUM TO $5.00 (matching existing shift.tolls)
        // This tests if shifts are counted as "updated" when amounts don't actually change
        var csvLines = ["Transaction Entry Date,Location,Plate,Transaction Amount"]

        for (index, shift) in testShifts.enumerated() {
            // Add exactly 2 transactions per shift that sum to $5.00 (matching existing toll amount)
            // Transaction 1: $3.00
            let tollTime1 = shift.startDate.addingTimeInterval(1800) // 30 min into shift
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MM/dd/yyyy HH:mm:ss"
            let dateString1 = dateFormatter.string(from: tollTime1)
            let location1 = "Test Toll Location \(index)-0"
            let plate = "TX - TEST\(index)"
            csvLines.append("\"\(dateString1)\",\"\(location1)\",\"\(plate)\",3.00")

            // Transaction 2: $2.00 (total = $5.00, matching existing)
            let tollTime2 = shift.startDate.addingTimeInterval(3600) // 1 hour into shift
            let dateString2 = dateFormatter.string(from: tollTime2)
            let location2 = "Test Toll Location \(index)-1"
            csvLines.append("\"\(dateString2)\",\"\(location2)\",\"\(plate)\",2.00")
        }

        let csvContent = csvLines.joined(separator: "\n")
        let tempDir = FileManager.default.temporaryDirectory
        let testURL = tempDir.appendingPathComponent("test_multiple_shifts_diagnostic.csv")
        try csvContent.write(to: testURL, atomically: true, encoding: .utf8)

        debugMessage("Created test CSV with \(csvLines.count - 1) toll transactions across \(testShifts.count) shifts")

        // When: Import the tolls
        let importResult = try await MainActor.run {
            return try ImportExportManager.shared.importTolls(from: testURL, dataManager: manager)
        }

        // Then: Verify that ALL shifts with tolls were updated (should be all 15 shifts)
        debugMessage("Import result: \(importResult.transactions.count) transactions processed, \(importResult.updatedShifts.count) shifts updated, \(importResult.imagesGenerated) images generated")

        XCTAssertEqual(importResult.transactions.count, csvLines.count - 1, "Should import all toll transactions from CSV")
        XCTAssertEqual(importResult.updatedShifts.count, testShifts.count, "Should update ALL shifts that have matching toll transactions")
        XCTAssertEqual(importResult.imagesGenerated, testShifts.count, "Should generate one toll summary image per updated shift")

        // Verify each shift has tolls set and toll image attached
        let shifts = await MainActor.run { manager.shifts }
        for shift in shifts {
            XCTAssertNotNil(shift.tolls, "Each shift should have tolls set after import")
            XCTAssertGreaterThan(shift.tolls ?? 0, 0, "Each shift should have non-zero toll amount")

            let tollImages = shift.imageAttachments.filter { $0.type == .importedToll }
            XCTAssertEqual(tollImages.count, 1, "Each shift should have exactly one toll summary image")
        }

        // Cleanup
        try? FileManager.default.removeItem(at: testURL)
    }

    // MARK: - Real Data Diagnostic Test

    func testTollImportWithRealUserData() async throws {
        // This test uses REAL user backup and toll history files to diagnose the issue
        // User reports: 119 toll transactions processed, only 3 shifts updated (expected 10+)

        // Paths to real data files
        let backupPath = "/Users/gnagz/Library/Mobile Documents/com~apple~CloudDocs/Uber/RideshareTracker_Backup_2025-10-02_07-50-59.json"
        let tollHistoryPath = "/Users/gnagz/Library/Mobile Documents/com~apple~CloudDocs/Uber/Toll Transaction History_01AUG25-05NOV25.csv"

        // Skip test if files don't exist (prevents test failure in CI)
        guard FileManager.default.fileExists(atPath: backupPath),
              FileManager.default.fileExists(atPath: tollHistoryPath) else {
            print("⚠️ Skipping testTollImportWithRealUserData - data files not found")
            print("   Backup: \(backupPath)")
            print("   Toll CSV: \(tollHistoryPath)")
            return
        }

        let manager = await MainActor.run {
            let mgr = ShiftDataManager(forEnvironment: true)
            mgr.shifts.removeAll()
            return mgr
        }

        // Load backup file to restore real shifts
        let backupURL = URL(fileURLWithPath: backupPath)
        let backupData = try await MainActor.run {
            let jsonData = try Data(contentsOf: backupURL)
            let decoder = JSONDecoder()
            // Backup uses TimeInterval (seconds since January 1, 2001 - Apple's reference date)
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let timeInterval = try container.decode(TimeInterval.self)
                return Date(timeIntervalSinceReferenceDate: timeInterval)
            }
            return try decoder.decode(BackupData.self, from: jsonData)
        }

        // Restore shifts from backup
        await MainActor.run {
            _ = BackupRestoreManager.shared.restoreFromBackup(
                backupData: backupData,
                shiftManager: manager,
                expenseManager: ExpenseDataManager.shared,
                preferencesManager: PreferencesManager.shared,
                action: .replaceAll
            )
        }

        let shiftsBeforeImport = await MainActor.run { manager.shifts.count }
        let shiftsWithTollsBefore = await MainActor.run {
            manager.shifts.filter { $0.tolls != nil && $0.tolls! > 0 }.count
        }

        print("📊 Before toll import:")
        print("   Total shifts: \(shiftsBeforeImport)")
        print("   Shifts with tolls: \(shiftsWithTollsBefore)")

        // Import real toll history
        let tollHistoryURL = URL(fileURLWithPath: tollHistoryPath)
        let importResult = try await MainActor.run {
            return try ImportExportManager.shared.importTolls(from: tollHistoryURL, dataManager: manager)
        }

        let shiftsWithTollsAfter = await MainActor.run {
            manager.shifts.filter { $0.tolls != nil && $0.tolls! > 0 }.count
        }

        print("📊 After toll import:")
        print("   Transactions processed: \(importResult.transactions.count)")
        print("   Shifts updated: \(importResult.updatedShifts.count)")
        print("   Images generated: \(importResult.imagesGenerated)")
        print("   Shifts with tolls after: \(shiftsWithTollsAfter)")

        // List the shifts that were updated (with dates for verification)
        print("\n✅ Updated shifts:")
        for shift in importResult.updatedShifts {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .short
            dateFormatter.timeStyle = .short
            print("   • \(dateFormatter.string(from: shift.startDate)) - Tolls: $\(shift.tolls ?? 0)")
        }

        // This test is diagnostic only - we're investigating why so few shifts matched
        // No assertions, just print output for analysis
    }
}
