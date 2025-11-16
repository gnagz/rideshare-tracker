//
//  MissingShiftsCSVGeneratorTests.swift
//  Rideshare TrackerTests
//
//  Created by Claude AI on 11/8/25.
//

import XCTest
@testable import Rideshare_Tracker

/// Tests for generating CSV files for unmatched transactions (missing shifts)
/// Uses earliest transaction time as start, latest as end within 4 AM windows
@MainActor
final class MissingShiftsCSVGeneratorTests: RideshareTrackerTestBase {

    var generator: MissingShiftsCSVGenerator!

    override func setUp() async throws {
        try await super.setUp()
        generator = MissingShiftsCSVGenerator()
    }

    override func tearDown() async throws {
        generator = nil
        try await super.tearDown()
    }

    // MARK: - Grouping by 4 AM Boundary Tests

    func testGroupTransactionsByShiftDate() throws {
        // Given: Transactions spanning multiple 4 AM windows
        let transactions = [
            UberTransaction(transactionDate: createDate(year: 2025, month: 10, day: 19, hour: 20)!, eventDate: nil, eventType: "UberX", amount: 20.0, tollsReimbursed: nil, statementPeriod: "Oct 13 - Oct 20, 2025", shiftID: nil, importDate: Date()),  // Oct 19 8 PM
            UberTransaction(transactionDate: createDate(year: 2025, month: 10, day: 20, hour: 2)!, eventDate: nil, eventType: "UberX", amount: 15.0, tollsReimbursed: nil, statementPeriod: "Oct 13 - Oct 20, 2025", shiftID: nil, importDate: Date()),   // Oct 20 2 AM (still Oct 19's window)
            UberTransaction(transactionDate: createDate(year: 2025, month: 10, day: 20, hour: 18)!, eventDate: nil, eventType: "UberX", amount: 25.0, tollsReimbursed: nil, statementPeriod: "Oct 13 - Oct 20, 2025", shiftID: nil, importDate: Date()),  // Oct 20 6 PM
            UberTransaction(transactionDate: createDate(year: 2025, month: 10, day: 21, hour: 1)!, eventDate: nil, eventType: "UberX", amount: 18.0, tollsReimbursed: nil, statementPeriod: "Oct 13 - Oct 20, 2025", shiftID: nil, importDate: Date())    // Oct 21 1 AM (still Oct 20's window)
        ]

        // When: Group by shift date
        let grouped = generator.groupTransactionsByShiftDate(transactions)

        // Then: Should have 2 groups (Oct 19 and Oct 20)
        XCTAssertEqual(grouped.count, 2, "Should group into 2 shift dates")

        // Verify Oct 19's group has 2 transactions
        let oct19Date = createDate(year: 2025, month: 10, day: 19, hour: 4)!
        let oct19Group = grouped.first(where: { Calendar.current.isDate($0.key, inSameDayAs: oct19Date) })
        XCTAssertNotNil(oct19Group)
        XCTAssertEqual(oct19Group?.value.count, 2, "Oct 19's 4 AM window should have 2 transactions")

        // Verify Oct 20's group has 2 transactions
        let oct20Date = createDate(year: 2025, month: 10, day: 20, hour: 4)!
        let oct20Group = grouped.first(where: { Calendar.current.isDate($0.key, inSameDayAs: oct20Date) })
        XCTAssertNotNil(oct20Group)
        XCTAssertEqual(oct20Group?.value.count, 2, "Oct 20's 4 AM window should have 2 transactions")
    }

    func testGroupTransactionsBoundaryAt4AM() throws {
        // Given: Transactions around 4 AM boundary
        let transactions = [
            UberTransaction(transactionDate: createDate(year: 2025, month: 10, day: 20, hour: 3, minute: 59)!, eventDate: nil, eventType: "UberX", amount: 20.0, tollsReimbursed: nil, statementPeriod: "Oct 13 - Oct 20, 2025", shiftID: nil, importDate: Date()),  // 3:59 AM (Oct 19's window)
            UberTransaction(transactionDate: createDate(year: 2025, month: 10, day: 20, hour: 4, minute: 0)!, eventDate: nil, eventType: "UberX", amount: 15.0, tollsReimbursed: nil, statementPeriod: "Oct 13 - Oct 20, 2025", shiftID: nil, importDate: Date())    // 4:00 AM (Oct 20's window)
        ]

        // When: Group by shift date
        let grouped = generator.groupTransactionsByShiftDate(transactions)

        // Then: Should be in different groups
        XCTAssertEqual(grouped.count, 2, "4 AM boundary should split into different days")
    }

    // MARK: - Earliest/Latest Transaction Time Tests

    func testUseEarliestTransactionAsStartTime() throws {
        // Given: Transactions between 6 PM and 2 AM
        let transactions = [
            UberTransaction(transactionDate: createDate(year: 2025, month: 10, day: 19, hour: 20)!, eventDate: nil, eventType: "UberX", amount: 20.0, tollsReimbursed: nil, statementPeriod: "Oct 13 - Oct 20, 2025", shiftID: nil, importDate: Date()),   // 8 PM
            UberTransaction(transactionDate: createDate(year: 2025, month: 10, day: 19, hour: 18)!, eventDate: nil, eventType: "UberX", amount: 15.0, tollsReimbursed: nil, statementPeriod: "Oct 13 - Oct 20, 2025", shiftID: nil, importDate: Date()),   // 6 PM (earliest)
            UberTransaction(transactionDate: createDate(year: 2025, month: 10, day: 20, hour: 2)!, eventDate: nil, eventType: "UberX", amount: 25.0, tollsReimbursed: nil, statementPeriod: "Oct 13 - Oct 20, 2025", shiftID: nil, importDate: Date())     // 2 AM
        ]

        // When: Calculate shift start/end times
        let (startTime, _) = generator.calculateShiftTimes(for: transactions)

        // Then: Should use 6 PM as start time
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: startTime)
        XCTAssertEqual(components.hour, 18, "Should use earliest transaction time (6 PM) as start")
        XCTAssertEqual(components.minute, 0)
    }

    func testUseLatestTransactionAsEndTime() throws {
        // Given: Transactions between 6 PM and 2 AM
        let transactions = [
            UberTransaction(transactionDate: createDate(year: 2025, month: 10, day: 19, hour: 20)!, eventDate: nil, eventType: "UberX", amount: 20.0, tollsReimbursed: nil, statementPeriod: "Oct 13 - Oct 20, 2025", shiftID: nil, importDate: Date()),   // 8 PM
            UberTransaction(transactionDate: createDate(year: 2025, month: 10, day: 19, hour: 18)!, eventDate: nil, eventType: "UberX", amount: 15.0, tollsReimbursed: nil, statementPeriod: "Oct 13 - Oct 20, 2025", shiftID: nil, importDate: Date()),   // 6 PM
            UberTransaction(transactionDate: createDate(year: 2025, month: 10, day: 20, hour: 2)!, eventDate: nil, eventType: "UberX", amount: 25.0, tollsReimbursed: nil, statementPeriod: "Oct 13 - Oct 20, 2025", shiftID: nil, importDate: Date())     // 2 AM (latest)
        ]

        // When: Calculate shift start/end times
        let (_, endTime) = generator.calculateShiftTimes(for: transactions)

        // Then: Should use 2 AM as end time
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: endTime)
        XCTAssertEqual(components.hour, 2, "Should use latest transaction time (2 AM) as end")
        XCTAssertEqual(components.minute, 0)
    }

    func testShiftTimesWithSingleTransaction() throws {
        // Given: Single transaction
        let transactions = [
            UberTransaction(transactionDate: createDate(year: 2025, month: 10, day: 19, hour: 20)!, eventDate: nil, eventType: "UberX", amount: 20.0, tollsReimbursed: nil, statementPeriod: "Oct 13 - Oct 20, 2025", shiftID: nil, importDate: Date())
        ]

        // When: Calculate shift times
        let (startTime, endTime) = generator.calculateShiftTimes(for: transactions)

        // Then: Start and end should be same time
        XCTAssertEqual(startTime, endTime, "Single transaction should have same start and end time")
    }

    // MARK: - CSV Generation Tests

    func testGenerateCSVWithPrefilledUberData() throws {
        // Given: Unmatched transactions
        let transactions = [
            UberTransaction(transactionDate: createDate(year: 2025, month: 10, day: 19, hour: 20)!, eventDate: nil, eventType: "UberX", amount: 20.0, tollsReimbursed: 2.50, statementPeriod: "Oct 13 - Oct 20, 2025", shiftID: nil, importDate: Date()),
            UberTransaction(transactionDate: createDate(year: 2025, month: 10, day: 19, hour: 21)!, eventDate: nil, eventType: "Tip", amount: 5.0, tollsReimbursed: nil, statementPeriod: "Oct 13 - Oct 20, 2025", shiftID: nil, importDate: Date())
        ]

        // When: Generate CSV
        let csv = try generator.generateMissingShiftsCSV(unmatchedTransactions: transactions, statementPeriod: "Oct 13, 2025 - Oct 20, 2025")

        // Then: Should contain header row
        XCTAssertTrue(csv.contains("Start Date"), "Should include Start Date column")
        XCTAssertTrue(csv.contains("End Date"), "Should include End Date column")
        XCTAssertTrue(csv.contains("Uber Net Fare"), "Should include Uber Net Fare column")
        XCTAssertTrue(csv.contains("Uber Tips"), "Should include Uber Tips column")
        XCTAssertTrue(csv.contains("Uber Tolls"), "Should include Uber Tolls column")

        // Should have Uber data prefilled
        XCTAssertTrue(csv.contains("20.0"), "Should include net fare amount")
        XCTAssertTrue(csv.contains("5.0"), "Should include tip amount")
        XCTAssertTrue(csv.contains("2.5"), "Should include toll amount")
    }

    func testGenerateCSVWithBlankVehicleFields() throws {
        // Given: Unmatched transactions
        let transactions = [
            UberTransaction(transactionDate: createDate(year: 2025, month: 10, day: 19, hour: 20)!, eventDate: nil, eventType: "UberX", amount: 20.0, tollsReimbursed: nil, statementPeriod: "Oct 13 - Oct 20, 2025", shiftID: nil, importDate: Date())
        ]

        // When: Generate CSV
        let csv = try generator.generateMissingShiftsCSV(unmatchedTransactions: transactions, statementPeriod: "Oct 13, 2025 - Oct 20, 2025")

        // Then: Vehicle fields should be blank (empty or comma separators)
        // Check that CSV has proper structure with empty vehicle fields
        let lines = csv.components(separatedBy: .newlines)
        XCTAssertGreaterThan(lines.count, 1, "Should have header + data rows")

        // Data row should have empty fields for start mileage, end mileage, etc.
        // This will be verified by the structure having commas for empty fields
        let dataLine = lines[1]
        let commaCount = dataLine.filter { $0 == "," }.count
        XCTAssertGreaterThan(commaCount, 10, "Should have multiple empty fields separated by commas")
    }

    func testGenerateCSVGroupsMultipleDays() throws {
        // Given: Transactions spanning 2 shift dates
        let transactions = [
            UberTransaction(transactionDate: createDate(year: 2025, month: 10, day: 19, hour: 20)!, eventDate: nil, eventType: "UberX", amount: 20.0, tollsReimbursed: nil, statementPeriod: "Oct 13 - Oct 20, 2025", shiftID: nil, importDate: Date()),  // Oct 19
            UberTransaction(transactionDate: createDate(year: 2025, month: 10, day: 20, hour: 18)!, eventDate: nil, eventType: "UberX", amount: 25.0, tollsReimbursed: nil, statementPeriod: "Oct 13 - Oct 20, 2025", shiftID: nil, importDate: Date())   // Oct 20
        ]

        // When: Generate CSV
        let csv = try generator.generateMissingShiftsCSV(unmatchedTransactions: transactions, statementPeriod: "Oct 13, 2025 - Oct 20, 2025")

        // Then: Should have 2 data rows (one per shift date)
        let lines = csv.components(separatedBy: .newlines).filter { !$0.isEmpty }
        XCTAssertEqual(lines.count, 3, "Should have header + 2 data rows")
    }

    func testGenerateCSVWithNoTransactions() throws {
        // Given: Empty transaction array
        let transactions: [UberTransaction] = []

        // When: Generate CSV
        let csv = try generator.generateMissingShiftsCSV(unmatchedTransactions: transactions, statementPeriod: "Oct 13, 2025 - Oct 20, 2025")

        // Then: Should have header only
        let lines = csv.components(separatedBy: .newlines).filter { !$0.isEmpty }
        XCTAssertEqual(lines.count, 1, "Should have header row only")
    }

    func testGenerateCSVAggregatesTransactionsByDay() throws {
        // Given: Multiple transactions in same 4 AM window
        let transactions = [
            UberTransaction(transactionDate: createDate(year: 2025, month: 10, day: 19, hour: 20)!, eventDate: nil, eventType: "UberX", amount: 20.0, tollsReimbursed: 2.50, statementPeriod: "Oct 13 - Oct 20, 2025", shiftID: nil, importDate: Date()),
            UberTransaction(transactionDate: createDate(year: 2025, month: 10, day: 19, hour: 21)!, eventDate: nil, eventType: "Tip", amount: 5.0, tollsReimbursed: nil, statementPeriod: "Oct 13 - Oct 20, 2025", shiftID: nil, importDate: Date()),
            UberTransaction(transactionDate: createDate(year: 2025, month: 10, day: 19, hour: 22)!, eventDate: nil, eventType: "UberX", amount: 15.0, tollsReimbursed: 1.75, statementPeriod: "Oct 13 - Oct 20, 2025", shiftID: nil, importDate: Date()),
            UberTransaction(transactionDate: createDate(year: 2025, month: 10, day: 20, hour: 1)!, eventDate: nil, eventType: "Quest", amount: 10.0, tollsReimbursed: nil, statementPeriod: "Oct 13 - Oct 20, 2025", shiftID: nil, importDate: Date())   // Still Oct 19's window
        ]

        // When: Generate CSV
        let csv = try generator.generateMissingShiftsCSV(unmatchedTransactions: transactions, statementPeriod: "Oct 13, 2025 - Oct 20, 2025")

        // Then: Should aggregate into single shift
        let lines = csv.components(separatedBy: .newlines).filter { !$0.isEmpty }
        XCTAssertEqual(lines.count, 2, "Should have header + 1 aggregated data row")

        // Should sum net fares, tips, tolls, promotions
        let dataLine = lines[1]
        XCTAssertTrue(dataLine.contains("35.0"), "Should sum net fares (20 + 15)")
        XCTAssertTrue(dataLine.contains("5.0"), "Should include tips")
        XCTAssertTrue(dataLine.contains("4.25"), "Should sum tolls (2.50 + 1.75)")
        XCTAssertTrue(dataLine.contains("10.0"), "Should include promotions")
    }

    func testCSVFormatMatchesImportStructure() throws {
        // Given: Sample transaction
        let transactions = [
            UberTransaction(transactionDate: createDate(year: 2025, month: 10, day: 19, hour: 20)!, eventDate: nil, eventType: "UberX", amount: 20.0, tollsReimbursed: nil, statementPeriod: "Oct 13 - Oct 20, 2025", shiftID: nil, importDate: Date())
        ]

        // When: Generate CSV
        let csv = try generator.generateMissingShiftsCSV(unmatchedTransactions: transactions, statementPeriod: "Oct 13, 2025 - Oct 20, 2025")

        // Then: Should match expected format for import
        let lines = csv.components(separatedBy: .newlines)
        let header = lines[0]

        // Verify critical columns exist in correct order (matching import structure)
        XCTAssertTrue(header.starts(with: "Start Date,End Date,Start Mileage,End Mileage"), "Should match import column structure")
    }

    // MARK: - Helper Methods

    private func createDate(year: Int, month: Int, day: Int, hour: Int, minute: Int = 0) -> Date? {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.timeZone = TimeZone.current
        return Calendar.current.date(from: components)
    }
}
