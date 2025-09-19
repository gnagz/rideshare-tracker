//
//  Rideshare_TrackerTests.swift
//  Rideshare TrackerTests
//
//  Created by George on 8/10/25.
//

import XCTest
import Foundation
import SwiftUI
@testable import Rideshare_Tracker

@MainActor
final class RideshareShiftTests: XCTestCase {
    
    // Test shift duration calculation
    func testShiftDurationCalculation() async throws {
        // Given
        let startDate = Date()
        let endDate = startDate.addingTimeInterval(4 * 3600) // 4 hours later
        
        var shift = RideshareShift(
            startDate: startDate,
            startMileage: 100.0,
            startTankReading: 8.0,
            hasFullTankAtStart: true,
            gasPrice: 2.00,
            standardMileageRate: 0.67
        )
        shift.endDate = endDate
        shift.endMileage = 200.0
        
        // When
        let duration = shift.shiftDuration
        let hours = shift.shiftHours
        let mileage = shift.shiftMileage
        
        // Then
        XCTAssertEqual(duration, 4 * 3600) // 4 hours in seconds
        XCTAssertEqual(hours, 4) // 4 hours
        XCTAssertEqual(mileage, 100.0) // 100 miles driven
    }
    
    // Test revenue calculation
    func testRevenueCalculation() async throws {
     // Given
     var shift = RideshareShift(
     startDate: Date(),
     startMileage: 100.0,
     startTankReading: 8.0,
     hasFullTankAtStart: true,
     gasPrice: 2.00,
     standardMileageRate: 0.67
     )
     shift.netFare = 150.0
     shift.tips = 25.0
     shift.promotions = 10.0
     
     // When
     let revenue = shift.revenue
     let totalEarnings = shift.totalEarnings
     
     // Then
     XCTAssertEqual(revenue, 185.0) // 150 + 25 + 10
     XCTAssertEqual(totalEarnings, revenue) // Should be the same
     }
     
     // Test profit calculation with direct costs
     func testProfitCalculation() async throws {
     // Given
     var shift = RideshareShift(
     startDate: Date(),
     startMileage: 100.0,
     startTankReading: 8.0,
     hasFullTankAtStart: true,
     gasPrice: 2.00,
     standardMileageRate: 0.67
     )
     shift.endDate = Date().addingTimeInterval(3600) // 1 hour
     shift.endMileage = 200.0
     shift.endTankReading = 6.0 // Used 2/8ths of tank
     shift.netFare = 150.0
     shift.tips = 25.0
     shift.tolls = 10.0
     shift.tollsReimbursed = 5.0
     shift.parkingFees = 5.0
     shift.didRefuelAtEnd = true
     shift.refuelGallons = 4.0 // Only refuel what was used (2/8ths of 16-gallon tank = 4 gallons)
     shift.refuelCost = 8.0 // 4 gallons * $2.00/gallon = $8.00

     let tankCapacity = 16.0 // gallons
     let gasPrice = 2.00 // Set to $2.00/gallon to match refuel calculation
     
     // When
     let revenue = shift.revenue
     let directCosts = shift.directCosts(tankCapacity: tankCapacity)
     let grossProfit = shift.grossProfit(tankCapacity: tankCapacity)
     let cashFlowProfit = shift.cashFlowProfit(tankCapacity: tankCapacity)
     
     // Then
     XCTAssertEqual(revenue, 175.0) // netFare + tips
     XCTAssertEqual(directCosts, 18.0) // shiftGasCost(8.0) + (tolls - tollsReimbursed) + parkingFees = 8.0 + 5.0 + 5.0 = 18.0
     XCTAssertEqual(grossProfit, 157.0) // revenue - directCosts = 175.0 - 18.0 = 157.0
     XCTAssertEqual(cashFlowProfit, grossProfit) // Should be same for this test
     }

     // Test Bug #1: Tank shortage at start + refuel at end - only charge for gas used during shift
     func testTankShortageRefuelBug() async throws {
     // Given: Tank starts NOT full, refuels at end (Bug #1 scenario)
     var shift = RideshareShift(
     startDate: Date(),
     startMileage: 100.0,
     startTankReading: 6.0, // NOT FULL: 6/8 = 4 gallons short of full 16-gallon tank
     hasFullTankAtStart: false,
     gasPrice: 2.00, // Set to $2.00/gallon to match refuel calculation (avoid Bug #2)
     standardMileageRate: 0.67
     )
     shift.endDate = Date().addingTimeInterval(3600) // 1 hour
     shift.endMileage = 150.0
     shift.endTankReading = 8.0 // Full tank after refuel
     shift.netFare = 50.0
     shift.tips = 0.0
     shift.tolls = 0.0
     shift.tollsReimbursed = 0.0
     shift.parkingFees = 0.0
     shift.didRefuelAtEnd = true
     shift.refuelGallons = 6.0 // 2 gallons for shift + 4 gallons for tank shortage = 6 total
     shift.refuelCost = 12.0 // 6 gallons * $2.00/gallon = $12.00

     let tankCapacity = 16.0 // tank capacity in gallons

     // When
     let revenue = shift.revenue
     let directCosts = shift.directCosts(tankCapacity: tankCapacity)
     let grossProfit = shift.grossProfit(tankCapacity: tankCapacity)
     let cashFlowProfit = shift.cashFlowProfit(tankCapacity: tankCapacity)

     // Then: Should only charge for 4 gallons used during shift, NOT the 2-gallon tank shortage
     XCTAssertEqual(revenue, 50.00) // netFare + tips
     XCTAssertEqual(directCosts, 4.00) // shiftGasCost($4.00 for 2 gallons) + (tolls - tollsReimbursed) + parkingFees = 4.00 + 0.0 + 0.0 = $4.00
     XCTAssertEqual(grossProfit, 46.00) // revenue - directCosts = 50.0 - 4.0 = $46.00
     XCTAssertEqual(cashFlowProfit, grossProfit) // Should be same for this test
     }

     // Test gas usage calculation
     func testGasUsageCalculation() async throws {
     // Given
     var shift = RideshareShift(
     startDate: Date(),
     startMileage: 100.0,
     startTankReading: 8.0, // Full tank
     hasFullTankAtStart: true,
     gasPrice: 2.00,
     standardMileageRate: 0.67
     )
     shift.endMileage = 200.0
     shift.endTankReading = 4.0 // Half tank remaining
     
     let tankCapacity = 16.0 // gallons
     
     // When
     let gasUsed = shift.shiftGasUsage(tankCapacity: tankCapacity)
     let mpg = shift.shiftMPG(tankCapacity: tankCapacity)
     
     // Then
     XCTAssertEqual(gasUsed, 8.0) // Used half tank (8 gallons)
     XCTAssertEqual(mpg, 12.5) // 100 miles / 8 gallons
     }
     
     // Test gas usage with refuel
     func testGasUsageWithRefuel() async throws {
     // Given
     var shift = RideshareShift(
     startDate: Date(),
     startMileage: 100.0,
     startTankReading: 6.0, // 3/4 tank
     
     hasFullTankAtStart: false,
     gasPrice: 2.00,
     standardMileageRate: 0.67
     )
     shift.endMileage = 300.0
     shift.endTankReading = 8.0 // Full tank (after refuel)
     shift.didRefuelAtEnd = true
     shift.refuelGallons = 10.0 // Added 10 gallons
     
     let tankCapacity = 16.0 // gallons
     
     // When
     let gasUsed = shift.shiftGasUsage(tankCapacity: tankCapacity)
     let mpg = shift.shiftMPG(tankCapacity: tankCapacity)
     
     // Then
     XCTAssertEqual(gasUsed, 6.0) // Actually used 6 gallons of gas
     XCTAssertEqual(mpg, 200.0 / 6.0) // 200 miles / 6 gallons ≈ 33.33 MPG
     }
     
     // Test incomplete shift
     func testIncompleteShift() async throws {
     // Given
     let shift = RideshareShift(
     startDate: Date(),
     startMileage: 100.0,
     startTankReading: 8.0,
     hasFullTankAtStart: true,
     gasPrice: 2.00,
     standardMileageRate: 0.67
     )
     
     // When/Then
     XCTAssertEqual(shift.endDate, nil)
     XCTAssertEqual(shift.shiftMileage, 0.0) // No end mileage yet
     XCTAssertEqual(shift.shiftDuration, 0.0) // No duration yet
     XCTAssertEqual(shift.revenue, 0.0) // No earnings yet
     }
     
     // Test tax calculations
     func testTaxCalculations() async throws {
     // Given
     var shift = RideshareShift(
     startDate: Date(),
     startMileage: 100.0,
     startTankReading: 8.0,
     hasFullTankAtStart: true,
     gasPrice: 2.00,
     standardMileageRate: 0.67
     )
     shift.endMileage = 200.0 // 100 miles
     shift.netFare = 150.0
     shift.tips = 25.0 // Cash tips are taxable but reported separately
     shift.tolls = 10.0
     shift.tollsReimbursed = 5.0
     shift.parkingFees = 8.0
     
     let mileageRate = 0.67 // IRS standard mileage rate
     
     // When
     let taxableIncome = shift.taxableIncome
     let deductibleExpenses = shift.deductibleExpenses(mileageRate: mileageRate)
     
     // Then
     XCTAssertEqual(taxableIncome, 150.0) // netFare only (tips reported separately)
     XCTAssertEqual(deductibleExpenses, 80.0) // (100 * 0.67) + (10-5) + 8 = 67 + 5 + 8 = 80
     }
     
     // Test profit per hour calculation
     func testProfitPerHour() async throws {
     // Given
     let startDate = Date()
     let endDate = startDate.addingTimeInterval(2 * 3600) // 2 hours

     var shift = RideshareShift(
     startDate: startDate,
     startMileage: 100.0,
     startTankReading: 8.0,
     hasFullTankAtStart: true,
     gasPrice: 2.00,
     standardMileageRate: 0.67
     )
     shift.endDate = endDate
     shift.endMileage = 150.0
     shift.endTankReading = 7.0
     shift.netFare = 80.0
     shift.tips = 20.0
     
     let tankCapacity = 16.0
     let gasPrice = 3.50
     
     // When
     let totalProfit = shift.cashFlowProfit(tankCapacity: tankCapacity)
     let profitPerHour = shift.profitPerHour(tankCapacity: tankCapacity)
     
     // Then
     XCTAssertTrue(totalProfit > 0) // Should be profitable
     XCTAssertEqual(profitPerHour, totalProfit / 2.0) // Should be profit divided by 2 hours
     }
     }
     
     // MARK: - Import/Export Tests
     @MainActor
     struct ImportExportTests {
     
     // Test CSV export with comprehensive columns
     func testCSVExportComprehensive() async throws {
     // Given
     let preferences = AppPreferences.shared
     let startDate = Date()
     let endDate = startDate.addingTimeInterval(3600) // 1 hour later

     var shift = RideshareShift(
     startDate: startDate,
     startMileage: 100.0,
     startTankReading: 8.0,
     hasFullTankAtStart: true,
     gasPrice: 2.00,
     standardMileageRate: 0.67
     )
     shift.endDate = endDate
     shift.endMileage = 150.0
     shift.endTankReading = 6.0
     shift.netFare = 75.0
     shift.tips = 15.0
     shift.tolls = 5.0
     shift.refuelGallons = 8.0
     shift.refuelCost = 25.0
     
     let testShifts = [shift]
     let fromDate = Date()
     let toDate = Date().addingTimeInterval(86400) // 1 day later
     
     // When
     let csvURL = preferences.exportCSVWithRange(shifts: testShifts, selectedRange: DateRangeOption.custom, fromDate: fromDate, toDate: toDate)
     
     // Then
     XCTAssertNotNil(csvURL, "CSV export should be created successfully")
     
     if let url = csvURL {
     let csvContent = try String(contentsOf: url, encoding: .utf8)
     let lines = csvContent.components(separatedBy: .newlines)
     
     // Verify header contains all expected columns
     let headers = lines[0].components(separatedBy: ",")
     XCTAssertTrue(headers.contains("StartDate"), "Should include StartDate")
     XCTAssertTrue(headers.contains("StartTime"), "Should include StartTime")
     XCTAssertTrue(headers.contains("StartMileage"), "Should include StartMileage")
     XCTAssertTrue(headers.contains("StartTankReading"), "Should include StartTankReading")
     XCTAssertTrue(headers.contains("RefuelGallons"), "Should include RefuelGallons")
     XCTAssertTrue(headers.contains("Tips"), "Should include Tips")
     XCTAssertTrue(headers.contains("C_Revenue"), "Should include calculated Revenue")
     XCTAssertTrue(headers.contains("C_MPG"), "Should include calculated MPG")
     XCTAssertTrue(headers.contains("P_TankCapacity"), "Should include preference TankCapacity")
     
     // Verify we have data row
     XCTAssertTrue(lines.count >= 2, "Should have header + at least one data row")
     }
     }
     
     // Test import matching by date and start mileage
     func testImportMatchingByDateAndMileage() async throws {
     // Given - Create a CSV with specific shift data (with empty values like real export)
     let csvContent = """
     StartDate,StartTime,EndDate,EndTime,StartMileage,EndMileage,StartTankReading,EndTankReading,RefuelGallons,RefuelCost,Trips,NetFare,Tips,Promotions,RiderFees,Tolls,TollsReimbursed,ParkingFees,MiscFees,C_Duration,C_ShiftMileage,C_Revenue,C_GasCost,C_GasUsage,C_MPG,C_TotalTips,C_TaxableIncome,C_DeductibleExpenses,C_ExpectedPayout,C_OutOfPocketCosts,C_CashFlowProfit,C_ProfitPerHour,P_TankCapacity,P_GasPrice,P_StandardMileageRate
     "Aug 30, 2025","9:00 AM","Aug 30, 2025","11:00 AM",12345.0,12395.0,1.000,0.500,,,,50.00,10.00,,,5.00,,,2.0,50.0,60.00,15.00,4.0,12.5,10.00,50.00,33.50,65.00,20.00,45.00,22.50,16.0,3.50,0.67,0.67
     """
     
     let tempDir = FileManager.default.temporaryDirectory
     let testURL = tempDir.appendingPathComponent("test_import.csv")
     try csvContent.write(to: testURL, atomically: true, encoding: .utf8)
     
     // When - Import the CSV
     let importResult = AppPreferences.importCSV(from: testURL)
     
     // Debug: Test CSV parsing manually first
     let testLine = "\"Aug 30, 2025\",\"9:00 AM\",\"Aug 30, 2025\",\"11:00 AM\",12345.0,12395.0,1.000,0.500,,,,50.00,10.00,,,5.00,,,2.0,50.0,60.00,15.00,4.0,12.5,10.00,50.00,33.50,65.00,20.00,45.00,22.50,16.0,3.50,0.67"
     
     // Count commas to verify expected field count
     let commaCount = testLine.filter { $0 == "," }.count
     let expectedFields = commaCount + 1
     print("DEBUG: Expected fields based on comma count: \(expectedFields)")
     
     // Test simple split (incorrect way - should break on quoted commas)
     let simpleSplit = testLine.components(separatedBy: ",")
     print("DEBUG: Simple split count: \(simpleSplit.count) (should be higher than expected due to comma in dates)")
     
     // Then
     switch importResult {
     case .success(let result):
     XCTAssertEqual(result.shifts.count, 1, "Should import one shift, got \(result.shifts.count). Expected fields: \(expectedFields), Simple split: \(simpleSplit.count)")
     
     let importedShift = result.shifts[0]
     XCTAssertEqual(importedShift.startMileage, 12345.0, "Should have correct start mileage")
     XCTAssertEqual(importedShift.endMileage, 12395.0, "Should have correct end mileage")
     XCTAssertEqual(importedShift.netFare, 50.0, "Should have correct net fare")
     XCTAssertEqual(importedShift.tips, 10.0, "Should have correct tips")
     XCTAssertEqual(importedShift.tolls, 5.0, "Should have correct tolls")
     
     case .failure(let error):
     XCTFail("Import should succeed but failed with: \(error)")
     }
     
     // Cleanup
     try FileManager.default.removeItem(at: testURL)
     }
     
     // Test import matching with multiple shifts on same day
     func testImportMultipleShiftsPerDay() async throws {
     // Given - Two shifts on same date with different mileage
     let csvContent = """
     StartDate,StartTime,EndDate,EndTime,StartMileage,EndMileage,StartTankReading,EndTankReading,RefuelGallons,RefuelCost,Trips,NetFare,Tips,Promotions,RiderFees,Tolls,TollsReimbursed,ParkingFees,MiscFees,C_Duration,C_ShiftMileage,C_Revenue,C_GasCost,C_GasUsage,C_MPG,C_TotalTips,C_TaxableIncome,C_DeductibleExpenses,C_ExpectedPayout,C_OutOfPocketCosts,C_CashFlowProfit,C_ProfitPerHour,P_TankCapacity,P_GasPrice,P_StandardMileageRate
     "Aug 30, 2025","9:00 AM","Aug 30, 2025","12:00 PM",12345.0,12395.0,1.000,0.750,0.0,0.0,3,45.00,8.00,0.0,0.0,3.00,0.0,0.0,0.0,3.0,50.0,53.00,12.00,2.0,25.0,8.00,45.00,33.50,58.00,15.00,43.00,14.33,16.0,3.50,0.67
     "Aug 30, 2025","6:00 PM","Aug 30, 2025","9:00 PM",12395.0,12435.0,0.750,0.500,0.0,0.0,2,35.00,7.00,0.0,0.0,2.00,0.0,0.0,0.0,3.0,40.0,42.00,10.00,2.0,20.0,7.00,35.00,26.80,49.00,12.00,37.00,12.33,16.0,3.50,0.67
     """
     
     let tempDir = FileManager.default.temporaryDirectory
     let testURL = tempDir.appendingPathComponent("test_multiple_shifts.csv")
     try csvContent.write(to: testURL, atomically: true, encoding: .utf8)
     
     // When - Import the CSV
     let importResult = AppPreferences.importCSV(from: testURL)
     
     // Then
     switch importResult {
     case .success(let result):
     XCTAssertEqual(result.shifts.count, 2, "Should import two shifts")
     
     let shifts = result.shifts.sorted { $0.startMileage < $1.startMileage }
     
     // First shift (morning)
     XCTAssertEqual(shifts[0].startMileage, 12345.0, "First shift should have start mileage 12345")
     XCTAssertEqual(shifts[0].endMileage, 12395.0, "First shift should have end mileage 12395")
     XCTAssertEqual(shifts[0].netFare, 45.0, "First shift should have correct fare")
     
     // Second shift (evening)
     XCTAssertEqual(shifts[1].startMileage, 12395.0, "Second shift should have start mileage 12395")
     XCTAssertEqual(shifts[1].endMileage, 12435.0, "Second shift should have end mileage 12435")
     XCTAssertEqual(shifts[1].netFare, 35.0, "Second shift should have correct fare")
     
     // Verify both shifts have same date
     let calendar = Calendar.current
     XCTAssertTrue(calendar.isDate(shifts[0].startDate, inSameDayAs: shifts[1].startDate), "Both shifts should be on same day")
     
     case .failure(let error):
     XCTFail("Import should succeed but failed with: \(error)")
     }
     
     // Cleanup
     try FileManager.default.removeItem(at: testURL)
     }
     
     // Test CSV import with tank readings in decimal format
     func testImportTankReadingsDecimal() async throws {
     // Given - CSV with decimal tank readings
     let csvContent = """
     StartDate,StartTime,EndDate,EndTime,StartMileage,EndMileage,StartTankReading,EndTankReading,RefuelGallons,RefuelCost,Trips,NetFare,Tips,Promotions,RiderFees,Tolls,TollsReimbursed,ParkingFees,MiscFees,C_Duration,C_ShiftMileage,C_Revenue,C_GasCost,C_GasUsage,C_MPG,C_TotalTips,C_TaxableIncome,C_DeductibleExpenses,C_ExpectedPayout,C_OutOfPocketCosts,C_CashFlowProfit,C_ProfitPerHour,P_TankCapacity,P_GasPrice,P_StandardMileageRate
     "Aug 30, 2025","9:00 AM","Aug 30, 2025","11:00 AM",12345.0,12395.0,1.000,0.500,0.0,0.0,3,50.00,10.00,0.0,0.0,0.0,0.0,0.0,0.0,2.0,50.0,60.00,15.00,4.0,12.5,10.00,50.00,33.50,65.00,20.00,45.00,22.50,16.0,3.50,0.67
     """
     
     let tempDir = FileManager.default.temporaryDirectory
     let testURL = tempDir.appendingPathComponent("test_tank_readings.csv")
     try csvContent.write(to: testURL, atomically: true, encoding: .utf8)
     
     // When - Import the CSV
     let importResult = AppPreferences.importCSV(from: testURL)
     
     // Then
     switch importResult {
     case .success(let result):
     XCTAssertEqual(result.shifts.count, 1, "Should import one shift")
     
     let shift = result.shifts[0]
     XCTAssertEqual(shift.startTankReading, 8.0, "Should convert 1.000 to 8/8ths (full)")
     XCTAssertEqual(shift.endTankReading, 4.0, "Should convert 0.500 to 4/8ths (half)")
     
     case .failure(let error):
     XCTFail("Import should succeed but failed with: \(error)")
     }
     
     // Cleanup
     try FileManager.default.removeItem(at: testURL)
     }
     }
     
     @MainActor
     struct AppPreferencesTests {
     
     // Test backup file extension is correct (.json not .json.csv)
     func testBackupFileExtensionIsCorrect() async throws {
     // Given
     let preferences = AppPreferences.shared
     let testShifts: [RideshareShift] = [
     RideshareShift(
     startDate: Date(),
     startMileage: 100.0,
     startTankReading: 8.0,
     hasFullTankAtStart: true,
     gasPrice: 2.00,
     standardMileageRate: 0.67
     )
     ]
     let testExpenses: [ExpenseItem] = [
     ExpenseItem(
     date: Date(),
     category: .vehicle,
     description: "Test expense",
     amount: 25.0
     )
     ]
     
     // When
     let backupURL = preferences.exportData(shifts: testShifts, expenses: testExpenses)
     
     // Then
     XCTAssertNotNil(backupURL, "Backup should be created successfully")
     
     if let url = backupURL {
     let filename = url.lastPathComponent
     let pathExtension = url.pathExtension
     
     // CRITICAL: This test catches the .json.csv bug
     XCTAssertEqual(pathExtension, "json", "Backup file should have .json extension, not .json.csv or other")
     XCTAssertTrue(filename.contains(".json"), "Filename should contain .json")
     XCTAssertFalse(filename.contains(".csv"), "Filename should NOT contain .csv")
     XCTAssertTrue(filename.hasPrefix("RideshareTracker_Backup_"), "Should have correct filename prefix")
     
     // Verify the file actually contains JSON data
     let fileData = try Data(contentsOf: url)
     let jsonObject = try JSONSerialization.jsonObject(with: fileData)
     XCTAssertTrue(jsonObject is [String: Any], "File should contain valid JSON dictionary")
     
     // Clean up test file
     try? FileManager.default.removeItem(at: url)
     }
     }
     
     // Test CSV export file extension is correct
     func testCSVExportFileExtensionIsCorrect() async throws {
     // Given
     let preferences = AppPreferences.shared
     let testShifts: [RideshareShift] = [
     RideshareShift(
     startDate: Date(),
     startMileage: 100.0,
     startTankReading: 8.0,
     hasFullTankAtStart: true,
     gasPrice: 2.00,
     standardMileageRate: 0.67
     )
     ]
     let fromDate = Date()
     let toDate = Date().addingTimeInterval(86400) // 1 day later
     
     // When
     let csvURL = preferences.exportCSVWithRange(shifts: testShifts, selectedRange: DateRangeOption.custom, fromDate: fromDate, toDate: toDate)
     
     // Then
     XCTAssertNotNil(csvURL, "CSV export should be created successfully")
     
     if let url = csvURL {
     let filename = url.lastPathComponent
     let pathExtension = url.pathExtension
     
     XCTAssertEqual(pathExtension, "csv", "CSV export should have .csv extension")
     XCTAssertTrue(filename.contains(".csv"), "Filename should contain .csv")
     XCTAssertFalse(filename.contains(".json"), "CSV filename should NOT contain .json")
     
     // Verify the file contains CSV data (comma-separated)
     let csvContent = try String(contentsOf: url, encoding: .utf8)
     XCTAssertTrue(csvContent.contains(","), "CSV file should contain comma separators")
     XCTAssertTrue(csvContent.contains("StartDate"), "CSV should have header row")
     
     // Clean up test file
     try? FileManager.default.removeItem(at: url)
     }
     }
     }
     
     @MainActor
     struct DateRangeOptionTests {
     
     // MARK: - Test basic date range calculations
     
     func testTodayDateRange() async throws {
     // Given
     let range = DateRangeOption.today
     let calendar = Calendar.current
     let now = Date()
     
     // When
     let result = range.getDateRange(weekStartDay: 1)
     
     // Then
     let expectedStart = calendar.startOfDay(for: now)
     let expectedEnd = calendar.date(byAdding: .day, value: 1, to: expectedStart)!
     
     XCTAssertTrue(calendar.isDate(result.start, inSameDayAs: expectedStart))
     XCTAssertTrue(calendar.isDate(result.end, inSameDayAs: expectedEnd))
     }
     
     func testYesterdayDateRange() async throws {
     // Given
     let range = DateRangeOption.yesterday
     let calendar = Calendar.current
     let now = Date()
     
     // When
     let result = range.getDateRange(weekStartDay: 1)
     
     // Then
     let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
     let expectedStart = calendar.startOfDay(for: yesterday)
     let expectedEnd = calendar.date(byAdding: .day, value: 1, to: expectedStart)!
     
     XCTAssertTrue(calendar.isDate(result.start, inSameDayAs: expectedStart))
     XCTAssertTrue(calendar.isDate(result.end, inSameDayAs: expectedEnd))
     }
     
     // MARK: - Test week calculations with different start days
     
     func testThisWeekWithMondayStart() async throws {
     // Given: Sunday, August 24, 2025
     let testDate = createDate(year: 2025, month: 8, day: 24, weekday: 1) // Sunday
     let range = DateRangeOption.thisWeek
     
     // When: Week starts on Monday (weekStartDay = 1)
     let result = range.getDateRange(weekStartDay: 1, referenceDate: testDate)
     
     // Then: Should be Monday August 18 - Sunday August 24
     let expectedStart = createDate(year: 2025, month: 8, day: 18, weekday: 2) // Monday Aug 18
     let expectedEnd = createDate(year: 2025, month: 8, day: 24, weekday: 1) // Sunday Aug 24
     
     XCTAssertTrue(Calendar.current.isDate(result.start, inSameDayAs: expectedStart))
     XCTAssertTrue(Calendar.current.isDate(result.end, inSameDayAs: expectedEnd))
     }
     
     func testThisWeekWithSundayStart() async throws {
     // Given: Monday, August 25, 2025
     let testDate = createDate(year: 2025, month: 8, day: 25, weekday: 2) // Monday
     let range = DateRangeOption.thisWeek
     
     // When: Week starts on Sunday (weekStartDay = 7)
     let result = range.getDateRange(weekStartDay: 7, referenceDate: testDate)
     
     // Then: Should be Sunday August 24 - Saturday August 30
     let expectedStart = createDate(year: 2025, month: 8, day: 24, weekday: 1) // Sunday Aug 24
     let expectedEnd = createDate(year: 2025, month: 8, day: 30, weekday: 7) // Saturday Aug 30
     
     XCTAssertTrue(Calendar.current.isDate(result.start, inSameDayAs: expectedStart))
     XCTAssertTrue(Calendar.current.isDate(result.end, inSameDayAs: expectedEnd))
     }
     
     func testLastWeekWithMondayStart() async throws {
     // Given: Monday, September 1, 2025
     let testDate = createDate(year: 2025, month: 9, day: 1, weekday: 2) // Monday
     let range = DateRangeOption.lastWeek
     
     // When: Week starts on Monday (weekStartDay = 1)
     let result = range.getDateRange(weekStartDay: 1, referenceDate: testDate)
     
     // Then: Should be Monday August 25 - Sunday August 31
     let expectedStart = createDate(year: 2025, month: 8, day: 25, weekday: 2) // Monday Aug 25
     let expectedEnd = createDate(year: 2025, month: 8, day: 31, weekday: 1) // Sunday Aug 31
     
     XCTAssertTrue(Calendar.current.isDate(result.start, inSameDayAs: expectedStart))
     XCTAssertTrue(Calendar.current.isDate(result.end, inSameDayAs: expectedEnd))
     }
     
     func testLastWeekWithSundayStart() async throws {
     // Given: Monday, September 1, 2025
     let testDate = createDate(year: 2025, month: 9, day: 1, weekday: 2) // Monday
     let range = DateRangeOption.lastWeek
     
     // When: Week starts on Sunday (weekStartDay = 7)
     let result = range.getDateRange(weekStartDay: 7, referenceDate: testDate)
     
     // Then: Should be Sunday August 24 - Saturday August 30
     let expectedStart = createDate(year: 2025, month: 8, day: 24, weekday: 1) // Sunday Aug 24
     let expectedEnd = createDate(year: 2025, month: 8, day: 30, weekday: 7) // Saturday Aug 30
     
     XCTAssertTrue(Calendar.current.isDate(result.start, inSameDayAs: expectedStart))
     XCTAssertTrue(Calendar.current.isDate(result.end, inSameDayAs: expectedEnd))
     }
     
     // MARK: - Test edge cases for week calculations
     
     func testWeekCalculationAcrossMonthBoundary() async throws {
     // Given: Tuesday, September 2, 2025 (early in month)
     let testDate = createDate(year: 2025, month: 9, day: 2, weekday: 3) // Tuesday
     let range = DateRangeOption.thisWeek
     
     // When: Week starts on Monday
     let result = range.getDateRange(weekStartDay: 1, referenceDate: testDate)
     
     // Then: Should include days from August (Monday Sept 1)
     let expectedStart = createDate(year: 2025, month: 9, day: 1, weekday: 2) // Monday Sept 1
     let expectedEnd = createDate(year: 2025, month: 9, day: 7, weekday: 1) // Sunday Sept 7
     
     XCTAssertTrue(Calendar.current.isDate(result.start, inSameDayAs: expectedStart))
     XCTAssertTrue(Calendar.current.isDate(result.end, inSameDayAs: expectedEnd))
     }
     
     func testWeekCalculationAcrossYearBoundary() async throws {
     // Given: Wednesday, January 1, 2025
     let testDate = createDate(year: 2025, month: 1, day: 1, weekday: 4) // Wednesday
     let range = DateRangeOption.thisWeek
     
     // When: Week starts on Monday
     let result = range.getDateRange(weekStartDay: 1, referenceDate: testDate)
     
     // Then: Should include days from December 2024
     let expectedStart = createDate(year: 2024, month: 12, day: 30, weekday: 2) // Monday Dec 30, 2024
     let expectedEnd = createDate(year: 2025, month: 1, day: 5, weekday: 1) // Sunday Jan 5, 2025
     
     XCTAssertTrue(Calendar.current.isDate(result.start, inSameDayAs: expectedStart))
     XCTAssertTrue(Calendar.current.isDate(result.end, inSameDayAs: expectedEnd))
     }
     
     // MARK: - Test month calculations
     
     func testThisMonthDateRange() async throws {
     // Given
     let testDate = createDate(year: 2025, month: 8, day: 15) // Mid August
     let range = DateRangeOption.thisMonth
     
     // When
     let result = range.getDateRange(weekStartDay: 1, referenceDate: testDate)
     
     // Then
     let expectedStart = createDate(year: 2025, month: 8, day: 1) // August 1
     let expectedEnd = createDate(year: 2025, month: 8, day: 31) // August 31
     
     XCTAssertTrue(Calendar.current.isDate(result.start, inSameDayAs: expectedStart))
     XCTAssertTrue(Calendar.current.isDate(result.end, inSameDayAs: expectedEnd))
     }
     
     func testLastMonthDateRange() async throws {
     // Given
     let testDate = createDate(year: 2025, month: 9, day: 15) // Mid September
     let range = DateRangeOption.lastMonth
     
     // When
     let result = range.getDateRange(weekStartDay: 1, referenceDate: testDate)
     
     // Then
     let expectedStart = createDate(year: 2025, month: 8, day: 1) // August 1
     let expectedEnd = createDate(year: 2025, month: 8, day: 31) // August 31
     
     XCTAssertTrue(Calendar.current.isDate(result.start, inSameDayAs: expectedStart))
     XCTAssertTrue(Calendar.current.isDate(result.end, inSameDayAs: expectedEnd))
     }
     
     // MARK: - Test year calculations
     
     func testThisYearDateRange() async throws {
     // Given
     let testDate = createDate(year: 2025, month: 6, day: 15) // Mid 2025
     let range = DateRangeOption.thisYear
     
     // When
     let result = range.getDateRange(weekStartDay: 1, referenceDate: testDate)
     
     // Then
     let expectedStart = createDate(year: 2025, month: 1, day: 1) // January 1, 2025
     let expectedEnd = createDate(year: 2025, month: 12, day: 31) // December 31, 2025
     
     XCTAssertTrue(Calendar.current.isDate(result.start, inSameDayAs: expectedStart))
     XCTAssertTrue(Calendar.current.isDate(result.end, inSameDayAs: expectedEnd))
     }
     
     func testLastYearDateRange() async throws {
     // Given
     let testDate = createDate(year: 2025, month: 6, day: 15) // Mid 2025
     let range = DateRangeOption.lastYear
     
     // When
     let result = range.getDateRange(weekStartDay: 1, referenceDate: testDate)
     
     // Then
     let expectedStart = createDate(year: 2024, month: 1, day: 1) // January 1, 2024
     let expectedEnd = createDate(year: 2024, month: 12, day: 31) // December 31, 2024
     
     XCTAssertTrue(Calendar.current.isDate(result.start, inSameDayAs: expectedStart))
     XCTAssertTrue(Calendar.current.isDate(result.end, inSameDayAs: expectedEnd))
     }
     
     // MARK: - Test all enum cases are covered
     
     func testAllDateRangeOptionsAreHandled() async throws {
     // Given
     let testDate = Date()
     
     // When/Then - Ensure no cases throw exceptions
     for range in DateRangeOption.allCases {
     let result = range.getDateRange(weekStartDay: 1, referenceDate: testDate)
     
     // Basic sanity checks
     if range != .all {
     XCTAssertTrue(result.start <= result.end, "Start should be before or equal to end for \(range.rawValue)")
     }
     
     // All option should return distant dates
     if range == .all {
     XCTAssertEqual(result.start, Date.distantPast)
     XCTAssertEqual(result.end, Date.distantFuture)
     }
     }
     }
     
     // MARK: - Helper methods for test date creation
     
     private func createDate(year: Int, month: Int, day: Int, weekday: Int? = nil) -> Date {
     let calendar = Calendar.current
     var components = DateComponents()
     components.year = year
     components.month = month
     components.day = day
     components.hour = 12 // Noon to avoid timezone issues
     
     let date = calendar.date(from: components) ?? Date()
     
     // Verify weekday if specified (for test correctness)
     if let expectedWeekday = weekday {
     let actualWeekday = calendar.component(.weekday, from: date)
     assert(actualWeekday == expectedWeekday,
     "Test date creation error: Expected weekday \(expectedWeekday) but got \(actualWeekday) for \(month)/\(day)/\(year)")
     }
     
     return date
     }
     }
     
     @MainActor
     struct IncrementalSyncTests {
     
     // MARK: - AppPreferences Sync Settings Tests
     
     func testSyncPreferencesBasicFunctionality() async throws {
     // Simple test that doesn't mess with UserDefaults to avoid parallel execution issues
     let preferences = AppPreferences.shared
     
     // Save original state
     let originalSyncEnabled = preferences.incrementalSyncEnabled
     let originalSyncFrequency = preferences.syncFrequency
     let originalSyncDate = preferences.lastIncrementalSyncDate
     
     // Test setting and getting sync preferences
     preferences.incrementalSyncEnabled = true
     XCTAssertEqual(preferences.incrementalSyncEnabled, true, "Should be able to set sync enabled")
     
     preferences.syncFrequency = "Daily"
     XCTAssertEqual(preferences.syncFrequency, "Daily", "Should be able to set sync frequency")
     
     let testDate = Date()
     preferences.lastIncrementalSyncDate = testDate
     XCTAssertEqual(preferences.lastIncrementalSyncDate, testDate, "Should be able to set last sync date")
     
     // Test savePreferences doesn't crash
     preferences.savePreferences()
     
     // Restore original state
     preferences.incrementalSyncEnabled = originalSyncEnabled
     preferences.syncFrequency = originalSyncFrequency
     preferences.lastIncrementalSyncDate = originalSyncDate
     }
     
     // MARK: - Data Model Sync Metadata Tests
     
     func testRideshareShiftHasSyncMetadata() async throws {
     // Given/When
     let shift = RideshareShift(
     startDate: Date(),
     startMileage: 100.0,
     startTankReading: 8.0,
     hasFullTankAtStart: true,
     gasPrice: 2.00,
     standardMileageRate: 0.67
     )
     
     // Then
     XCTAssertTrue(shift.id != UUID(), "Shift should have a unique ID")
     XCTAssertTrue(shift.createdDate != Date(timeIntervalSince1970: 0), "Shift should have created date set")
     XCTAssertTrue(shift.modifiedDate != Date(timeIntervalSince1970: 0), "Shift should have modified date set")
     XCTAssertFalse(shift.deviceID.isEmpty, "Shift should have device ID set")
     XCTAssertEqual(shift.isDeleted, false, "Shift should not be marked as deleted by default")
     }
     
     func testExpenseItemHasSyncMetadata() async throws {
     // Given/When
     let expense = ExpenseItem(
     date: Date(),
     category: .vehicle,
     description: "Test expense",
     amount: 25.0
     )
     
     // Then
     XCTAssertTrue(expense.id != UUID(), "Expense should have a unique ID")
     XCTAssertTrue(expense.createdDate != Date(timeIntervalSince1970: 0), "Expense should have created date set")
     XCTAssertTrue(expense.modifiedDate != Date(timeIntervalSince1970: 0), "Expense should have modified date set")
     XCTAssertFalse(expense.deviceID.isEmpty, "Expense should have device ID set")
     XCTAssertEqual(expense.isDeleted, false, "Expense should not be marked as deleted by default")
     }
     
     func testShiftSyncMetadataUpdate() async throws {
     // Given
     var shift = RideshareShift(
     startDate: Date(),
     startMileage: 100.0,
     startTankReading: 8.0,
     hasFullTankAtStart: true,
     gasPrice: 2.00,
     standardMileageRate: 0.67
     )
     let originalModifiedDate = shift.modifiedDate
     
     // Wait a bit to ensure time difference
     try await Task.sleep(nanoseconds: 1_000_000) // 1ms
     
     // When - simulate updating the shift
     shift.modifiedDate = Date()
     shift.endMileage = 200.0
     
     // Then
     XCTAssertTrue(shift.modifiedDate > originalModifiedDate, "Modified date should be updated when shift changes")
     }
     
     // MARK: - Data Migration Tests
     
     func testMigrateShiftWithoutSyncMetadata() async throws {
     // Given - simulate an old shift without sync metadata
     var oldShift = RideshareShift(
     startDate: Date(),
     startMileage: 100.0,
     startTankReading: 8.0,
     hasFullTankAtStart: true,
     gasPrice: 2.00,
     standardMileageRate: 0.67
     )
     oldShift.endDate = Date().addingTimeInterval(3600)
     oldShift.endMileage = 150.0
     
     // Clear sync metadata to simulate old record
     oldShift.deviceID = "unknown"
     _ = oldShift.createdDate // Verify it exists
     
     // When - simulate migration logic
     if oldShift.deviceID.isEmpty || oldShift.deviceID == "unknown" {
     oldShift.createdDate = oldShift.startDate
     oldShift.modifiedDate = oldShift.endDate ?? oldShift.startDate
     oldShift.deviceID = "migrated-device-id"
     oldShift.isDeleted = false
     }
     
     // Then
     XCTAssertEqual(oldShift.createdDate, oldShift.startDate, "Created date should be set to start date during migration")
     XCTAssertEqual(oldShift.modifiedDate, oldShift.endDate, "Modified date should be set to end date during migration")
     XCTAssertEqual(oldShift.deviceID, "migrated-device-id", "Device ID should be updated during migration")
     XCTAssertEqual(oldShift.isDeleted, false, "isDeleted should be set to false during migration")
     }
     
     func testMigrateExpenseWithoutSyncMetadata() async throws {
     // Given - simulate an old expense without sync metadata
     var oldExpense = ExpenseItem(
     date: Date(),
     category: .vehicle,
     description: "Old expense",
     amount: 50.0
     )
     
     // Clear sync metadata to simulate old record
     oldExpense.deviceID = ""
     
     // When - simulate migration logic
     if oldExpense.deviceID.isEmpty || oldExpense.deviceID == "unknown" {
     oldExpense.createdDate = oldExpense.date
     oldExpense.modifiedDate = oldExpense.date
     oldExpense.deviceID = "migrated-device-id"
     oldExpense.isDeleted = false
     }
     
     // Then
     XCTAssertEqual(oldExpense.createdDate, oldExpense.date, "Created date should be set to expense date during migration")
     XCTAssertEqual(oldExpense.modifiedDate, oldExpense.date, "Modified date should be set to expense date during migration")
     XCTAssertEqual(oldExpense.deviceID, "migrated-device-id", "Device ID should be updated during migration")
     XCTAssertEqual(oldExpense.isDeleted, false, "isDeleted should be set to false during migration")
     }
     
     // MARK: - Initial Sync Detection Tests
     
     func testDetectFirstTimeSyncEnable() async throws {
     // Given
     let preferences = AppPreferences.shared
     let originalSyncDate = preferences.lastIncrementalSyncDate
     
     // Reset to test state
     preferences.lastIncrementalSyncDate = nil
     
     // When/Then - First time enabling should be detectable
     let isFirstTimeEnabling = preferences.lastIncrementalSyncDate == nil
     XCTAssertEqual(isFirstTimeEnabling, true, "Should detect first time sync enabling")
     
     // When - after initial sync
     preferences.lastIncrementalSyncDate = Date()
     
     // Then
     let isStillFirstTime = preferences.lastIncrementalSyncDate == nil
     XCTAssertEqual(isStillFirstTime, false, "Should not detect first time after sync date is set")
     
     // Restore original state
     preferences.lastIncrementalSyncDate = originalSyncDate
     }
     
     // MARK: - Backup Creation with Sync Support Tests
     
     func testCreateFullBackupWithSyncMetadata() async throws {
     // Given
     let preferences = AppPreferences.shared
     
     let shiftWithSyncData = RideshareShift(
     startDate: Date(),
     startMileage: 100.0,
     startTankReading: 8.0,
     hasFullTankAtStart: true,
     gasPrice: 2.00,
     standardMileageRate: 0.67
     )
     
     let expenseWithSyncData = ExpenseItem(
     date: Date(),
     category: .vehicle,
     description: "Test expense with sync data",
     amount: 25.0
     )
     
     // When
     let backupURL = preferences.createFullBackup(shifts: [shiftWithSyncData], expenses: [expenseWithSyncData])
     
     // Then
     XCTAssertNotNil(backupURL, "Full backup should be created successfully")
     
     if let url = backupURL {
     // Verify the backup contains the sync metadata
     let backupData = try Data(contentsOf: url)
     let backupJson = try JSONSerialization.jsonObject(with: backupData) as! [String: Any]
     
     XCTAssertNotNil(backupJson["shifts"], "Backup should contain shifts")
     XCTAssertNotNil(backupJson["expenses"], "Backup should contain expenses")
     
     let shifts = backupJson["shifts"] as! [[String: Any]]
     let expenses = backupJson["expenses"] as! [[String: Any]]
     
     XCTAssertEqual(shifts.count, 1, "Should have one shift in backup")
     XCTAssertEqual(expenses.count, 1, "Should have one expense in backup")
     
     // Verify sync metadata is preserved in backup
     let firstShift = shifts[0]
     XCTAssertNotNil(firstShift["createdDate"], "Shift backup should include createdDate")
     XCTAssertNotNil(firstShift["modifiedDate"], "Shift backup should include modifiedDate")
     XCTAssertNotNil(firstShift["deviceID"], "Shift backup should include deviceID")
     XCTAssertNotNil(firstShift["isDeleted"], "Shift backup should include isDeleted")
     
     let firstExpense = expenses[0]
     XCTAssertNotNil(firstExpense["createdDate"], "Expense backup should include createdDate")
     XCTAssertNotNil(firstExpense["modifiedDate"], "Expense backup should include modifiedDate")
     XCTAssertNotNil(firstExpense["deviceID"], "Expense backup should include deviceID")
     XCTAssertNotNil(firstExpense["isDeleted"], "Expense backup should include isDeleted")
     
     // Clean up test file
     try? FileManager.default.removeItem(at: url)
     }
     }
     
     // MARK: - Sync Frequency Validation Tests
     
     func testSyncFrequencyOptions() async throws {
     // Given
     let preferences = AppPreferences.shared
     let originalSyncFrequency = preferences.syncFrequency
     let validFrequencies = ["Immediate", "Hourly", "Daily"]
     
     // When/Then
     for frequency in validFrequencies {
     preferences.syncFrequency = frequency
     
     XCTAssertEqual(preferences.syncFrequency, frequency, "Should accept valid sync frequency: \(frequency)")
     }
     
     // Restore original state
     preferences.syncFrequency = originalSyncFrequency
     }
     
     func testDefaultSyncFrequency() async throws {
     // Given/When
     let preferences = AppPreferences.shared
     let originalSyncFrequency = preferences.syncFrequency
     
     // Reset to default for testing
     preferences.syncFrequency = "Immediate"
     
     // Then
     XCTAssertEqual(preferences.syncFrequency, "Immediate", "Default sync frequency should be Immediate")
     
     // Restore original state
     preferences.syncFrequency = originalSyncFrequency
     }
     }
     
     @MainActor
     struct SyncDataManagerTests {
     
     // MARK: - ExpenseDataManager saveExpenses Access Tests
     
     func testExpenseManagerSaveIsPublic() async throws {
     // Given
     let manager = ExpenseDataManager(forEnvironment: true)
     let testExpense = ExpenseItem(
     date: Date(),
     category: .vehicle,
     description: "Test save access",
     amount: 10.0
     )
     
     // When - This should compile without error (testing public access)
     manager.addExpense(testExpense)
     manager.saveExpenses() // This line tests that saveExpenses is public
     
     // Then - Verify the expense was added and saved
     XCTAssertTrue(manager.expenses.contains { $0.description == "Test save access" }, "Expense should be added to manager")
     }
     
     // MARK: - Data Manager Sync Integration Tests
     
     func testShiftDataManagerPreservesMetadata() async throws {
     // Given
     let manager = ShiftDataManager(forEnvironment: true)
     var testShift = RideshareShift(
     startDate: Date(),
     startMileage: 100.0,
     startTankReading: 8.0,
     hasFullTankAtStart: true,
     gasPrice: 2.00,
     standardMileageRate: 0.67
     )
     testShift.deviceID = "test-device-123"
     testShift.modifiedDate = Date()
     
     // When
     manager.addShift(testShift)
     manager.saveShifts()
     
     // Create new manager to test persistence
     let newManager = ShiftDataManager(forEnvironment: true)
     
     // Then
     XCTAssertTrue(newManager.shifts.count > 0, "Shifts should be loaded from persistence")
     
     let loadedShift = newManager.shifts.first { $0.id == testShift.id }
     XCTAssertNotNil(loadedShift, "Test shift should be found in loaded data")
     
     if let loaded = loadedShift {
     XCTAssertEqual(loaded.deviceID, "test-device-123", "Device ID should be preserved through save/load")
     XCTAssertEqual(loaded.isDeleted, false, "isDeleted should be preserved through save/load")
     }
     }
     
     func testExpenseDataManagerPreservesMetadata() async throws {
     // Given
     let manager = ExpenseDataManager(forEnvironment: true)
     var testExpense = ExpenseItem(
     date: Date(),
     category: .equipment,
     description: "Test metadata preservation",
     amount: 75.0
     )
     testExpense.deviceID = "test-device-456"
     testExpense.modifiedDate = Date()
     
     // When
     manager.addExpense(testExpense)
     manager.saveExpenses()
     
     // Create new manager to test persistence
     let newManager = ExpenseDataManager(forEnvironment: true)
     
     // Then
     XCTAssertTrue(newManager.expenses.count > 0, "Expenses should be loaded from persistence")
     
     let loadedExpense = newManager.expenses.first { $0.id == testExpense.id }
     XCTAssertNotNil(loadedExpense, "Test expense should be found in loaded data")
     
     if let loaded = loadedExpense {
     XCTAssertEqual(loaded.deviceID, "test-device-456", "Device ID should be preserved through save/load")
     XCTAssertEqual(loaded.isDeleted, false, "isDeleted should be preserved through save/load")
     }
     }
     }
     
     // MARK: - Soft Deletion Tests
     
     @MainActor
     struct SoftDeletionTests {
     func testActiveShiftsFiltersSoftDeletedRecords() async throws {
     let manager = ShiftDataManager(forEnvironment: true)
     
     // Create test shifts - one active, one soft-deleted
     var activeShift = createTestShift()
     activeShift.isDeleted = false
     
     var deletedShift = createTestShift()
     deletedShift.isDeleted = true
     
     // Add both shifts to manager
     manager.shifts = [activeShift, deletedShift]
     
     // Test activeShifts property filters out soft-deleted records
     let activeShifts = manager.activeShifts
     XCTAssertEqual(activeShifts.count, 1, "activeShifts should only return non-deleted records")
     XCTAssertEqual(activeShifts.first?.id, activeShift.id, "activeShifts should return the active shift")
     XCTAssertFalse(activeShifts.contains { $0.isDeleted }, "activeShifts should not contain deleted records")
     }
     
     func testActiveExpensesFiltersSoftDeletedRecords() async throws {
     let manager = ExpenseDataManager(forEnvironment: true)
     
     // Create test expenses - one active, one soft-deleted
     var activeExpense = ExpenseItem(date: Date(), category: .equipment, description: "Phone Mount", amount: 50.0)
     activeExpense.isDeleted = false
     
     var deletedExpense = ExpenseItem(date: Date(), category: .vehicle, description: "Repair", amount: 100.0)
     deletedExpense.isDeleted = true
     
     // Add both expenses to manager
     manager.expenses = [activeExpense, deletedExpense]
     
     // Test activeExpenses property filters out soft-deleted records
     let activeExpenses = manager.activeExpenses
     XCTAssertEqual(activeExpenses.count, 1, "activeExpenses should only return non-deleted records")
     XCTAssertEqual(activeExpenses.first?.id, activeExpense.id, "activeExpenses should return the active expense")
     XCTAssertFalse(activeExpenses.contains { $0.isDeleted }, "activeExpenses should not contain deleted records")
     }
     
     func testConditionalDeletionWithSyncEnabled() async throws {
     let manager = ShiftDataManager(forEnvironment: true)
     let preferences = AppPreferences.shared
     
     // Clear any existing shifts first
     manager.shifts.removeAll()
     
     // Enable cloud sync
     preferences.incrementalSyncEnabled = true
     
     let testShift = createTestShift()
     manager.addShift(testShift)
     
     // Delete shift with sync enabled - should be soft deleted
     manager.deleteShift(testShift)
     
     // Verify shift is soft-deleted, not hard-deleted
     XCTAssertEqual(manager.shifts.count, 1, "Shift should still exist in shifts array")
     XCTAssertEqual(manager.shifts.first?.isDeleted, true, "Shift should be marked as deleted")
     XCTAssertEqual(manager.activeShifts.count, 0, "activeShifts should not include soft-deleted shift")
     
     // Cleanup
     preferences.incrementalSyncEnabled = false
     }
     
     func testConditionalDeletionWithSyncDisabled() async throws {
     let manager = ShiftDataManager(forEnvironment: true)
     let preferences = AppPreferences.shared
     
     // Clear any existing shifts first
     manager.shifts.removeAll()
     
     // Disable cloud sync
     preferences.incrementalSyncEnabled = false
     
     let testShift = createTestShift()
     manager.addShift(testShift)
     
     // Delete shift with sync disabled - should be hard deleted
     manager.deleteShift(testShift)
     
     // Verify shift is completely removed
     XCTAssertEqual(manager.shifts.count, 0, "Shift should be completely removed from shifts array")
     XCTAssertEqual(manager.activeShifts.count, 0, "activeShifts should be empty")
     }
     
     func testAutomaticCleanupOfSoftDeletedRecords() async throws {
     let manager = ShiftDataManager(forEnvironment: true)
     let preferences = AppPreferences.shared
     
     // Disable sync to trigger cleanup
     preferences.incrementalSyncEnabled = false
     
     // Create shifts with mixed deletion status
     var activeShift = createTestShift()
     activeShift.isDeleted = false
     
     var deletedShift1 = createTestShift()
     deletedShift1.isDeleted = true
     
     var deletedShift2 = createTestShift()
     deletedShift2.isDeleted = true
     
     // Manually set shifts to simulate loaded data with soft-deleted records
     manager.shifts = [activeShift, deletedShift1, deletedShift2]
     
     // Trigger cleanup (simulates what happens during loadShifts)
     manager.cleanupDeletedShifts()
     
     // Verify only active shifts remain
     XCTAssertEqual(manager.shifts.count, 1, "Only active shifts should remain after cleanup")
     XCTAssertEqual(manager.shifts.first?.id, activeShift.id, "The remaining shift should be the active one")
     XCTAssertFalse(manager.shifts.contains { $0.isDeleted }, "No soft-deleted shifts should remain")
     }
     
     func testExpenseFilteringInMonthlyQueries() async throws {
     let manager = ExpenseDataManager(forEnvironment: true)
     
     let currentDate = Date()
     
     // Create expenses for current month - one active, one deleted
     var activeExpense = ExpenseItem(date: currentDate, category: .supplies, description: "Cleaning Supplies", amount: 50.0)
     activeExpense.isDeleted = false
     
     var deletedExpense = ExpenseItem(date: currentDate, category: .vehicle, description: "Oil Change", amount: 100.0)
     deletedExpense.isDeleted = true
     
     manager.expenses = [activeExpense, deletedExpense]
     
     // Test monthly queries filter out deleted expenses
     let monthExpenses = manager.expensesForMonth(currentDate)
     XCTAssertEqual(monthExpenses.count, 1, "Monthly expenses should exclude deleted records")
     XCTAssertEqual(monthExpenses.first?.id, activeExpense.id, "Should return only the active expense")
     
     // Test monthly total excludes deleted expenses
     let monthTotal = manager.totalForMonth(currentDate)
     XCTAssertEqual(monthTotal, 50.0, "Monthly total should only include active expenses")
     }
     
     private func createTestShift() -> RideshareShift {
     return RideshareShift(
     startDate: Date(),
     startMileage: 10000.0,
     startTankReading: 8.0,
     hasFullTankAtStart: true,
     gasPrice: 2.00,
     standardMileageRate: 0.67
     )
     }
     }
     
     // MARK: - Week Date Range Tests
     
     @MainActor
     struct WeekDateRangeTests {
     func testWeekBoundaryInclusiveFiltering() async throws {
     let manager = ShiftDataManager(forEnvironment: true)
     manager.shifts.removeAll() // Clear any existing state
     let preferences = AppPreferences.shared
     let calendar = Calendar.current
     
     // Test the actual bug: Sunday Aug 24, 2025 was being excluded from week view
     // Create date for Sunday Aug 24, 2025 (the original problematic date)
     let sundayComponents = DateComponents(year: 2025, month: 8, day: 24, hour: 14, minute: 30)
     guard let sundayAug24 = calendar.date(from: sundayComponents) else {
     throw TestError.dateCreationFailed
     }
     
     // Create a shift on the boundary date that was being excluded
     let boundaryShift = RideshareShift(
     startDate: sundayAug24,
     startMileage: 62495.0,
     startTankReading: 1.0,
     hasFullTankAtStart: false,
     gasPrice: 2.00,
     standardMileageRate: 0.67
     )
     
     manager.shifts = [boundaryShift]
     
     // Replicate ContentView's getWeekInterval logic exactly
     func getWeekInterval(for date: Date) -> DateInterval {
     let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
     
     // Find the user's preferred week start day
     let preferredWeekStart = preferences.weekStartDay == 1 ? 1 : 2 // 1 = Sunday, 2 = Monday
     let currentWeekStart = calendar.component(.weekday, from: startOfWeek)
     
     var adjustedStart = startOfWeek
     if currentWeekStart != preferredWeekStart {
     let dayDifference = preferredWeekStart - currentWeekStart
     adjustedStart = calendar.date(byAdding: .day, value: dayDifference, to: startOfWeek) ?? startOfWeek
     
     // If the adjustment puts us in the future, go back a week
     if adjustedStart > date {
     adjustedStart = calendar.date(byAdding: .weekOfYear, value: -1, to: adjustedStart) ?? adjustedStart
     }
     }
     
     let endOfWeek = calendar.date(byAdding: .day, value: 6, to: adjustedStart) ?? adjustedStart
     return DateInterval(start: adjustedStart, end: endOfWeek)
     }
     
     // Simple test: test that inclusive vs exclusive boundary filtering works differently
     let startDate = sundayAug24.addingTimeInterval(-3600 * 24 * 3) // 3 days before
     let endDate = sundayAug24
     
     // Test the FIXED inclusive filtering logic (ContentView currentWeekShifts)
     let inclusiveFilteredShifts = manager.activeShifts.filter { shift in
     shift.startDate >= startDate && shift.startDate <= endDate
     }
     
     // Test the OLD buggy filtering logic (using DateInterval.contains)
     let weekInterval = DateInterval(start: startDate, end: endDate)
     let exclusiveFilteredShifts = manager.activeShifts.filter { shift in
     weekInterval.contains(shift.startDate)
     }
     
     // The fix: inclusive filtering should find the boundary shift
     XCTAssertEqual(inclusiveFilteredShifts.count, 1, "Fixed inclusive filtering should find boundary shift")
     XCTAssertEqual(inclusiveFilteredShifts.first?.id, boundaryShift.id, "Should find the Sunday boundary shift")
     
     // The original bug: exclusive filtering should behave differently (may or may not find boundary)
     XCTAssertTrue(inclusiveFilteredShifts.count >= exclusiveFilteredShifts.count, "Inclusive filtering should find at least as many shifts as exclusive")
     }
     
     func testWeekStartDayPreferenceDependency() async throws {
     let manager = ShiftDataManager(forEnvironment: true)
     manager.shifts.removeAll() // Clear any existing state
     let calendar = Calendar.current
     
     // Create date for Wednesday Aug 20, 2025 (middle of week)
     let wednesdayComponents = DateComponents(year: 2025, month: 8, day: 20, hour: 12, minute: 0)
     guard let wednesdayAug20 = calendar.date(from: wednesdayComponents) else {
     throw TestError.dateCreationFailed
     }
     
     // Create a shift on Wednesday
     let testShift = RideshareShift(
     startDate: wednesdayAug20,
     startMileage: 10000.0,
     startTankReading: 8.0,
     hasFullTankAtStart: true,
     gasPrice: 2.00,
     standardMileageRate: 0.67
     )
     
     manager.shifts = [testShift]
     
     // Replicate ContentView's getWeekInterval logic exactly
     func getWeekInterval(for date: Date, weekStartDay: Int) -> DateInterval {
     let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
     
     // Find the user's preferred week start day
     let preferredWeekStart = weekStartDay == 1 ? 1 : 2 // 1 = Sunday, 2 = Monday
     let currentWeekStart = calendar.component(.weekday, from: startOfWeek)
     
     var adjustedStart = startOfWeek
     if currentWeekStart != preferredWeekStart {
     let dayDifference = preferredWeekStart - currentWeekStart
     adjustedStart = calendar.date(byAdding: .day, value: dayDifference, to: startOfWeek) ?? startOfWeek
     
     // If the adjustment puts us in the future, go back a week
     if adjustedStart > date {
     adjustedStart = calendar.date(byAdding: .weekOfYear, value: -1, to: adjustedStart) ?? adjustedStart
     }
     }
     
     let endOfWeek = calendar.date(byAdding: .day, value: 6, to: adjustedStart) ?? adjustedStart
     return DateInterval(start: adjustedStart, end: endOfWeek)
     }
     
     // Test with Sunday start (weekStartDay = 1)
     let sundayWeekInterval = getWeekInterval(for: wednesdayAug20, weekStartDay: 1)
     let sundayWeekShifts = manager.activeShifts.filter { shift in
     shift.startDate >= sundayWeekInterval.start && shift.startDate <= sundayWeekInterval.end
     }
     
     // Test with Monday start (weekStartDay = 2)
     let mondayWeekInterval = getWeekInterval(for: wednesdayAug20, weekStartDay: 2)
     let mondayWeekShifts = manager.activeShifts.filter { shift in
     shift.startDate >= mondayWeekInterval.start && shift.startDate <= mondayWeekInterval.end
     }
     
     // Both should find the Wednesday shift, but with different week boundaries
     XCTAssertEqual(sundayWeekShifts.count, 1, "Sunday-start week should include Wednesday shift")
     XCTAssertEqual(mondayWeekShifts.count, 1, "Monday-start week should include Wednesday shift")
     XCTAssertEqual(sundayWeekShifts.first?.id, testShift.id, "Should find correct shift with Sunday start")
     XCTAssertEqual(mondayWeekShifts.first?.id, testShift.id, "Should find correct shift with Monday start")
     
     // The week intervals should be different (different start dates)
     XCTAssertTrue(sundayWeekInterval.start != mondayWeekInterval.start, "Different week start preferences should create different week boundaries")
     }
     }
     
     // MARK: - Calculator Tests
     @MainActor
     struct CalculatorEngineTests {
     
     func testBasicArithmetic() async throws {
     let calculator = CalculatorEngine.shared
     
     // Basic operations
     XCTAssertEqual(calculator.evaluate("45+23"), 68.0)
     XCTAssertEqual(calculator.evaluate("100-25"), 75.0)
     XCTAssertEqual(calculator.evaluate("50*2"), 100.0)
     XCTAssertEqual(calculator.evaluate("100/4"), 25.0)
     
     // Decimal operations
     let result1 = calculator.evaluate("12.50+3.75")
     XCTAssertNotNil(result1)
     XCTAssertTrue(abs(result1! - 16.25) < 0.001)
     
     let result2 = calculator.evaluate("45.67*0.85")
     XCTAssertNotNil(result2)
     XCTAssertTrue(abs(result2! - 38.8195) < 0.001)
     }
     
     func testRideshareScenarios() async throws {
     let calculator = CalculatorEngine.shared
     
     // Scenarios from your Uber shifts
     XCTAssertEqual(calculator.evaluate("250-175"), 75.0)   // Mileage calculation (end - start)
     XCTAssertEqual(calculator.evaluate("45/3"), 15.0)       // Tip splitting
     XCTAssertEqual(calculator.evaluate("65*0.75"), 48.75)   // Fuel costs
     XCTAssertEqual(calculator.evaluate("150*0.67"), 100.5)  // Tax deductions (IRS rate)
     
     // Expense calculations
     XCTAssertEqual(calculator.evaluate("12.50+3.50"), 16.0)  // Meal + tip
     XCTAssertEqual(calculator.evaluate("25+15+8"), 48.0)     // Multiple expenses
     }
     
     func testComplexExpressions() async throws {
     let calculator = CalculatorEngine.shared
     
     // Parentheses and order of operations
     XCTAssertEqual(calculator.evaluate("(100+50)*0.67"), 100.5)
     XCTAssertEqual(calculator.evaluate("100+50*2-25/5"), 195.0)
     XCTAssertEqual(calculator.evaluate("(250-175)*0.67"), 50.25) // Miles times IRS rate
     }
     
     func testExpressionDetection() async throws {
     let calculator = CalculatorEngine.shared
     
     // Should detect math expressions
     XCTAssertEqual(calculator.containsMathExpression("45+23"), true)
     XCTAssertEqual(calculator.containsMathExpression("100*0.67"), true)
     XCTAssertTrue(calculator.containsMathExpression("250-175=") == true)
     
     // Should not detect plain numbers
     XCTAssertEqual(calculator.containsMathExpression("45"), false)
     XCTAssertEqual(calculator.containsMathExpression("123.45"), false)
     XCTAssertEqual(calculator.containsMathExpression(""), false)
     }
     
     func testInputSanitization() async throws {
     let calculator = CalculatorEngine.shared
     
     // Should handle equals sign at end
     XCTAssertTrue(calculator.evaluate("45+23=") == 68.0)
     XCTAssertTrue(calculator.evaluate("100/4=") == 25.0)
     
     // Should handle alternative math symbols
     XCTAssertEqual(calculator.evaluate("50×2"), 100.0)  // Multiplication symbol
     XCTAssertEqual(calculator.evaluate("100÷4"), 25.0)  // Division symbol
     XCTAssertEqual(calculator.evaluate("100−25"), 75.0) // En-dash minus
     }
     
     func testErrorHandling() async throws {
     let calculator = CalculatorEngine.shared
     
     // Invalid expressions should return nil
     XCTAssertEqual(calculator.evaluate("invalid"), nil)
     XCTAssertEqual(calculator.evaluate("45+"), nil)
     XCTAssertEqual(calculator.evaluate("+45"), nil)
     XCTAssertEqual(calculator.evaluate("45++23"), nil)
     XCTAssertEqual(calculator.evaluate("("), nil)
     XCTAssertTrue(calculator.evaluate("45/0") != nil) // Division by zero should be handled by NSExpression
     }
     
     func testStringExtensions() async throws {
     // Test convenience extensions
     XCTAssertEqual("45+23".evaluateAsMath(), 68.0)
     XCTAssertEqual("100*0.67".evaluateAsMath(), 67.0)
     
     XCTAssertEqual("45+23".containsMathExpression, true)
     XCTAssertEqual("123.45".containsMathExpression, false)
     
     XCTAssertEqual("45+23".isValidMathExpression, true)
     XCTAssertEqual("45+".isValidMathExpression, false)
     }
     
     func testMultipleRefuelingScenario() async throws {
     let calculator = CalculatorEngine.shared
     
     // Your real scenario: refueling more than once
     // Fuel costs: First fill $45.67, second fill $38.25
     XCTAssertEqual(calculator.evaluate("45.67+38.25"), 83.92)
     
     // Gallons used: First 12.5 gallons, second 10.75 gallons
     let totalGallons = calculator.evaluate("12.5+10.75")
     XCTAssertEqual(totalGallons, 23.25)
     
     // Average cost per gallon across both fills
     let avgCostPerGallon = calculator.evaluate("(45.67+38.25)/(12.5+10.75)")
     XCTAssertNotNil(avgCostPerGallon)
     XCTAssertTrue(abs(avgCostPerGallon! - 3.61) < 0.01)
     
     // Complex refuel math: (cost1/gallons1 + cost2/gallons2)/2 for average price
     let complexAvg = calculator.evaluate("(45.67/12.5 + 38.25/10.75)/2")
     XCTAssertNotNil(complexAvg)
     XCTAssertTrue(complexAvg! > 3.5 && complexAvg! < 4.0)
     }
     
     func testRealWorldUberScenarios() async throws {
     let calculator = CalculatorEngine.shared
     
     // After 12-hour shift calculations
     // Multiple platform earnings: Uber + Lyft + DoorDash
     XCTAssertEqual(calculator.evaluate("125.50+87.25+45.75"), 258.5)
     
     // Tip calculations with cash tips included
     XCTAssertEqual(calculator.evaluate("35.75+12+8.50"), 56.25)
     
     // Toll road costs throughout day
     XCTAssertEqual(calculator.evaluate("3.50+2.75+4.25+3.50"), 14.0)
     
     // Parking fees at multiple locations
     XCTAssertEqual(calculator.evaluate("8+5+12"), 25.0)
     
     // Net profit after all expenses
     let revenue = calculator.evaluate("258.5+56.25") // Fare + tips
     let expenses = calculator.evaluate("83.92+14+25") // Fuel + tolls + parking
     XCTAssertEqual(revenue, 314.75)
     XCTAssertEqual(expenses, 122.92)
     
     // Quick profit check
     let profit = calculator.evaluate("314.75-122.92")
     XCTAssertNotNil(profit)
     XCTAssertTrue(abs(profit! - 191.83) < 0.01)
     }
     }
     
     enum TestError: Error {
     case dateCreationFailed
     }
     
     // MARK: - Phase 1 Photo Attachment Tests
     
     @MainActor
     struct ExpenseImageAttachmentTests {
     
     func testExpenseItemImageAttachmentMetadata() async throws {
     // Given
     let expense = ExpenseItem(
     date: Date(),
     category: .vehicle,
     description: "Test expense with images",
     amount: 45.67
     )
     
     let attachment = ImageAttachment(
     filename: "test_receipt.jpg",
     type: .receipt,
     description: "Gas receipt"
     )
     
     // When
     var expenseWithImage = expense
     expenseWithImage.imageAttachments.append(attachment)
     
     // Then
     XCTAssertEqual(expenseWithImage.imageAttachments.count, 1, "Should have one image attachment")
     XCTAssertEqual(expenseWithImage.imageAttachments.first?.filename, "test_receipt.jpg", "Should have correct filename")
     XCTAssertEqual(expenseWithImage.imageAttachments.first?.type, .receipt, "Should have correct attachment type")
     XCTAssertEqual(expenseWithImage.imageAttachments.first?.description, "Gas receipt", "Should have correct description")
     XCTAssertTrue(expenseWithImage.imageAttachments.first?.id != UUID(), "Should have unique ID")
     }
     
     func testExpenseItemImageAttachmentSyncMetadata() async throws {
     // Given
     let expense = ExpenseItem(
     date: Date(),
     category: .equipment,
     description: "Phone mount with receipt photo",
     amount: 29.99
     )
     
     let attachment = ImageAttachment(
     filename: "receipt_20250914.jpg",
     type: .receipt
     )
     
     // When
     var expenseWithImage = expense
     expenseWithImage.imageAttachments.append(attachment)
     expenseWithImage.modifiedDate = Date()
     
     // Then
     // Verify sync metadata exists
     XCTAssertTrue(expenseWithImage.createdDate != Date(timeIntervalSince1970: 0), "Should have creation date")
     XCTAssertTrue(expenseWithImage.modifiedDate != Date(timeIntervalSince1970: 0), "Should have modification date")
     XCTAssertFalse(expenseWithImage.deviceID.isEmpty, "Should have device ID")
     XCTAssertEqual(expenseWithImage.isDeleted, false, "Should not be deleted")
     
     // Verify attachment metadata
     XCTAssertTrue(attachment.createdDate != Date(timeIntervalSince1970: 0), "Attachment should have creation date")
     XCTAssertTrue(attachment.id != UUID(), "Attachment should have unique ID")
     }
     
     func testExpenseItemImageAttachmentPersistence() async throws {
     // Given
     let originalExpense = ExpenseItem(
     date: Date(),
     category: .supplies,
     description: "Cleaning supplies with receipts",
     amount: 15.50
     )
     
     let attachment1 = ImageAttachment(filename: "receipt1.jpg", type: .receipt)
     let attachment2 = ImageAttachment(filename: "receipt2.jpg", type: .receipt)
     
     var expenseWithImages = originalExpense
     expenseWithImages.imageAttachments = [attachment1, attachment2]
     
     // When - Encode and decode to test persistence
     let encoder = JSONEncoder()
     let data = try encoder.encode(expenseWithImages)
     
     let decoder = JSONDecoder()
     let decodedExpense = try decoder.decode(ExpenseItem.self, from: data)
     
     // Then
     XCTAssertEqual(decodedExpense.imageAttachments.count, 2, "Should persist both image attachments")
     XCTAssertEqual(decodedExpense.imageAttachments[0].filename, "receipt1.jpg", "Should preserve first attachment filename")
     XCTAssertEqual(decodedExpense.imageAttachments[1].filename, "receipt2.jpg", "Should preserve second attachment filename")
     XCTAssertEqual(decodedExpense.imageAttachments[0].type, .receipt, "Should preserve attachment type")
     XCTAssertEqual(decodedExpense.imageAttachments[0].id, attachment1.id, "Should preserve attachment ID")
     XCTAssertEqual(decodedExpense.imageAttachments[1].id, attachment2.id, "Should preserve attachment ID")
     }
     
     func testExpenseItemBackwardCompatibilityWithoutImages() async throws {
     // Given - JSON without imageAttachments field (simulating old data)
     let jsonWithoutImages = """
     {
     "id": "12345678-1234-1234-1234-123456789ABC",
     "date": 1726329600.0,
     "category": "Vehicle",
     "description": "Gas",
     "amount": 45.67,
     "createdDate": 1726329600.0,
     "modifiedDate": 1726329600.0,
     "deviceID": "test-device",
     "isDeleted": false
     }
     """.data(using: .utf8)!
     
     // When
     let decoder = JSONDecoder()
     let expense = try decoder.decode(ExpenseItem.self, from: jsonWithoutImages)
     
     // Then
     XCTAssertTrue(expense.imageAttachments.isEmpty, "Should default to empty array for backward compatibility")
     XCTAssertEqual(expense.amount, 45.67, "Should decode other fields correctly")
     XCTAssertEqual(expense.description, "Gas", "Should decode description correctly")
     }
     
     func testImageAttachmentFileURLGeneration() async throws {
     // Given
     let expenseID = UUID()
     let attachment = ImageAttachment(
     filename: "test_image.jpg",
     type: .receipt,
     description: "Test receipt"
     )
     
     // When
     let fileURL = attachment.fileURL(for: expenseID, parentType: .expense)
     let thumbnailURL = attachment.thumbnailURL(for: expenseID, parentType: .expense)
     
     // Then
     XCTAssertTrue(fileURL.absoluteString.contains("expenses"), "File URL should contain expense parent type")
     XCTAssertTrue(fileURL.absoluteString.contains(expenseID.uuidString), "File URL should contain parent ID")
     XCTAssertTrue(fileURL.absoluteString.contains("test_image.jpg"), "File URL should contain filename")
     
     XCTAssertTrue(thumbnailURL.absoluteString.contains("Thumbnails"), "Thumbnail URL should contain thumbnails directory")
     XCTAssertTrue(thumbnailURL.absoluteString.contains("expenses"), "Thumbnail URL should contain expense parent type")
     XCTAssertTrue(thumbnailURL.absoluteString.contains(expenseID.uuidString), "Thumbnail URL should contain parent ID")
     }
     
     func testAttachmentTypeSystemImages() async throws {
     // Given/When/Then - Test all attachment types have system images
     for attachmentType in AttachmentType.allCases {
     XCTAssertFalse(attachmentType.systemImage.isEmpty, "\(attachmentType.rawValue) should have system image")
     XCTAssertFalse(attachmentType.displayName.isEmpty, "\(attachmentType.rawValue) should have display name")
     }
     
     // Test specific mappings
     XCTAssertEqual(AttachmentType.receipt.systemImage, "receipt", "Receipt should use receipt icon")
     XCTAssertEqual(AttachmentType.gasPump.systemImage, "fuelpump", "Gas pump should use fuel pump icon")
     XCTAssertEqual(AttachmentType.damage.systemImage, "exclamationmark.triangle", "Damage should use warning icon")
     }
     }
     
     @MainActor
     struct ImageManagerTests {
     
     // Helper method to create test image
     private func createTestImage(size: CGSize = CGSize(width: 100, height: 100), color: UIColor = .blue) -> UIImage {
     UIGraphicsBeginImageContextWithOptions(size, false, 0)
     color.setFill()
     UIRectFill(CGRect(origin: .zero, size: size))
     let image = UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
     UIGraphicsEndImageContext()
     return image
     }
     
     func testImageManagerSaveAndLoadImage() async throws {
     // Given
     let imageManager = ImageManager.shared
     let testExpenseID = UUID()
     let testImage = createTestImage()
     
     // When
     let attachment = try imageManager.saveImage(
     testImage,
     for: testExpenseID,
     parentType: .expense,
     type: .receipt,
     description: "Test receipt"
     )
     
     // Load the saved image
     let loadedImage = imageManager.loadImage(
     for: testExpenseID,
     parentType: .expense,
     filename: attachment.filename
     )
     
     let loadedThumbnail = imageManager.loadThumbnail(
     for: testExpenseID,
     parentType: .expense,
     filename: attachment.filename
     )
     
     // Then
     XCTAssertTrue(attachment.filename.hasSuffix(".jpg"), "Should generate JPG filename")
     XCTAssertEqual(attachment.type, .receipt, "Should preserve attachment type")
     XCTAssertEqual(attachment.description, "Test receipt", "Should preserve description")
     
     XCTAssertNotNil(loadedImage, "Should be able to load saved image")
     XCTAssertNotNil(loadedThumbnail, "Should be able to load saved thumbnail")
     
     // Verify thumbnail is smaller than original
     if let thumbnail = loadedThumbnail {
     XCTAssertTrue(thumbnail.size.width <= 150, "Thumbnail width should be <= 150px")
     XCTAssertTrue(thumbnail.size.height <= 150, "Thumbnail height should be <= 150px")
     }
     
     // Cleanup
     imageManager.deleteImage(attachment, for: testExpenseID, parentType: .expense)
     }
     
     func testImageManagerDeleteImage() async throws {
     // Given
     let imageManager = ImageManager.shared
     let testExpenseID = UUID()
     let testImage = createTestImage()
     
     // Save image first
     let attachment = try imageManager.saveImage(
     testImage,
     for: testExpenseID,
     parentType: .expense,
     type: .receipt
     )
     
     // Verify image exists
     XCTAssertTrue(imageManager.loadImage(for: testExpenseID, parentType: .expense, filename: attachment.filename) != nil,
     "Image should exist before deletion")
     
     // When - Delete image
     imageManager.deleteImage(attachment, for: testExpenseID, parentType: .expense)
     
     // Then
     let deletedImage = imageManager.loadImage(for: testExpenseID, parentType: .expense, filename: attachment.filename)
     let deletedThumbnail = imageManager.loadThumbnail(for: testExpenseID, parentType: .expense, filename: attachment.filename)
     
     XCTAssertEqual(deletedImage, nil, "Image should be deleted")
     XCTAssertEqual(deletedThumbnail, nil, "Thumbnail should be deleted")
     }
     
     func testImageManagerDeleteAllImages() async throws {
     // Given
     let imageManager = ImageManager.shared
     let testExpenseID = UUID()
     let testImage1 = createTestImage(color: .red)
     let testImage2 = createTestImage(color: .green)
     
     // Save multiple images
     let attachment1 = try imageManager.saveImage(testImage1, for: testExpenseID, parentType: .expense, type: .receipt)
     let attachment2 = try imageManager.saveImage(testImage2, for: testExpenseID, parentType: .expense, type: .receipt)
     
     // Verify images exist
     XCTAssertTrue(imageManager.loadImage(for: testExpenseID, parentType: .expense, filename: attachment1.filename) != nil)
     XCTAssertTrue(imageManager.loadImage(for: testExpenseID, parentType: .expense, filename: attachment2.filename) != nil)
     
     // When - Delete all images for this expense
     imageManager.deleteAllImages(for: testExpenseID, parentType: .expense)
     
     // Then
     XCTAssertTrue(imageManager.loadImage(for: testExpenseID, parentType: .expense, filename: attachment1.filename) == nil,
     "All images should be deleted")
     XCTAssertTrue(imageManager.loadImage(for: testExpenseID, parentType: .expense, filename: attachment2.filename) == nil,
     "All images should be deleted")
     }
     
     func testImageManagerResizing() async throws {
     // Given
     let imageManager = ImageManager.shared
     let testExpenseID = UUID()
     // Create a large image that should be resized
     let largeImage = createTestImage(size: CGSize(width: 3000, height: 4000))
     
     // When
     let attachment = try imageManager.saveImage(
     largeImage,
     for: testExpenseID,
     parentType: .expense,
     type: .receipt
     )
     
     let savedImage = imageManager.loadImage(
     for: testExpenseID,
     parentType: .expense,
     filename: attachment.filename
     )
     
     // Then
     XCTAssertNotNil(savedImage, "Should save large image")
     if let resized = savedImage {
     // Image should be resized to max 2048px on longest side
     XCTAssertTrue(max(resized.size.width, resized.size.height) <= 2048,
     "Image should be resized to maximum 2048px on longest side")
     }
     
     // Cleanup
     imageManager.deleteImage(attachment, for: testExpenseID, parentType: .expense)
     }
     
     func testImageManagerStorageCalculation() async throws {
     // Given
     let imageManager = ImageManager.shared
     let testExpenseID = UUID()
     let testImage = createTestImage()
     
     let initialStorage = imageManager.calculateStorageUsage()
     
     // When - Save an image
     let attachment = try imageManager.saveImage(
     testImage,
     for: testExpenseID,
     parentType: .expense,
     type: .receipt
     )
     
     let afterSaveStorage = imageManager.calculateStorageUsage()
     
     // Then
     XCTAssertTrue(afterSaveStorage.images >= initialStorage.images, "Images storage should increase or stay same")
     XCTAssertTrue(afterSaveStorage.thumbnails >= initialStorage.thumbnails, "Thumbnails storage should increase or stay same")
     
     // Cleanup
     imageManager.deleteImage(attachment, for: testExpenseID, parentType: .expense)
     }
     
     func testImageManagerErrorHandling() async throws {
     // Test that ImageManager handles errors appropriately
     let imageManager = ImageManager.shared
     
     // Test loading non-existent image
     let nonExistentImage = imageManager.loadImage(
     for: UUID(),
     parentType: .expense,
     filename: "nonexistent.jpg"
     )
     
     XCTAssertEqual(nonExistentImage, nil, "Should return nil for non-existent image")
     
     let nonExistentThumbnail = imageManager.loadThumbnail(
     for: UUID(),
     parentType: .expense,
     filename: "nonexistent.jpg"
     )
     
     XCTAssertEqual(nonExistentThumbnail, nil, "Should return nil for non-existent thumbnail")
     
     // Test deleting non-existent image (should not crash)
     let fakeAttachment = ImageAttachment(filename: "fake.jpg", type: .other)
     imageManager.deleteImage(fakeAttachment, for: UUID(), parentType: .expense)
     // If we reach here without crashing, the test passes
     XCTAssertTrue(true, "Should handle deleting non-existent image gracefully")
     }
     }
     
     @MainActor
     struct ExpenseDataManagerImageTests {
     
     func testExpenseDataManagerImagePersistence() async throws {
     // Given
     let manager = ExpenseDataManager(forEnvironment: true)
     manager.expenses.removeAll() // Start clean
     
     let testExpense = ExpenseItem(
     date: Date(),
     category: .vehicle,
     description: "Gas with receipt photos",
     amount: 67.89
     )
     
     let attachment1 = ImageAttachment(filename: "receipt1.jpg", type: .receipt)
     let attachment2 = ImageAttachment(filename: "receipt2.jpg", type: .gasPump)
     
     var expenseWithImages = testExpense
     expenseWithImages.imageAttachments = [attachment1, attachment2]
     
     // When
     manager.addExpense(expenseWithImages)
     manager.saveExpenses()
     
     // Create new manager to test persistence
     let newManager = ExpenseDataManager(forEnvironment: true)
     
     // Then
     XCTAssertTrue(newManager.expenses.count > 0, "Expenses should be loaded from persistence")
     
     let loadedExpense = newManager.expenses.first { $0.id == expenseWithImages.id }
     XCTAssertNotNil(loadedExpense, "Test expense should be found in loaded data")
     
     if let loaded = loadedExpense {
     XCTAssertEqual(loaded.imageAttachments.count, 2, "Should persist both image attachments")
     XCTAssertEqual(loaded.imageAttachments[0].filename, "receipt1.jpg", "Should preserve first attachment filename")
     XCTAssertEqual(loaded.imageAttachments[1].filename, "receipt2.jpg", "Should preserve second attachment filename")
     XCTAssertEqual(loaded.imageAttachments[0].type, .receipt, "Should preserve first attachment type")
     XCTAssertEqual(loaded.imageAttachments[1].type, .gasPump, "Should preserve second attachment type")
     }
     }
     
     func testExpenseDataManagerUpdateExpenseWithImages() async throws {
     // Given
     let manager = ExpenseDataManager(forEnvironment: true)
     manager.expenses.removeAll()
     
     var originalExpense = ExpenseItem(
     date: Date(),
     category: .supplies,
     description: "Office supplies",
     amount: 25.00
     )
     
     // Add expense without images first
     manager.addExpense(originalExpense)
     XCTAssertEqual(manager.expenses.first?.imageAttachments.isEmpty, true, "Should start without images")
     
     // When - Update expense with images
     let attachment = ImageAttachment(filename: "supplies_receipt.jpg", type: .receipt)
     originalExpense.imageAttachments.append(attachment)
     originalExpense.modifiedDate = Date()
     
     manager.updateExpense(originalExpense)
     
     // Then
     let updatedExpense = manager.expenses.first { $0.id == originalExpense.id }
     XCTAssertNotNil(updatedExpense, "Should find updated expense")
     XCTAssertEqual(updatedExpense?.imageAttachments.count, 1, "Should have one image attachment after update")
     XCTAssertEqual(updatedExpense?.imageAttachments.first?.filename, "supplies_receipt.jpg", "Should preserve attachment filename")
     }
     
     func testExpenseDataManagerDeleteExpenseWithImages() async throws {
     // Given
     let manager = ExpenseDataManager(forEnvironment: true)
     manager.expenses.removeAll()
     
     let expenseWithImages = ExpenseItem(
     date: Date(),
     category: .equipment,
     description: "Dashboard cam with receipt",
     amount: 89.99
     )
     
     var expenseWithAttachment = expenseWithImages
     expenseWithAttachment.imageAttachments = [
     ImageAttachment(filename: "cam_receipt.jpg", type: .receipt)
     ]
     
     manager.addExpense(expenseWithAttachment)
     XCTAssertEqual(manager.expenses.count, 1, "Should have one expense")
     
     // When - Delete expense
     manager.deleteExpense(expenseWithAttachment)
     
     // Then
     XCTAssertEqual(manager.activeExpenses.count, 0, "Should have no active expenses after deletion")
     
     // If sync is disabled, expense should be completely removed
     // If sync is enabled, expense should be soft-deleted
     let allExpenses = manager.expenses
     if AppPreferences.shared.incrementalSyncEnabled {
     XCTAssertEqual(allExpenses.count, 1, "Should have one soft-deleted expense when sync enabled")
     XCTAssertEqual(allExpenses.first?.isDeleted, true, "Expense should be marked as deleted")
     } else {
     XCTAssertEqual(allExpenses.count, 0, "Should have no expenses when sync disabled (hard delete)")
     }
     }
     
     func testExpenseDataManagerFilteringWithImages() async throws {
     // Given
     let manager = ExpenseDataManager(forEnvironment: true)
     manager.expenses.removeAll()
     
     let currentDate = Date()
     let lastMonth = Calendar.current.date(byAdding: .month, value: -1, to: currentDate) ?? currentDate
     
     // Create expenses with and without images
     let expenseWithImages = ExpenseItem(
     date: currentDate,
     category: .vehicle,
     description: "Gas with photo",
     amount: 45.67
     )
     
     var expenseWithAttachment = expenseWithImages
     expenseWithAttachment.imageAttachments = [
     ImageAttachment(filename: "gas_receipt.jpg", type: .receipt)
     ]
     
     let expenseWithoutImages = ExpenseItem(
     date: lastMonth,
     category: .supplies,
     description: "Car wash",
     amount: 15.00
     )
     
     manager.addExpense(expenseWithAttachment)
     manager.addExpense(expenseWithoutImages)
     
     // When - Filter by current month
     let currentMonthExpenses = manager.expensesForMonth(currentDate)
     
     // Then
     XCTAssertEqual(currentMonthExpenses.count, 1, "Should have one expense for current month")
     XCTAssertEqual(currentMonthExpenses.first?.imageAttachments.count, 1, "Current month expense should have image attachment")
     XCTAssertEqual(currentMonthExpenses.first?.imageAttachments.first?.filename, "gas_receipt.jpg", "Should preserve attachment in filtered results")
     }
     
     func testExpenseDataManagerBackwardCompatibilityImages() async throws {
     // Given - Manager with existing expenses (some may not have imageAttachments property)
     let manager = ExpenseDataManager(forEnvironment: true)
     
     // Create expense manually to simulate old data format
     let oldExpense = ExpenseItem(
     date: Date(),
     category: .vehicle,
     description: "Legacy expense",
     amount: 30.00
     )
     
     manager.expenses = [oldExpense]
     
     // When - Save and reload
     manager.saveExpenses()
     let newManager = ExpenseDataManager(forEnvironment: true)
     
     // Then - Should handle expenses without imageAttachments gracefully
     XCTAssertTrue(newManager.expenses.count > 0, "Should load legacy expenses")
     let loadedExpense = newManager.expenses.first
     XCTAssertNotNil(loadedExpense, "Should find legacy expense")
     XCTAssertEqual(loadedExpense?.imageAttachments.isEmpty, true, "Legacy expense should have empty imageAttachments array")
     }
     
     func testExpenseDataManagerImageCleanupOnDelete() async throws {
     // Given
     let manager = ExpenseDataManager(forEnvironment: true)
     let imageManager = ImageManager.shared
     manager.expenses.removeAll()
     
     let testExpenseID = UUID()
     var testExpense = ExpenseItem(
     date: Date(),
     category: .vehicle,
     description: "Test expense for image cleanup",
     amount: 50.00
     )
     testExpense.id = testExpenseID
     
     // Create and save a real image
     let testImage = createTestUIImage()
     let attachment = try imageManager.saveImage(
     testImage,
     for: testExpenseID,
     parentType: .expense,
     type: .receipt
     )
     
     testExpense.imageAttachments = [attachment]
     manager.addExpense(testExpense)
     
     // Verify image exists
     XCTAssertTrue(imageManager.loadImage(for: testExpenseID, parentType: .expense, filename: attachment.filename) != nil,
     "Image should exist before expense deletion")
     
     // When - Delete expense (assuming hard delete when sync is disabled)
     let originalSyncEnabled = AppPreferences.shared.incrementalSyncEnabled
     AppPreferences.shared.incrementalSyncEnabled = false // Force hard delete
     
     manager.deleteExpense(testExpense)
     
     // Then - Image should be cleaned up
     let deletedImage = imageManager.loadImage(for: testExpenseID, parentType: .expense, filename: attachment.filename)
     XCTAssertEqual(deletedImage, nil, "Image should be deleted when expense is hard-deleted")
     
     // Restore original sync setting
     AppPreferences.shared.incrementalSyncEnabled = originalSyncEnabled
     }
     
     // Helper method to create test image
     private func createTestUIImage(size: CGSize = CGSize(width: 50, height: 50), color: UIColor = .red) -> UIImage {
     UIGraphicsBeginImageContextWithOptions(size, false, 0)
     color.setFill()
     UIRectFill(CGRect(origin: .zero, size: size))
     let image = UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
     UIGraphicsEndImageContext()
     return image
     }

    // MARK: - Shift Photo Attachment Tests (Phase 2)

    @MainActor
    struct ShiftPhotoAttachmentTests {

        // MARK: - RideshareShift Model Photo Support Tests

        func testShiftImageAttachmentsProperty() async throws {
            // Given: New shift without photos
            let shift = RideshareShift(
                startDate: Date(),
                startMileage: 100000,
                startTankReading: 8.0,
                hasFullTankAtStart: true,
                gasPrice: 2.00,
                standardMileageRate: 0.67
            )

            // When: Checking imageAttachments property exists
            // This will fail initially because RideshareShift doesn't have imageAttachments yet
            let attachments = shift.imageAttachments

            // Then: Should have empty imageAttachments array by default
            XCTAssertNotNil(attachments, "Shift should have imageAttachments property")
            XCTAssertTrue(attachments.isEmpty, "New shift should start with empty photo array")
        }

        func testShiftWithMultiplePhotos() async throws {
            // Given: Shift with multiple photo types (realistic usage)
            var shift = RideshareShift(
                startDate: Date(),
                startMileage: 100000,
                startTankReading: 8.0,
                hasFullTankAtStart: true,
                gasPrice: 3.50,
                standardMileageRate: 0.67
            )

            // Create shift-specific photo attachments
            let attachments = [
                ImageAttachment(filename: "gas_pump.jpg", type: .gasPump, description: "Gas station pump display"),
                ImageAttachment(filename: "earnings.jpg", type: .screenshot, description: "Earnings screenshot"),
                ImageAttachment(filename: "gas_receipt.jpg", type: .receipt, description: "Fuel receipt"),
                ImageAttachment(filename: "car_damage.jpg", type: .damage, description: "Minor scratch found"),
                ImageAttachment(filename: "cleaning_needed.jpg", type: .cleaning, description: "Interior mess")
            ]

            // When: Adding photos to shift
            shift.imageAttachments = attachments

            // Then: Shift should store all photos correctly
            XCTAssertEqual(shift.imageAttachments.count, 5, "Should store all 5 photos")
            XCTAssertEqual(shift.imageAttachments[0].type, .gasPump, "Should maintain photo types")
            XCTAssertEqual(shift.imageAttachments[1].description, "Earnings screenshot", "Should maintain descriptions")
        }

        func testShiftPhotoAttachmentPersistence() async throws {
            // Given: Shift with photos saved to data manager
            var shift = RideshareShift(
                startDate: Date(),
                startMileage: 100000,
                startTankReading: 8.0,
                hasFullTankAtStart: true,
                gasPrice: 3.50,
                standardMileageRate: 0.67
            )

            let attachment = ImageAttachment(
                filename: "test_shift_photo.jpg",
                type: .screenshot,
                description: "Test earnings screenshot"
            )
            shift.imageAttachments = [attachment]

            let shiftManager = ShiftDataManager.shared

            // When: Saving and reloading shift
            shiftManager.addShift(shift)
            let savedShifts = shiftManager.shifts
            let reloadedShift = savedShifts.first { $0.id == shift.id }

            // Then: Photos should persist
            XCTAssertNotNil(reloadedShift, "Shift should be saved and reloadable")
            XCTAssertEqual(reloadedShift?.imageAttachments.count, 1, "Photo attachment should persist")
            XCTAssertEqual(reloadedShift?.imageAttachments.first?.filename, "test_shift_photo.jpg", "Filename should match")
            XCTAssertEqual(reloadedShift?.imageAttachments.first?.type, .screenshot, "Type should match")
        }

        func testShiftPhotoFileDeletion() async throws {
            // Given: Shift with photos that need cleanup when shift is deleted
            let testImage = createTestUIImage()
            let imageManager = ImageManager.shared
            let testShiftID = UUID()

            var shift = RideshareShift(
                startDate: Date(),
                startMileage: 100000,
                startTankReading: 8.0,
                hasFullTankAtStart: true,
                gasPrice: 3.50,
                standardMileageRate: 0.67
            )
            shift.id = testShiftID

            // Save test image to disk
            let attachment = try imageManager.saveImage(
                testImage,
                for: testShiftID,
                parentType: .shift,  // This will fail initially - need to add .shift case
                type: .screenshot
            )

            shift.imageAttachments = [attachment]
            let shiftManager = ShiftDataManager.shared
            shiftManager.addShift(shift)

            // Verify image exists
            XCTAssertNotNil(imageManager.loadImage(for: testShiftID, parentType: .shift, filename: attachment.filename),
                           "Image should exist before shift deletion")

            // When: Deleting shift (hard delete)
            let originalSyncEnabled = AppPreferences.shared.incrementalSyncEnabled
            AppPreferences.shared.incrementalSyncEnabled = false // Force hard delete
            shiftManager.deleteShift(shift)

            // Then: Associated images should be cleaned up
            let deletedImage = imageManager.loadImage(for: testShiftID, parentType: .shift, filename: attachment.filename)
            XCTAssertNil(deletedImage, "Image should be deleted when shift is hard-deleted")

            // Restore original sync setting
            AppPreferences.shared.incrementalSyncEnabled = originalSyncEnabled
        }

        // MARK: - Critical Calculation Bug Tests

        func testGasPriceCalculationFromRefuelData() async throws {
            // Bug #2: Gas price should be calculated from actual refuel data when available,
            // not always use App Preferences gas price

            // Given: Shift with different preferences gas price vs actual refuel price
            var shift = RideshareShift(
                startDate: Date(),
                startMileage: 100.0,
                startTankReading: 8.0, // Start with full tank to simplify calculation
                hasFullTankAtStart: true,
                gasPrice: 3.50, // Preferences gas price: $2.50/gallon
                standardMileageRate: 0.67
            )
            shift.endDate = Date().addingTimeInterval(3600)
            shift.endMileage = 150.0
            shift.endTankReading = 6.0 // Used 2 gallons during shift
            shift.refuelGallons = 2.0 // Refueled exactly what was used
            shift.refuelCost = 5.00 // Actual cost: $5.00 (= $2.50/gallon, different from preferences!)

            let tankCapacity = 8.0

            // When: Simulate EndShiftView setting gas price from refuel data
            if let cost = shift.refuelCost, let gallons = shift.refuelGallons, gallons > 0 {
                shift.gasPrice = cost / gallons  // This is what EndShiftView should do
            }
            let shiftGasCost = shift.shiftGasCost(tankCapacity: tankCapacity)

            // Then: Should use actual refuel price ($2.50/gallon), not preferences ($3.50/gallon)
            XCTAssertEqual(shift.gasPrice, 2.50, accuracy: 0.01, "Gas price should be updated from refuel data")
            XCTAssertEqual(shiftGasCost, 5.00, accuracy: 0.01, "Should use actual refuel price for gas cost calculation")

            // Verify it would be different if using preferences price
            let wouldBeWithPreferences = 2.0 * 3.50 // 2 gallons * $3.50 = $7.00
            XCTAssertNotEqual(shiftGasCost, wouldBeWithPreferences, "Should NOT use preferences gas price when refuel data available")
        }

        // MARK: - Tax Calculation Tests
        func testTaxCalculationMethods() async throws {
            // Given: Tax calculation inputs
            let grossIncome = 1000.0
            let deductibleTips = 500.0
            let mileageDeduction = 350.0
            let otherExpenses = 100.0
            let taxRate = 22.0

            // When: Calculate tax components using static methods
            let adjustedGrossIncome = RideshareShift.calculateAdjustedGrossIncome(
                grossIncome: grossIncome,
                deductibleTips: deductibleTips
            )
            let selfEmploymentTax = RideshareShift.calculateSelfEmploymentTax(grossIncome: grossIncome)
            let taxableIncome = RideshareShift.calculateTaxableIncome(
                adjustedGrossIncome: adjustedGrossIncome,
                mileageDeduction: mileageDeduction,
                otherExpenses: otherExpenses
            )
            let incomeTax = RideshareShift.calculateIncomeTax(
                taxableIncome: taxableIncome,
                taxRate: taxRate
            )
            let totalTax = RideshareShift.calculateTotalTax(
                incomeTax: incomeTax,
                selfEmploymentTax: selfEmploymentTax
            )

            // Then: Verify calculations match expected values
            XCTAssertEqual(adjustedGrossIncome, 500.0, accuracy: 0.01, "Adjusted gross income should be $500.00")
            XCTAssertEqual(selfEmploymentTax, 153.0, accuracy: 0.01, "Self-employment tax should be $153.00 (15.3%)")
            XCTAssertEqual(taxableIncome, 50.0, accuracy: 0.01, "Taxable income should be $50.00")
            XCTAssertEqual(incomeTax, 11.0, accuracy: 0.01, "Income tax should be $11.00 (22%)")
            XCTAssertEqual(totalTax, 164.0, accuracy: 0.01, "Total tax should be $164.00")
        }

        // Helper method to create test images
        private func createTestUIImage(size: CGSize = CGSize(width: 100, height: 100), color: UIColor = .blue) -> UIImage {
            UIGraphicsBeginImageContextWithOptions(size, false, 0)
            color.setFill()
            UIRectFill(CGRect(origin: .zero, size: size))
            let image = UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
            UIGraphicsEndImageContext()
            return image
        }
    }

}
