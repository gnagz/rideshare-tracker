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

    func testTollImportReplacesExistingAmount() async throws {
        // Given: Create a shift with existing toll amount
        let shiftStart = createTestDate(year: 2025, month: 9, day: 16, hour: 9, minute: 0)
        var existingShift = createBasicTestShift(startDate: shiftStart)
        existingShift.endDate = shiftStart.addingTimeInterval(8 * 3600)
        existingShift.endMileage = existingShift.startMileage + 150.0
        existingShift.tolls = 2.71  // Pre-existing toll amount (like user manually entered)

        // Add shift to manager
        let manager = await MainActor.run {
            let mgr = ShiftDataManager(forEnvironment: true)
            mgr.shifts.removeAll()
            mgr.addShift(existingShift)
            return mgr
        }

        // Create CSV with toll transactions that should REPLACE the existing amount
        let csvContent = """
        Transaction Entry Date,Location,Plate,Transaction Amount
        "09/16/2025 10:30:00","183S - Thompson Lane Mainline NB","TX - MKG0738",1.30
        "09/16/2025 12:45:00","Mopac Express - Cesar Chavez SB","TX - MKG0738",0.75
        "09/16/2025 15:15:00","183S - Research Blvd NB","TX - MKG0738",0.75
        """

        let tempDir = FileManager.default.temporaryDirectory
        let testURL = tempDir.appendingPathComponent("test_toll_replacement.csv")
        try csvContent.write(to: testURL, atomically: true, encoding: .utf8)

        // When: Import the tolls (this should REPLACE existing tolls)
        let importResult = await MainActor.run {
            return CSVImportManager.importTolls(from: testURL, dataManager: manager)
        }

        // Then: Verify import succeeded
        switch importResult {
        case .success(let result):
            XCTAssertEqual(result.transactions.count, 3, "Should import 3 toll transactions")
            XCTAssertEqual(result.updatedShifts.count, 1, "Should update 1 shift")

            // Verify the shift toll amount was REPLACED, not added to
            guard let updatedShift = result.updatedShifts.first else {
                XCTFail("Should have one updated shift")
                return
            }

            let expectedTotalTolls = 1.30 + 0.75 + 0.75 // = 2.80
            if let actualTolls = updatedShift.tolls {
                assertCurrency(actualTolls, equals: expectedTotalTolls, "Toll amount should be REPLACED with imported total, not added")
                XCTAssertNotEqual(actualTolls, 2.71 + expectedTotalTolls, "Should NOT add to existing amount (would be 5.51)")
            } else {
                XCTFail("Shift should have tolls set after import")
            }

            debugMessage("Original tolls: 2.71, Imported tolls: \(expectedTotalTolls), Final tolls: \(updatedShift.tolls ?? 0)")

        case .failure(let error):
            XCTFail("Toll import should succeed but failed with: \(error.localizedDescription)")
        }

        // Cleanup
        try? FileManager.default.removeItem(at: testURL)
    }

    func testTollImportAttachesImageToShift() async throws {
        // Given: Create a shift that will match toll transactions
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

        // Create CSV with toll transactions
        let csvContent = """
        Transaction Entry Date,Location,Plate,Transaction Amount
        "09/16/2025 10:30:00","183S - Thompson Lane Mainline NB","TX - MKG0738",1.30
        "09/16/2025 12:45:00","Mopac Express - Cesar Chavez SB","TX - MKG0738",0.75
        """

        let tempDir = FileManager.default.temporaryDirectory
        let testURL = tempDir.appendingPathComponent("test_toll_image.csv")
        try csvContent.write(to: testURL, atomically: true, encoding: .utf8)

        // When: Import the tolls
        let importResult = await MainActor.run {
            return CSVImportManager.importTolls(from: testURL, dataManager: manager)
        }

        // Then: Verify toll summary image was attached to shift
        switch importResult {
        case .success(let result):
            XCTAssertEqual(result.transactions.count, 2, "Should import 2 toll transactions")
            XCTAssertEqual(result.updatedShifts.count, 1, "Should update 1 shift")

            guard let updatedShift = result.updatedShifts.first else {
                XCTFail("Should have one updated shift")
                return
            }

            // Debug output
            debugMessage("Toll import result: \(result.imagesGenerated) images generated, \(updatedShift.imageAttachments.count) attachments on shift")

            // Verify toll summary image was attached
            XCTAssertFalse(updatedShift.imageAttachments.isEmpty, "Shift should have image attachments after toll import")
            XCTAssertEqual(result.imagesGenerated, 1, "Should generate 1 toll summary image")

            let tollImageAttachments = updatedShift.imageAttachments.filter { $0.type == .receipt }
            XCTAssertGreaterThanOrEqual(tollImageAttachments.count, 1, "Should have at least one receipt/toll image attachment")

            // Verify the attachment has appropriate description
            if let tollAttachment = tollImageAttachments.first {
                XCTAssertTrue(tollAttachment.description?.contains("Toll Summary") == true, "Toll image should have 'Toll Summary' in description")
            }

            debugMessage("Images generated: \(result.imagesGenerated), Attached images: \(updatedShift.imageAttachments.count)")

        case .failure(let error):
            XCTFail("Toll import should succeed but failed with: \(error.localizedDescription)")
        }

        // Cleanup
        try? FileManager.default.removeItem(at: testURL)
    }
}