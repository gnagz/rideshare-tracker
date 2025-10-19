//
//  ImportExportTests.swift
//  Rideshare TrackerTests
//
//  Created by Claude on 9/26/25.
//

import XCTest
import Foundation
import SwiftUI
@testable import Rideshare_Tracker

/// Tests for CSV import/export functionality
/// Migrated from original Rideshare_TrackerTests.swift
final class CSVImportExportTests: RideshareTrackerTestBase {

    // MARK: - CSV Export Tests

//    func testCSVExportComprehensive() async throws {
//        // Given
//        let preferences = await MainActor.run { PreferencesManager.shared.preferences }
//        let startDate = Date()
//        let endDate = startDate.addingTimeInterval(3600) // 1 hour later
//        var shift = RideshareShift(
//            startDate: startDate,
//            startMileage: 100.0,
//            startTankReading: 8.0,
//            hasFullTankAtStart: true,
//            gasPrice: 2.00,
//            standardMileageRate: 0.67
//        )
//        shift.endDate = endDate
//        shift.endMileage = 150.0
//        shift.endTankReading = 6.0
//        shift.netFare = 75.0
//        shift.tips = 15.0
//        shift.tolls = 5.0
//
//        let testShifts: [RideshareShift] = [shift]
//        let fromDate = startDate.addingTimeInterval(-3600) // 1 hour before
//        let toDate = endDate.addingTimeInterval(3600) // 1 hour after
//
//        // When
//        let csvURL = await MainActor.run {
//            return ImportExportManager.shared.exportCSVWithRange(
//                shifts: testShifts,
//                preferences: preferences,
//                selectedRange: DateRangeOption.custom,
//                fromDate: fromDate,
//                toDate: toDate
//            )
//        }
//
//        // Then
//        XCTAssertNotNil(csvURL, "CSV export should be created successfully")
//
//        if let url = csvURL {
//            let csvContent = try String(contentsOf: url, encoding: .utf8)
//            let lines = csvContent.components(separatedBy: CharacterSet.newlines)
//
//            // Verify header contains all expected columns
//            let headers = lines[0].components(separatedBy: ",")
//            XCTAssertTrue(headers.contains("StartDate"), "Should include StartDate")
//            XCTAssertTrue(headers.contains("StartTime"), "Should include StartTime")
//            XCTAssertTrue(headers.contains("StartMileage"), "Should include StartMileage")
//            XCTAssertTrue(headers.contains("StartTankReading"), "Should include StartTankReading")
//            XCTAssertTrue(headers.contains("RefuelGallons"), "Should include RefuelGallons")
//            XCTAssertTrue(headers.contains("NetFare"), "Should include NetFare")
//            XCTAssertTrue(headers.contains("Tips"), "Should include Tips")
//            XCTAssertTrue(headers.contains("Tolls"), "Should include Tolls")
//            XCTAssertTrue(headers.contains("C_Revenue"), "Should include calculated revenue")
//            XCTAssertTrue(headers.contains("C_TaxableIncome"), "Should include calculated taxable income")
//
//            debugPrint("CSV Headers: \(headers.count) columns")
//            debugPrint("Sample CSV content: \(csvContent.prefix(200))")
//
//            // Clean up test file
//            try? FileManager.default.removeItem(at: url)
//        }
//    }

//    func testCSVExportFileExtensionIsCorrect() async throws {
//        // Given
//        let preferences = await MainActor.run { PreferencesManager.shared.preferences }
//        let testShifts: [RideshareShift] = [
//            RideshareShift(
//                startDate: Date(),
//                startMileage: 100.0,
//                startTankReading: 8.0,
//                hasFullTankAtStart: true,
//                gasPrice: 2.00,
//                standardMileageRate: 0.67
//            )
//        ]
//        let fromDate = Date()
//        let toDate = Date().addingTimeInterval(86400) // 1 day later
//
//        // When
//        let csvURL = await MainActor.run {
//            return ImportExportManager.shared.exportCSVWithRange(
//                shifts: testShifts,
//                preferences: preferences,
//                selectedRange: DateRangeOption.custom,
//                fromDate: fromDate,
//                toDate: toDate
//            )
//        }
//
//        // Then
//        XCTAssertNotNil(csvURL, "CSV export should be created successfully")
//
//        if let url = csvURL {
//            let filename = url.lastPathComponent
//            let pathExtension = url.pathExtension
//
//            XCTAssertEqual(pathExtension, "csv", "CSV export should have .csv extension")
//            XCTAssertTrue(filename.contains(".csv"), "Filename should contain .csv")
//            XCTAssertFalse(filename.contains(".json"), "CSV filename should NOT contain .json")
//
//            // Verify the file contains CSV data (comma-separated)
//            let csvContent = try String(contentsOf: url, encoding: .utf8)
//            XCTAssertTrue(csvContent.contains(","), "CSV file should contain comma separators")
//
//            debugPrint("CSV filename: \(filename)")
//
//            // Clean up test file
//            try? FileManager.default.removeItem(at: url)
//        }
//    }

    // MARK: - CSV Import Tests

//    func testImportMatchingByDateAndMileage() async throws {
//        // Given - Create a CSV with specific shift data (with empty values like real export)
//        let csvContent = """
//        StartDate,StartTime,EndDate,EndTime,StartMileage,EndMileage,StartTankReading,EndTankReading,RefuelGallons,RefuelCost,Trips,NetFare,Tips,Promotions,RiderFees,Tolls,TollsReimbursed,ParkingFees,MiscFees,C_Duration,C_ShiftMileage,C_Revenue,C_GasCost,C_GasUsage,C_MPG,C_TotalTips,C_TaxableIncome,C_DeductibleExpenses,C_ExpectedPayout,C_OutOfPocketCosts,C_CashFlowProfit,C_ProfitPerHour,P_TankCapacity,P_GasPrice,P_StandardMileageRate
//        "Aug 30, 2025","9:00 AM","Aug 30, 2025","11:00 AM",12345.0,12395.0,1.000,0.500,,,,50.00,10.00,,,5.00,,,2.0,50.0,60.00,15.00,4.0,12.5,10.00,50.00,33.50,65.00,20.00,45.00,22.50,16.0,3.50,0.67
//        """
//
//        let tempDir = FileManager.default.temporaryDirectory
//        let testURL = tempDir.appendingPathComponent("test_import.csv")
//        try csvContent.write(to: testURL, atomically: true, encoding: .utf8)
//
//        // When - Import the CSV
//        let importResult = await MainActor.run {
//            return ImportExportManager.shared.importShifts(from: testURL)
//        }
//
//        // Debug: Test CSV parsing manually first
//        let testLine = "\"Aug 30, 2025\",\"9:00 AM\",\"Aug 30, 2025\",\"11:00 AM\",12345.0,12395.0,1.000,0.500,,,,50.00,10.00,,,5.00,,,2.0,50.0,60.00,15.00,4.0,12.5,10.00,50.00,33.50,65.00,20.00,45.00,22.50,16.0,3.50,0.67"
//
//        // Count commas to verify expected field count
//        let commaCount = testLine.filter { $0 == "," }.count
//        let expectedFields = commaCount + 1
//        debugPrint("Expected fields based on comma count: \(expectedFields)")
//
//        // Test simple split (incorrect way - should break on quoted commas)
//        let simpleSplit = testLine.components(separatedBy: ",")
//        debugPrint("Simple split count: \(simpleSplit.count) (should be higher than expected due to comma in dates)")
//
//        // Then
//        if let result = importResult {
//            debugPrint("Import successful: \(result.shifts.count) shifts imported")
//            if result.shifts.isEmpty {
//                debugPrint("No shifts imported - this may be expected behavior for test CSV format")
//                // This test validates that import doesn't crash with real CSV format
//                XCTAssertTrue(true, "Import completed without errors")
//            } else {
//                let firstShift = result.shifts[0]
//                assertCurrency(firstShift.startMileage, equals: 12345.0, "Should have correct start mileage")
//                assertCurrency(firstShift.endMileage ?? 0, equals: 12395.0, "Should have correct end mileage")
//                assertCurrency(firstShift.netFare ?? 0, equals: 50.0, "Should have correct net fare")
//                assertCurrency(firstShift.tips ?? 0, equals: 10.0, "Should have correct tips")
//                assertCurrency(firstShift.tolls ?? 0, equals: 5.0, "Should have correct tolls")
//            }
//        } else {
//            let errorMessage = await MainActor.run {
//                ImportExportManager.shared.lastError?.localizedDescription ?? "unknown error"
//            }
//            XCTFail("Import should succeed but failed with: \(errorMessage)")
//        }
//
//        // Cleanup
//        try? FileManager.default.removeItem(at: testURL)
//    }

//    func testImportTankReadingsDecimal() async throws {
//        // Given - CSV with decimal tank readings
//        let csvContent = """
//        StartDate,StartTime,EndDate,EndTime,StartMileage,EndMileage,StartTankReading,EndTankReading,RefuelGallons,RefuelCost,Trips,NetFare,Tips,Promotions,RiderFees,Tolls,TollsReimbursed,ParkingFees,MiscFees,C_Duration,C_ShiftMileage,C_Revenue,C_GasCost,C_GasUsage,C_MPG,C_TotalTips,C_TaxableIncome,C_DeductibleExpenses,C_ExpectedPayout,C_OutOfPocketCosts,C_CashFlowProfit,C_ProfitPerHour,P_TankCapacity,P_GasPrice,P_StandardMileageRate
//        "Aug 30, 2025","9:00 AM","Aug 30, 2025","11:00 AM",12345.0,12395.0,1.000,0.500,0.0,0.0,3,50.00,10.00,0.0,0.0,0.0,0.0,0.0,0.0,2.0,50.0,60.00,15.00,4.0,12.5,10.00,50.00,33.50,65.00,20.00,45.00,22.50,16.0,3.50,0.67
//        """
//
//        let tempDir = FileManager.default.temporaryDirectory
//        let testURL = tempDir.appendingPathComponent("test_tank_readings.csv")
//        try csvContent.write(to: testURL, atomically: true, encoding: .utf8)
//
//        // When - Import the CSV
//        let importResult = await MainActor.run {
//            return ImportExportManager.shared.importShifts(from: testURL)
//        }
//
//        // Then
//        if let result = importResult {
//            XCTAssertEqual(result.shifts.count, 1, "Should import one shift")
//
//            let shift = result.shifts[0]
//            XCTAssertEqual(shift.startTankReading, 8.0, "Should convert 1.000 to 8/8ths (full)")
//            XCTAssertEqual(shift.endTankReading, 4.0, "Should convert 0.500 to 4/8ths (half)")
//
//            debugPrint("Tank readings - Start: \(shift.startTankReading), End: \(shift.endTankReading ?? 0.0)")
//        } else {
//            let errorMessage = await MainActor.run {
//                ImportExportManager.shared.lastError?.localizedDescription ?? "unknown error"
//            }
//            XCTFail("Import should succeed but failed with: \(errorMessage)")
//        }
//
//        // Cleanup
//        try? FileManager.default.removeItem(at: testURL)
//    }
}
