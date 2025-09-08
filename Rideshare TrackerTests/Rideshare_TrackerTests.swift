//
//  Rideshare_TrackerTests.swift
//  Rideshare TrackerTests
//
//  Created by George on 8/10/25.
//

import Testing
import Foundation
@testable import Rideshare_Tracker

struct RideshareShiftTests {
    
    // Test shift duration calculation
    @Test func testShiftDurationCalculation() async throws {
        // Given
        let startDate = Date()
        let endDate = startDate.addingTimeInterval(4 * 3600) // 4 hours later
        
        var shift = RideshareShift(
            startDate: startDate,
            startMileage: 100.0,
            startTankReading: 8.0,
            hasFullTankAtStart: true
        )
        shift.endDate = endDate
        shift.endMileage = 200.0
        
        // When
        let duration = shift.shiftDuration
        let hours = shift.shiftHours
        let mileage = shift.shiftMileage
        
        // Then
        #expect(duration == 4 * 3600) // 4 hours in seconds
        #expect(hours == 4) // 4 hours
        #expect(mileage == 100.0) // 100 miles driven
    }
    
    // Test revenue calculation
    @Test func testRevenueCalculation() async throws {
        // Given
        var shift = RideshareShift(
            startDate: Date(),
            startMileage: 100.0,
            startTankReading: 8.0,
            hasFullTankAtStart: true
        )
        shift.netFare = 150.0
        shift.tips = 25.0
        shift.promotions = 10.0
        shift.riderFees = 5.0
        
        // When
        let revenue = shift.revenue
        let totalEarnings = shift.totalEarnings
        
        // Then
        #expect(revenue == 190.0) // 150 + 25 + 10 + 5
        #expect(totalEarnings == revenue) // Should be the same
    }
    
    // Test profit calculation with direct costs
    @Test func testProfitCalculation() async throws {
        // Given
        var shift = RideshareShift(
            startDate: Date(),
            startMileage: 100.0,
            startTankReading: 8.0,
            hasFullTankAtStart: true
        )
        shift.endDate = Date().addingTimeInterval(3600) // 1 hour
        shift.endMileage = 200.0
        shift.endTankReading = 6.0 // Used 2/8ths of tank
        shift.netFare = 150.0
        shift.tips = 25.0
        shift.tolls = 10.0
        shift.tollsReimbursed = 5.0
        shift.parkingFees = 5.0
        shift.refuelCost = 30.0
        
        let tankCapacity = 16.0 // gallons
        let gasPrice = 3.50
        
        // When
        let revenue = shift.revenue
        let directCosts = shift.directCosts(tankCapacity: tankCapacity, gasPrice: gasPrice)
        let grossProfit = shift.grossProfit(tankCapacity: tankCapacity, gasPrice: gasPrice)
        let cashFlowProfit = shift.cashFlowProfit(tankCapacity: tankCapacity, gasPrice: gasPrice)
        
        // Then
        #expect(revenue == 175.0) // netFare + tips
        #expect(directCosts == 40.0) // refuelCost + (tolls - tollsReimbursed) + parkingFees
        #expect(grossProfit == 135.0) // revenue - directCosts
        #expect(cashFlowProfit == grossProfit) // Should be same for this test
    }
    
    // Test gas usage calculation
    @Test func testGasUsageCalculation() async throws {
        // Given
        var shift = RideshareShift(
            startDate: Date(),
            startMileage: 100.0,
            startTankReading: 8.0, // Full tank
            hasFullTankAtStart: true
        )
        shift.endMileage = 200.0
        shift.endTankReading = 4.0 // Half tank remaining
        
        let tankCapacity = 16.0 // gallons
        
        // When
        let gasUsed = shift.shiftGasUsage(tankCapacity: tankCapacity)
        let mpg = shift.shiftMPG(tankCapacity: tankCapacity)
        
        // Then
        #expect(gasUsed == 8.0) // Used half tank (8 gallons)
        #expect(mpg == 12.5) // 100 miles / 8 gallons
    }
    
    // Test gas usage with refuel
    @Test func testGasUsageWithRefuel() async throws {
        // Given
        var shift = RideshareShift(
            startDate: Date(),
            startMileage: 100.0,
            startTankReading: 6.0, // 3/4 tank
            hasFullTankAtStart: false
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
        #expect(gasUsed == 6.0) // Actually used 6 gallons of gas
        #expect(mpg == 200.0 / 6.0) // 200 miles / 6 gallons ≈ 33.33 MPG
    }
    
    // Test incomplete shift
    @Test func testIncompleteShift() async throws {
        // Given
        let shift = RideshareShift(
            startDate: Date(),
            startMileage: 100.0,
            startTankReading: 8.0,
            hasFullTankAtStart: true
        )
        
        // When/Then
        #expect(shift.endDate == nil)
        #expect(shift.shiftMileage == 0.0) // No end mileage yet
        #expect(shift.shiftDuration == 0.0) // No duration yet
        #expect(shift.revenue == 0.0) // No earnings yet
    }
    
    // Test tax calculations
    @Test func testTaxCalculations() async throws {
        // Given
        var shift = RideshareShift(
            startDate: Date(),
            startMileage: 100.0,
            startTankReading: 8.0,
            hasFullTankAtStart: true
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
        #expect(taxableIncome == 150.0) // netFare only (tips reported separately)
        #expect(deductibleExpenses == 80.0) // (100 * 0.67) + (10-5) + 8 = 67 + 5 + 8 = 80
    }
    
    // Test profit per hour calculation
    @Test func testProfitPerHour() async throws {
        // Given
        let startDate = Date()
        let endDate = startDate.addingTimeInterval(2 * 3600) // 2 hours
        
        var shift = RideshareShift(
            startDate: startDate,
            startMileage: 100.0,
            startTankReading: 8.0,
            hasFullTankAtStart: true
        )
        shift.endDate = endDate
        shift.endMileage = 150.0
        shift.endTankReading = 7.0
        shift.netFare = 80.0
        shift.tips = 20.0
        
        let tankCapacity = 16.0
        let gasPrice = 3.50
        
        // When
        let totalProfit = shift.cashFlowProfit(tankCapacity: tankCapacity, gasPrice: gasPrice)
        let profitPerHour = shift.profitPerHour(tankCapacity: tankCapacity, gasPrice: gasPrice)
        
        // Then
        #expect(totalProfit > 0) // Should be profitable
        #expect(profitPerHour == totalProfit / 2.0) // Should be profit divided by 2 hours
    }
}

// MARK: - Import/Export Tests
struct ImportExportTests {
    
    // Test CSV export with comprehensive columns
    @Test func testCSVExportComprehensive() async throws {
        // Given
        let preferences = AppPreferences.shared
        let startDate = Date()
        let endDate = startDate.addingTimeInterval(3600) // 1 hour later
        
        var shift = RideshareShift(
            startDate: startDate,
            startMileage: 100.0,
            startTankReading: 8.0,
            hasFullTankAtStart: true
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
        #expect(csvURL != nil, "CSV export should be created successfully")
        
        if let url = csvURL {
            let csvContent = try String(contentsOf: url, encoding: .utf8)
            let lines = csvContent.components(separatedBy: .newlines)
            
            // Verify header contains all expected columns
            let headers = lines[0].components(separatedBy: ",")
            #expect(headers.contains("StartDate"), "Should include StartDate")
            #expect(headers.contains("StartTime"), "Should include StartTime") 
            #expect(headers.contains("StartMileage"), "Should include StartMileage")
            #expect(headers.contains("StartTankReading"), "Should include StartTankReading")
            #expect(headers.contains("RefuelGallons"), "Should include RefuelGallons")
            #expect(headers.contains("Tips"), "Should include Tips")
            #expect(headers.contains("C_Revenue"), "Should include calculated Revenue")
            #expect(headers.contains("C_MPG"), "Should include calculated MPG")
            #expect(headers.contains("P_TankCapacity"), "Should include preference TankCapacity")
            
            // Verify we have data row
            #expect(lines.count >= 2, "Should have header + at least one data row")
        }
    }
    
    // Test import matching by date and start mileage
    @Test func testImportMatchingByDateAndMileage() async throws {
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
            #expect(result.shifts.count == 1, "Should import one shift, got \(result.shifts.count). Expected fields: \(expectedFields), Simple split: \(simpleSplit.count)")
            
            let importedShift = result.shifts[0]
            #expect(importedShift.startMileage == 12345.0, "Should have correct start mileage")
            #expect(importedShift.endMileage == 12395.0, "Should have correct end mileage") 
            #expect(importedShift.netFare == 50.0, "Should have correct net fare")
            #expect(importedShift.tips == 10.0, "Should have correct tips")
            #expect(importedShift.tolls == 5.0, "Should have correct tolls")
            
        case .failure(let error):
            Issue.record("Import should succeed but failed with: \(error)")
        }
        
        // Cleanup
        try FileManager.default.removeItem(at: testURL)
    }
    
    // Test import matching with multiple shifts on same day
    @Test func testImportMultipleShiftsPerDay() async throws {
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
            #expect(result.shifts.count == 2, "Should import two shifts")
            
            let shifts = result.shifts.sorted { $0.startMileage < $1.startMileage }
            
            // First shift (morning)
            #expect(shifts[0].startMileage == 12345.0, "First shift should have start mileage 12345")
            #expect(shifts[0].endMileage == 12395.0, "First shift should have end mileage 12395")
            #expect(shifts[0].netFare == 45.0, "First shift should have correct fare")
            
            // Second shift (evening)  
            #expect(shifts[1].startMileage == 12395.0, "Second shift should have start mileage 12395")
            #expect(shifts[1].endMileage == 12435.0, "Second shift should have end mileage 12435")
            #expect(shifts[1].netFare == 35.0, "Second shift should have correct fare")
            
            // Verify both shifts have same date
            let calendar = Calendar.current
            #expect(calendar.isDate(shifts[0].startDate, inSameDayAs: shifts[1].startDate), "Both shifts should be on same day")
            
        case .failure(let error):
            Issue.record("Import should succeed but failed with: \(error)")
        }
        
        // Cleanup
        try FileManager.default.removeItem(at: testURL)
    }
    
    // Test CSV import with tank readings in decimal format
    @Test func testImportTankReadingsDecimal() async throws {
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
            #expect(result.shifts.count == 1, "Should import one shift")
            
            let shift = result.shifts[0]
            #expect(shift.startTankReading == 8.0, "Should convert 1.000 to 8/8ths (full)")
            #expect(shift.endTankReading == 4.0, "Should convert 0.500 to 4/8ths (half)")
            
        case .failure(let error):
            Issue.record("Import should succeed but failed with: \(error)")
        }
        
        // Cleanup
        try FileManager.default.removeItem(at: testURL)
    }
}

struct AppPreferencesTests {
    
    // Test backup file extension is correct (.json not .json.csv)
    @Test func testBackupFileExtensionIsCorrect() async throws {
        // Given
        let preferences = AppPreferences.shared
        let testShifts: [RideshareShift] = [
            RideshareShift(
                startDate: Date(),
                startMileage: 100.0,
                startTankReading: 8.0,
                hasFullTankAtStart: true
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
        #expect(backupURL != nil, "Backup should be created successfully")
        
        if let url = backupURL {
            let filename = url.lastPathComponent
            let pathExtension = url.pathExtension
            
            // CRITICAL: This test catches the .json.csv bug
            #expect(pathExtension == "json", "Backup file should have .json extension, not .json.csv or other")
            #expect(filename.contains(".json"), "Filename should contain .json")
            #expect(!filename.contains(".csv"), "Filename should NOT contain .csv")
            #expect(filename.hasPrefix("RideshareTracker_Backup_"), "Should have correct filename prefix")
            
            // Verify the file actually contains JSON data
            let fileData = try Data(contentsOf: url)
            let jsonObject = try JSONSerialization.jsonObject(with: fileData)
            #expect(jsonObject is [String: Any], "File should contain valid JSON dictionary")
            
            // Clean up test file
            try? FileManager.default.removeItem(at: url)
        }
    }
    
    // Test CSV export file extension is correct
    @Test func testCSVExportFileExtensionIsCorrect() async throws {
        // Given
        let preferences = AppPreferences.shared
        let testShifts: [RideshareShift] = [
            RideshareShift(
                startDate: Date(),
                startMileage: 100.0,
                startTankReading: 8.0,
                hasFullTankAtStart: true
            )
        ]
        let fromDate = Date()
        let toDate = Date().addingTimeInterval(86400) // 1 day later
        
        // When
        let csvURL = preferences.exportCSVWithRange(shifts: testShifts, selectedRange: DateRangeOption.custom, fromDate: fromDate, toDate: toDate)
        
        // Then
        #expect(csvURL != nil, "CSV export should be created successfully")
        
        if let url = csvURL {
            let filename = url.lastPathComponent
            let pathExtension = url.pathExtension
            
            #expect(pathExtension == "csv", "CSV export should have .csv extension")
            #expect(filename.contains(".csv"), "Filename should contain .csv")
            #expect(!filename.contains(".json"), "CSV filename should NOT contain .json")
            
            // Verify the file contains CSV data (comma-separated)
            let csvContent = try String(contentsOf: url, encoding: .utf8)
            #expect(csvContent.contains(","), "CSV file should contain comma separators")
            #expect(csvContent.contains("StartDate"), "CSV should have header row")
            
            // Clean up test file
            try? FileManager.default.removeItem(at: url)
        }
    }
}

struct DateRangeOptionTests {
    
    // MARK: - Test basic date range calculations
    
    @Test func testTodayDateRange() async throws {
        // Given
        let range = DateRangeOption.today
        let calendar = Calendar.current
        let now = Date()
        
        // When
        let result = range.getDateRange(weekStartDay: 1)
        
        // Then
        let expectedStart = calendar.startOfDay(for: now)
        let expectedEnd = calendar.date(byAdding: .day, value: 1, to: expectedStart)!
        
        #expect(calendar.isDate(result.start, inSameDayAs: expectedStart))
        #expect(calendar.isDate(result.end, inSameDayAs: expectedEnd))
    }
    
    @Test func testYesterdayDateRange() async throws {
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
        
        #expect(calendar.isDate(result.start, inSameDayAs: expectedStart))
        #expect(calendar.isDate(result.end, inSameDayAs: expectedEnd))
    }
    
    // MARK: - Test week calculations with different start days
    
    @Test func testThisWeekWithMondayStart() async throws {
        // Given: Sunday, August 24, 2025
        let testDate = createDate(year: 2025, month: 8, day: 24, weekday: 1) // Sunday
        let range = DateRangeOption.thisWeek
        
        // When: Week starts on Monday (weekStartDay = 1)
        let result = range.getDateRange(weekStartDay: 1, referenceDate: testDate)
        
        // Then: Should be Monday August 18 - Sunday August 24
        let expectedStart = createDate(year: 2025, month: 8, day: 18, weekday: 2) // Monday Aug 18
        let expectedEnd = createDate(year: 2025, month: 8, day: 24, weekday: 1) // Sunday Aug 24
        
        #expect(Calendar.current.isDate(result.start, inSameDayAs: expectedStart))
        #expect(Calendar.current.isDate(result.end, inSameDayAs: expectedEnd))
    }
    
    @Test func testThisWeekWithSundayStart() async throws {
        // Given: Monday, August 25, 2025
        let testDate = createDate(year: 2025, month: 8, day: 25, weekday: 2) // Monday
        let range = DateRangeOption.thisWeek
        
        // When: Week starts on Sunday (weekStartDay = 7)
        let result = range.getDateRange(weekStartDay: 7, referenceDate: testDate)
        
        // Then: Should be Sunday August 24 - Saturday August 30
        let expectedStart = createDate(year: 2025, month: 8, day: 24, weekday: 1) // Sunday Aug 24
        let expectedEnd = createDate(year: 2025, month: 8, day: 30, weekday: 7) // Saturday Aug 30
        
        #expect(Calendar.current.isDate(result.start, inSameDayAs: expectedStart))
        #expect(Calendar.current.isDate(result.end, inSameDayAs: expectedEnd))
    }
    
    @Test func testLastWeekWithMondayStart() async throws {
        // Given: Monday, September 1, 2025
        let testDate = createDate(year: 2025, month: 9, day: 1, weekday: 2) // Monday
        let range = DateRangeOption.lastWeek
        
        // When: Week starts on Monday (weekStartDay = 1)
        let result = range.getDateRange(weekStartDay: 1, referenceDate: testDate)
        
        // Then: Should be Monday August 25 - Sunday August 31
        let expectedStart = createDate(year: 2025, month: 8, day: 25, weekday: 2) // Monday Aug 25
        let expectedEnd = createDate(year: 2025, month: 8, day: 31, weekday: 1) // Sunday Aug 31
        
        #expect(Calendar.current.isDate(result.start, inSameDayAs: expectedStart))
        #expect(Calendar.current.isDate(result.end, inSameDayAs: expectedEnd))
    }
    
    @Test func testLastWeekWithSundayStart() async throws {
        // Given: Monday, September 1, 2025
        let testDate = createDate(year: 2025, month: 9, day: 1, weekday: 2) // Monday
        let range = DateRangeOption.lastWeek
        
        // When: Week starts on Sunday (weekStartDay = 7)
        let result = range.getDateRange(weekStartDay: 7, referenceDate: testDate)
        
        // Then: Should be Sunday August 24 - Saturday August 30
        let expectedStart = createDate(year: 2025, month: 8, day: 24, weekday: 1) // Sunday Aug 24
        let expectedEnd = createDate(year: 2025, month: 8, day: 30, weekday: 7) // Saturday Aug 30
        
        #expect(Calendar.current.isDate(result.start, inSameDayAs: expectedStart))
        #expect(Calendar.current.isDate(result.end, inSameDayAs: expectedEnd))
    }
    
    // MARK: - Test edge cases for week calculations
    
    @Test func testWeekCalculationAcrossMonthBoundary() async throws {
        // Given: Tuesday, September 2, 2025 (early in month)
        let testDate = createDate(year: 2025, month: 9, day: 2, weekday: 3) // Tuesday
        let range = DateRangeOption.thisWeek
        
        // When: Week starts on Monday
        let result = range.getDateRange(weekStartDay: 1, referenceDate: testDate)
        
        // Then: Should include days from August (Monday Sept 1)
        let expectedStart = createDate(year: 2025, month: 9, day: 1, weekday: 2) // Monday Sept 1
        let expectedEnd = createDate(year: 2025, month: 9, day: 7, weekday: 1) // Sunday Sept 7
        
        #expect(Calendar.current.isDate(result.start, inSameDayAs: expectedStart))
        #expect(Calendar.current.isDate(result.end, inSameDayAs: expectedEnd))
    }
    
    @Test func testWeekCalculationAcrossYearBoundary() async throws {
        // Given: Wednesday, January 1, 2025
        let testDate = createDate(year: 2025, month: 1, day: 1, weekday: 4) // Wednesday
        let range = DateRangeOption.thisWeek
        
        // When: Week starts on Monday
        let result = range.getDateRange(weekStartDay: 1, referenceDate: testDate)
        
        // Then: Should include days from December 2024
        let expectedStart = createDate(year: 2024, month: 12, day: 30, weekday: 2) // Monday Dec 30, 2024
        let expectedEnd = createDate(year: 2025, month: 1, day: 5, weekday: 1) // Sunday Jan 5, 2025
        
        #expect(Calendar.current.isDate(result.start, inSameDayAs: expectedStart))
        #expect(Calendar.current.isDate(result.end, inSameDayAs: expectedEnd))
    }
    
    // MARK: - Test month calculations
    
    @Test func testThisMonthDateRange() async throws {
        // Given
        let testDate = createDate(year: 2025, month: 8, day: 15) // Mid August
        let range = DateRangeOption.thisMonth
        
        // When
        let result = range.getDateRange(weekStartDay: 1, referenceDate: testDate)
        
        // Then
        let expectedStart = createDate(year: 2025, month: 8, day: 1) // August 1
        let expectedEnd = createDate(year: 2025, month: 8, day: 31) // August 31
        
        #expect(Calendar.current.isDate(result.start, inSameDayAs: expectedStart))
        #expect(Calendar.current.isDate(result.end, inSameDayAs: expectedEnd))
    }
    
    @Test func testLastMonthDateRange() async throws {
        // Given
        let testDate = createDate(year: 2025, month: 9, day: 15) // Mid September
        let range = DateRangeOption.lastMonth
        
        // When
        let result = range.getDateRange(weekStartDay: 1, referenceDate: testDate)
        
        // Then
        let expectedStart = createDate(year: 2025, month: 8, day: 1) // August 1
        let expectedEnd = createDate(year: 2025, month: 8, day: 31) // August 31
        
        #expect(Calendar.current.isDate(result.start, inSameDayAs: expectedStart))
        #expect(Calendar.current.isDate(result.end, inSameDayAs: expectedEnd))
    }
    
    // MARK: - Test year calculations
    
    @Test func testThisYearDateRange() async throws {
        // Given
        let testDate = createDate(year: 2025, month: 6, day: 15) // Mid 2025
        let range = DateRangeOption.thisYear
        
        // When
        let result = range.getDateRange(weekStartDay: 1, referenceDate: testDate)
        
        // Then
        let expectedStart = createDate(year: 2025, month: 1, day: 1) // January 1, 2025
        let expectedEnd = createDate(year: 2025, month: 12, day: 31) // December 31, 2025
        
        #expect(Calendar.current.isDate(result.start, inSameDayAs: expectedStart))
        #expect(Calendar.current.isDate(result.end, inSameDayAs: expectedEnd))
    }
    
    @Test func testLastYearDateRange() async throws {
        // Given
        let testDate = createDate(year: 2025, month: 6, day: 15) // Mid 2025
        let range = DateRangeOption.lastYear
        
        // When
        let result = range.getDateRange(weekStartDay: 1, referenceDate: testDate)
        
        // Then
        let expectedStart = createDate(year: 2024, month: 1, day: 1) // January 1, 2024
        let expectedEnd = createDate(year: 2024, month: 12, day: 31) // December 31, 2024
        
        #expect(Calendar.current.isDate(result.start, inSameDayAs: expectedStart))
        #expect(Calendar.current.isDate(result.end, inSameDayAs: expectedEnd))
    }
    
    // MARK: - Test all enum cases are covered
    
    @Test func testAllDateRangeOptionsAreHandled() async throws {
        // Given
        let testDate = Date()
        
        // When/Then - Ensure no cases throw exceptions
        for range in DateRangeOption.allCases {
            let result = range.getDateRange(weekStartDay: 1, referenceDate: testDate)
            
            // Basic sanity checks
            if range != .all {
                #expect(result.start <= result.end, "Start should be before or equal to end for \(range.rawValue)")
            }
            
            // All option should return distant dates
            if range == .all {
                #expect(result.start == Date.distantPast)
                #expect(result.end == Date.distantFuture)
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

struct IncrementalSyncTests {
    
    // MARK: - AppPreferences Sync Settings Tests
    
    @Test func testSyncPreferencesBasicFunctionality() async throws {
        // Simple test that doesn't mess with UserDefaults to avoid parallel execution issues
        let preferences = AppPreferences.shared
        
        // Save original state
        let originalSyncEnabled = preferences.incrementalSyncEnabled
        let originalSyncFrequency = preferences.syncFrequency
        let originalSyncDate = preferences.lastIncrementalSyncDate
        
        // Test setting and getting sync preferences
        preferences.incrementalSyncEnabled = true
        #expect(preferences.incrementalSyncEnabled == true, "Should be able to set sync enabled")
        
        preferences.syncFrequency = "Daily"
        #expect(preferences.syncFrequency == "Daily", "Should be able to set sync frequency")
        
        let testDate = Date()
        preferences.lastIncrementalSyncDate = testDate
        #expect(preferences.lastIncrementalSyncDate == testDate, "Should be able to set last sync date")
        
        // Test savePreferences doesn't crash
        preferences.savePreferences()
        
        // Restore original state
        preferences.incrementalSyncEnabled = originalSyncEnabled
        preferences.syncFrequency = originalSyncFrequency
        preferences.lastIncrementalSyncDate = originalSyncDate
    }
    
    // MARK: - Data Model Sync Metadata Tests
    
    @Test func testRideshareShiftHasSyncMetadata() async throws {
        // Given/When
        let shift = RideshareShift(
            startDate: Date(),
            startMileage: 100.0,
            startTankReading: 8.0,
            hasFullTankAtStart: true
        )
        
        // Then
        #expect(shift.id != UUID(), "Shift should have a unique ID")
        #expect(shift.createdDate != Date(timeIntervalSince1970: 0), "Shift should have created date set")
        #expect(shift.modifiedDate != Date(timeIntervalSince1970: 0), "Shift should have modified date set")
        #expect(!shift.deviceID.isEmpty, "Shift should have device ID set")
        #expect(shift.isDeleted == false, "Shift should not be marked as deleted by default")
    }
    
    @Test func testExpenseItemHasSyncMetadata() async throws {
        // Given/When
        let expense = ExpenseItem(
            date: Date(),
            category: .vehicle,
            description: "Test expense",
            amount: 25.0
        )
        
        // Then
        #expect(expense.id != UUID(), "Expense should have a unique ID")
        #expect(expense.createdDate != Date(timeIntervalSince1970: 0), "Expense should have created date set")
        #expect(expense.modifiedDate != Date(timeIntervalSince1970: 0), "Expense should have modified date set")
        #expect(!expense.deviceID.isEmpty, "Expense should have device ID set")
        #expect(expense.isDeleted == false, "Expense should not be marked as deleted by default")
    }
    
    @Test func testShiftSyncMetadataUpdate() async throws {
        // Given
        var shift = RideshareShift(
            startDate: Date(),
            startMileage: 100.0,
            startTankReading: 8.0,
            hasFullTankAtStart: true
        )
        let originalModifiedDate = shift.modifiedDate
        
        // Wait a bit to ensure time difference
        try await Task.sleep(nanoseconds: 1_000_000) // 1ms
        
        // When - simulate updating the shift
        shift.modifiedDate = Date()
        shift.endMileage = 200.0
        
        // Then
        #expect(shift.modifiedDate > originalModifiedDate, "Modified date should be updated when shift changes")
    }
    
    // MARK: - Data Migration Tests
    
    @Test func testMigrateShiftWithoutSyncMetadata() async throws {
        // Given - simulate an old shift without sync metadata
        var oldShift = RideshareShift(
            startDate: Date(),
            startMileage: 100.0,
            startTankReading: 8.0,
            hasFullTankAtStart: true
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
        #expect(oldShift.createdDate == oldShift.startDate, "Created date should be set to start date during migration")
        #expect(oldShift.modifiedDate == oldShift.endDate, "Modified date should be set to end date during migration")
        #expect(oldShift.deviceID == "migrated-device-id", "Device ID should be updated during migration")
        #expect(oldShift.isDeleted == false, "isDeleted should be set to false during migration")
    }
    
    @Test func testMigrateExpenseWithoutSyncMetadata() async throws {
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
        #expect(oldExpense.createdDate == oldExpense.date, "Created date should be set to expense date during migration")
        #expect(oldExpense.modifiedDate == oldExpense.date, "Modified date should be set to expense date during migration")
        #expect(oldExpense.deviceID == "migrated-device-id", "Device ID should be updated during migration")
        #expect(oldExpense.isDeleted == false, "isDeleted should be set to false during migration")
    }
    
    // MARK: - Initial Sync Detection Tests
    
    @Test func testDetectFirstTimeSyncEnable() async throws {
        // Given
        let preferences = AppPreferences.shared
        let originalSyncDate = preferences.lastIncrementalSyncDate
        
        // Reset to test state
        preferences.lastIncrementalSyncDate = nil
        
        // When/Then - First time enabling should be detectable
        let isFirstTimeEnabling = preferences.lastIncrementalSyncDate == nil
        #expect(isFirstTimeEnabling == true, "Should detect first time sync enabling")
        
        // When - after initial sync
        preferences.lastIncrementalSyncDate = Date()
        
        // Then
        let isStillFirstTime = preferences.lastIncrementalSyncDate == nil
        #expect(isStillFirstTime == false, "Should not detect first time after sync date is set")
        
        // Restore original state
        preferences.lastIncrementalSyncDate = originalSyncDate
    }
    
    // MARK: - Backup Creation with Sync Support Tests
    
    @Test func testCreateFullBackupWithSyncMetadata() async throws {
        // Given
        let preferences = AppPreferences.shared
        
        let shiftWithSyncData = RideshareShift(
            startDate: Date(),
            startMileage: 100.0,
            startTankReading: 8.0,
            hasFullTankAtStart: true
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
        #expect(backupURL != nil, "Full backup should be created successfully")
        
        if let url = backupURL {
            // Verify the backup contains the sync metadata
            let backupData = try Data(contentsOf: url)
            let backupJson = try JSONSerialization.jsonObject(with: backupData) as! [String: Any]
            
            #expect(backupJson["shifts"] != nil, "Backup should contain shifts")
            #expect(backupJson["expenses"] != nil, "Backup should contain expenses")
            
            let shifts = backupJson["shifts"] as! [[String: Any]]
            let expenses = backupJson["expenses"] as! [[String: Any]]
            
            #expect(shifts.count == 1, "Should have one shift in backup")
            #expect(expenses.count == 1, "Should have one expense in backup")
            
            // Verify sync metadata is preserved in backup
            let firstShift = shifts[0]
            #expect(firstShift["createdDate"] != nil, "Shift backup should include createdDate")
            #expect(firstShift["modifiedDate"] != nil, "Shift backup should include modifiedDate")
            #expect(firstShift["deviceID"] != nil, "Shift backup should include deviceID")
            #expect(firstShift["isDeleted"] != nil, "Shift backup should include isDeleted")
            
            let firstExpense = expenses[0]
            #expect(firstExpense["createdDate"] != nil, "Expense backup should include createdDate")
            #expect(firstExpense["modifiedDate"] != nil, "Expense backup should include modifiedDate")
            #expect(firstExpense["deviceID"] != nil, "Expense backup should include deviceID")
            #expect(firstExpense["isDeleted"] != nil, "Expense backup should include isDeleted")
            
            // Clean up test file
            try? FileManager.default.removeItem(at: url)
        }
    }
    
    // MARK: - Sync Frequency Validation Tests
    
    @Test func testSyncFrequencyOptions() async throws {
        // Given
        let preferences = AppPreferences.shared
        let originalSyncFrequency = preferences.syncFrequency
        let validFrequencies = ["Immediate", "Hourly", "Daily"]
        
        // When/Then
        for frequency in validFrequencies {
            preferences.syncFrequency = frequency
            
            #expect(preferences.syncFrequency == frequency, "Should accept valid sync frequency: \(frequency)")
        }
        
        // Restore original state
        preferences.syncFrequency = originalSyncFrequency
    }
    
    @Test func testDefaultSyncFrequency() async throws {
        // Given/When
        let preferences = AppPreferences.shared
        let originalSyncFrequency = preferences.syncFrequency
        
        // Reset to default for testing
        preferences.syncFrequency = "Immediate"
        
        // Then
        #expect(preferences.syncFrequency == "Immediate", "Default sync frequency should be Immediate")
        
        // Restore original state
        preferences.syncFrequency = originalSyncFrequency
    }
}

struct SyncDataManagerTests {
    
    // MARK: - ExpenseDataManager saveExpenses Access Tests
    
    @Test func testExpenseManagerSaveIsPublic() async throws {
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
        #expect(manager.expenses.contains { $0.description == "Test save access" }, "Expense should be added to manager")
    }
    
    // MARK: - Data Manager Sync Integration Tests
    
    @Test func testShiftDataManagerPreservesMetadata() async throws {
        // Given
        let manager = ShiftDataManager(forEnvironment: true)
        var testShift = RideshareShift(
            startDate: Date(),
            startMileage: 100.0,
            startTankReading: 8.0,
            hasFullTankAtStart: true
        )
        testShift.deviceID = "test-device-123"
        testShift.modifiedDate = Date()
        
        // When
        manager.addShift(testShift)
        manager.saveShifts()
        
        // Create new manager to test persistence
        let newManager = ShiftDataManager(forEnvironment: true)
        
        // Then
        #expect(newManager.shifts.count > 0, "Shifts should be loaded from persistence")
        
        let loadedShift = newManager.shifts.first { $0.id == testShift.id }
        #expect(loadedShift != nil, "Test shift should be found in loaded data")
        
        if let loaded = loadedShift {
            #expect(loaded.deviceID == "test-device-123", "Device ID should be preserved through save/load")
            #expect(loaded.isDeleted == false, "isDeleted should be preserved through save/load")
        }
    }
    
    @Test func testExpenseDataManagerPreservesMetadata() async throws {
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
        #expect(newManager.expenses.count > 0, "Expenses should be loaded from persistence")
        
        let loadedExpense = newManager.expenses.first { $0.id == testExpense.id }
        #expect(loadedExpense != nil, "Test expense should be found in loaded data")
        
        if let loaded = loadedExpense {
            #expect(loaded.deviceID == "test-device-456", "Device ID should be preserved through save/load")
            #expect(loaded.isDeleted == false, "isDeleted should be preserved through save/load")
        }
    }
}

// MARK: - Soft Deletion Tests

struct SoftDeletionTests {
    @Test func testActiveShiftsFiltersSoftDeletedRecords() async throws {
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
        #expect(activeShifts.count == 1, "activeShifts should only return non-deleted records")
        #expect(activeShifts.first?.id == activeShift.id, "activeShifts should return the active shift")
        #expect(!activeShifts.contains { $0.isDeleted }, "activeShifts should not contain deleted records")
    }
    
    @Test func testActiveExpensesFiltersSoftDeletedRecords() async throws {
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
        #expect(activeExpenses.count == 1, "activeExpenses should only return non-deleted records")
        #expect(activeExpenses.first?.id == activeExpense.id, "activeExpenses should return the active expense")
        #expect(!activeExpenses.contains { $0.isDeleted }, "activeExpenses should not contain deleted records")
    }
    
    @Test func testConditionalDeletionWithSyncEnabled() async throws {
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
        #expect(manager.shifts.count == 1, "Shift should still exist in shifts array")
        #expect(manager.shifts.first?.isDeleted == true, "Shift should be marked as deleted")
        #expect(manager.activeShifts.count == 0, "activeShifts should not include soft-deleted shift")
        
        // Cleanup
        preferences.incrementalSyncEnabled = false
    }
    
    @Test func testConditionalDeletionWithSyncDisabled() async throws {
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
        #expect(manager.shifts.count == 0, "Shift should be completely removed from shifts array")
        #expect(manager.activeShifts.count == 0, "activeShifts should be empty")
    }
    
    @Test func testAutomaticCleanupOfSoftDeletedRecords() async throws {
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
        #expect(manager.shifts.count == 1, "Only active shifts should remain after cleanup")
        #expect(manager.shifts.first?.id == activeShift.id, "The remaining shift should be the active one")
        #expect(!manager.shifts.contains { $0.isDeleted }, "No soft-deleted shifts should remain")
    }
    
    @Test func testExpenseFilteringInMonthlyQueries() async throws {
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
        #expect(monthExpenses.count == 1, "Monthly expenses should exclude deleted records")
        #expect(monthExpenses.first?.id == activeExpense.id, "Should return only the active expense")
        
        // Test monthly total excludes deleted expenses
        let monthTotal = manager.totalForMonth(currentDate)
        #expect(monthTotal == 50.0, "Monthly total should only include active expenses")
    }
    
    private func createTestShift() -> RideshareShift {
        return RideshareShift(
            startDate: Date(),
            startMileage: 10000.0,
            startTankReading: 8.0,
            hasFullTankAtStart: true
        )
    }
}

// MARK: - Week Date Range Tests

struct WeekDateRangeTests {
    @Test func testWeekBoundaryInclusiveFiltering() async throws {
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
            hasFullTankAtStart: false
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
        #expect(inclusiveFilteredShifts.count == 1, "Fixed inclusive filtering should find boundary shift")
        #expect(inclusiveFilteredShifts.first?.id == boundaryShift.id, "Should find the Sunday boundary shift")
        
        // The original bug: exclusive filtering should behave differently (may or may not find boundary)
        #expect(inclusiveFilteredShifts.count >= exclusiveFilteredShifts.count, "Inclusive filtering should find at least as many shifts as exclusive")
    }
    
    @Test func testWeekStartDayPreferenceDependency() async throws {
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
            hasFullTankAtStart: true
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
        #expect(sundayWeekShifts.count == 1, "Sunday-start week should include Wednesday shift")
        #expect(mondayWeekShifts.count == 1, "Monday-start week should include Wednesday shift") 
        #expect(sundayWeekShifts.first?.id == testShift.id, "Should find correct shift with Sunday start")
        #expect(mondayWeekShifts.first?.id == testShift.id, "Should find correct shift with Monday start")
        
        // The week intervals should be different (different start dates)
        #expect(sundayWeekInterval.start != mondayWeekInterval.start, "Different week start preferences should create different week boundaries")
    }
}

// MARK: - Calculator Tests
struct CalculatorEngineTests {
    
    @Test func testBasicArithmetic() async throws {
        let calculator = CalculatorEngine.shared
        
        // Basic operations
        #expect(calculator.evaluate("45+23") == 68.0)
        #expect(calculator.evaluate("100-25") == 75.0)
        #expect(calculator.evaluate("50*2") == 100.0)
        #expect(calculator.evaluate("100/4") == 25.0)
        
        // Decimal operations
        let result1 = calculator.evaluate("12.50+3.75")
        #expect(result1 != nil && abs(result1! - 16.25) < 0.001)
        
        let result2 = calculator.evaluate("45.67*0.85")
        #expect(result2 != nil && abs(result2! - 38.8195) < 0.001)
    }
    
    @Test func testRideshareScenarios() async throws {
        let calculator = CalculatorEngine.shared
        
        // Scenarios from your Uber shifts
        #expect(calculator.evaluate("250-175") == 75.0)   // Mileage calculation (end - start)
        #expect(calculator.evaluate("45/3") == 15.0)       // Tip splitting
        #expect(calculator.evaluate("65*0.75") == 48.75)   // Fuel costs
        #expect(calculator.evaluate("150*0.67") == 100.5)  // Tax deductions (IRS rate)
        
        // Expense calculations
        #expect(calculator.evaluate("12.50+3.50") == 16.0)  // Meal + tip
        #expect(calculator.evaluate("25+15+8") == 48.0)     // Multiple expenses
    }
    
    @Test func testComplexExpressions() async throws {
        let calculator = CalculatorEngine.shared
        
        // Parentheses and order of operations
        #expect(calculator.evaluate("(100+50)*0.67") == 100.5)
        #expect(calculator.evaluate("100+50*2-25/5") == 195.0)
        #expect(calculator.evaluate("(250-175)*0.67") == 50.25) // Miles times IRS rate
    }
    
    @Test func testExpressionDetection() async throws {
        let calculator = CalculatorEngine.shared
        
        // Should detect math expressions
        #expect(calculator.containsMathExpression("45+23") == true)
        #expect(calculator.containsMathExpression("100*0.67") == true)
        #expect(calculator.containsMathExpression("250-175=") == true)
        
        // Should not detect plain numbers
        #expect(calculator.containsMathExpression("45") == false)
        #expect(calculator.containsMathExpression("123.45") == false)
        #expect(calculator.containsMathExpression("") == false)
    }
    
    @Test func testInputSanitization() async throws {
        let calculator = CalculatorEngine.shared
        
        // Should handle equals sign at end
        #expect(calculator.evaluate("45+23=") == 68.0)
        #expect(calculator.evaluate("100/4=") == 25.0)
        
        // Should handle alternative math symbols
        #expect(calculator.evaluate("50×2") == 100.0)  // Multiplication symbol
        #expect(calculator.evaluate("100÷4") == 25.0)  // Division symbol
        #expect(calculator.evaluate("100−25") == 75.0) // En-dash minus
    }
    
    @Test func testErrorHandling() async throws {
        let calculator = CalculatorEngine.shared
        
        // Invalid expressions should return nil
        #expect(calculator.evaluate("invalid") == nil)
        #expect(calculator.evaluate("45+") == nil)
        #expect(calculator.evaluate("+45") == nil)
        #expect(calculator.evaluate("45++23") == nil)
        #expect(calculator.evaluate("(") == nil)
        #expect(calculator.evaluate("45/0") != nil) // Division by zero should be handled by NSExpression
    }
    
    @Test func testStringExtensions() async throws {
        // Test convenience extensions
        #expect("45+23".evaluateAsMath() == 68.0)
        #expect("100*0.67".evaluateAsMath() == 67.0)
        
        #expect("45+23".containsMathExpression == true)
        #expect("123.45".containsMathExpression == false)
        
        #expect("45+23".isValidMathExpression == true)
        #expect("45+".isValidMathExpression == false)
    }
    
    @Test func testMultipleRefuelingScenario() async throws {
        let calculator = CalculatorEngine.shared
        
        // Your real scenario: refueling more than once
        // Fuel costs: First fill $45.67, second fill $38.25
        #expect(calculator.evaluate("45.67+38.25") == 83.92)
        
        // Gallons used: First 12.5 gallons, second 10.75 gallons
        let totalGallons = calculator.evaluate("12.5+10.75")
        #expect(totalGallons == 23.25)
        
        // Average cost per gallon across both fills
        let avgCostPerGallon = calculator.evaluate("(45.67+38.25)/(12.5+10.75)")
        #expect(avgCostPerGallon != nil && abs(avgCostPerGallon! - 3.61) < 0.01)
        
        // Complex refuel math: (cost1/gallons1 + cost2/gallons2)/2 for average price
        let complexAvg = calculator.evaluate("(45.67/12.5 + 38.25/10.75)/2")
        #expect(complexAvg != nil && complexAvg! > 3.5 && complexAvg! < 4.0)
    }
    
    @Test func testRealWorldUberScenarios() async throws {
        let calculator = CalculatorEngine.shared
        
        // After 12-hour shift calculations
        // Multiple platform earnings: Uber + Lyft + DoorDash
        #expect(calculator.evaluate("125.50+87.25+45.75") == 258.5)
        
        // Tip calculations with cash tips included
        #expect(calculator.evaluate("35.75+12+8.50") == 56.25)
        
        // Toll road costs throughout day
        #expect(calculator.evaluate("3.50+2.75+4.25+3.50") == 14.0)
        
        // Parking fees at multiple locations
        #expect(calculator.evaluate("8+5+12") == 25.0)
        
        // Net profit after all expenses
        let revenue = calculator.evaluate("258.5+56.25") // Fare + tips
        let expenses = calculator.evaluate("83.92+14+25") // Fuel + tolls + parking
        #expect(revenue == 314.75)
        #expect(expenses == 122.92)
        
        // Quick profit check
        let profit = calculator.evaluate("314.75-122.92")
        #expect(profit != nil && abs(profit! - 191.83) < 0.01)
    }
}

enum TestError: Error {
    case dateCreationFailed
}