//
//  UberPDFParserTests.swift
//  Rideshare TrackerTests
//
//  Created by Claude AI on 11/8/25.
//

import XCTest
import PDFKit
@testable import Rideshare_Tracker

/// Tests for Uber weekly statement PDF parsing
/// Verifies statement period extraction, column layout detection, transaction parsing, and event categorization
@MainActor
final class UberPDFParserTests: RideshareTrackerTestBase {

    var parser: UberPDFParser!

    override func setUp() async throws {
        try await super.setUp()
        parser = UberPDFParser()
    }

    override func tearDown() async throws {
        parser = nil
        try await super.tearDown()
    }

    // MARK: - Statement Period Parsing Tests

    func testParseStatementPeriod() throws {
        // Given: Statement period text from PDF page 1
        let statementText = """
        Statement period:
        Oct 13, 2025 4 AM - Oct 20, 2025 4 AM
        """

        // When: Parse statement period
        let result = try parser.parseStatementPeriod(from: statementText)

        // Then: Should extract start and end dates with 4 AM time
        XCTAssertNotNil(result, "Should parse statement period")

        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.year, .month, .day, .hour], from: result!.startDate)
        XCTAssertEqual(startComponents.year, 2025)
        XCTAssertEqual(startComponents.month, 10)
        XCTAssertEqual(startComponents.day, 13)
        XCTAssertEqual(startComponents.hour, 4)

        let endComponents = calendar.dateComponents([.year, .month, .day, .hour], from: result!.endDate)
        XCTAssertEqual(endComponents.year, 2025)
        XCTAssertEqual(endComponents.month, 10)
        XCTAssertEqual(endComponents.day, 20)
        XCTAssertEqual(endComponents.hour, 4)

        XCTAssertEqual(result!.period, "Oct 13, 2025 - Oct 20, 2025")
    }

    func testParseStatementPeriodWithDifferentFormat() throws {
        // Given: Alternative statement period format
        let statementText = """
        Statement period: Nov 3, 2025 4 AM - Nov 10, 2025 4 AM
        """

        // When: Parse statement period
        let result = try parser.parseStatementPeriod(from: statementText)

        // Then: Should parse correctly
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.period, "Nov 3, 2025 - Nov 10, 2025")
    }

    // MARK: - Column Layout Detection Tests

    func testDetectSixColumnLayout() throws {
        // Given: Transaction table header with toll column
        let tableHeader = """
        Processed   Event   Your earnings   Refunds & Expenses   Payouts   Balance
        """

        // When: Detect column layout
        let layout = parser.detectColumnLayout(from: tableHeader)

        // Then: Should detect 6-column layout
        XCTAssertEqual(layout, .sixColumn, "Should detect 6-column layout with 'Refunds & Expenses'")
    }

    func testDetectFiveColumnLayout() throws {
        // Given: Transaction table header without toll column
        let tableHeader = """
        Processed   Event   Your earnings   Payouts   Balance
        """

        // When: Detect column layout
        let layout = parser.detectColumnLayout(from: tableHeader)

        // Then: Should detect 5-column layout
        XCTAssertEqual(layout, .fiveColumn, "Should detect 5-column layout without 'Refunds & Expenses'")
    }

    // MARK: - Transaction Parsing Tests

    func testParseTransactionWithToll() throws {
        // Given: Transaction row with toll reimbursement
        let transactionLine = "Oct 19 7:49 PM   UberX   $21.55   $2.71   $0.00   $448.32"
        let statementEndDate = createDate(year: 2025, month: 10, day: 20, hour: 4)!

        // When: Parse transaction
        let transaction = try parser.parseTransaction(
            line: transactionLine,
            layout: .sixColumn,
            statementEndDate: statementEndDate
        )

        // Then: Should parse all fields correctly
        XCTAssertNotNil(transaction)
        XCTAssertEqual(transaction!.eventType, "UberX")
        XCTAssertEqual(transaction!.amount, 21.55, accuracy: 0.01)
        XCTAssertNotNil(transaction!.tollReimbursement)
        XCTAssertEqual(transaction!.tollReimbursement!, 2.71, accuracy: 0.01)

        let calendar = Calendar.current
        let components = calendar.dateComponents([.month, .day, .hour, .minute], from: transaction!.transactionDate)
        XCTAssertEqual(components.month, 10)
        XCTAssertEqual(components.day, 19)
        XCTAssertEqual(components.hour, 19) // 7 PM
        XCTAssertEqual(components.minute, 49)
    }

    func testParseTransactionWithoutToll() throws {
        // Given: Transaction row without toll column
        let transactionLine = "Nov 5 2:30 AM   Delivery   $12.25   $0.00   $156.78"
        let statementEndDate = createDate(year: 2025, month: 11, day: 10, hour: 4)!

        // When: Parse transaction
        let transaction = try parser.parseTransaction(
            line: transactionLine,
            layout: .fiveColumn,
            statementEndDate: statementEndDate
        )

        // Then: Should parse correctly with nil toll
        XCTAssertNotNil(transaction)
        XCTAssertEqual(transaction!.eventType, "Delivery")
        XCTAssertEqual(transaction!.amount, 12.25, accuracy: 0.01)
        XCTAssertNil(transaction!.tollReimbursement)
    }

    func testParseTipTransaction() throws {
        // Given: Tip transaction (separate from ride)
        let transactionLine = "Oct 20 2:30 AM   Tip   $5.00   $0.00   $453.32"
        let statementEndDate = createDate(year: 2025, month: 10, day: 20, hour: 4)!

        // When: Parse transaction
        let transaction = try parser.parseTransaction(
            line: transactionLine,
            layout: .fiveColumn,
            statementEndDate: statementEndDate
        )

        // Then: Should parse tip correctly
        XCTAssertNotNil(transaction)
        XCTAssertEqual(transaction!.eventType, "Tip")
        XCTAssertEqual(transaction!.amount, 5.00, accuracy: 0.01)
    }

    func testParseQuestTransaction() throws {
        // Given: Quest transaction
        let transactionLine = "Oct 19 11:59 PM   Quest   $20.00   $0.00   $468.32"
        let statementEndDate = createDate(year: 2025, month: 10, day: 20, hour: 4)!

        // When: Parse transaction
        let transaction = try parser.parseTransaction(
            line: transactionLine,
            layout: .fiveColumn,
            statementEndDate: statementEndDate
        )

        // Then: Should parse quest correctly
        XCTAssertNotNil(transaction)
        XCTAssertEqual(transaction!.eventType, "Quest")
        XCTAssertEqual(transaction!.amount, 20.00, accuracy: 0.01)
    }

    // MARK: - Year Inference Tests

    func testYearInferenceWithinStatementYear() throws {
        // Given: Transaction in October, statement ends in October 2025
        let transactionLine = "Oct 19 7:49 PM   UberX   $21.55   $0.00   $448.32"
        let statementEndDate = createDate(year: 2025, month: 10, day: 20, hour: 4)!

        // When: Parse transaction
        let transaction = try parser.parseTransaction(
            line: transactionLine,
            layout: .fiveColumn,
            statementEndDate: statementEndDate
        )

        // Then: Should use same year as statement
        let calendar = Calendar.current
        let year = calendar.component(.year, from: transaction!.transactionDate)
        XCTAssertEqual(year, 2025)
    }

    func testYearInferenceAcrossYearBoundary() throws {
        // Given: Transaction in December, but statement ends in January 2026
        let transactionLine = "Dec 31 11:30 PM   UberX   $15.00   $0.00   $200.00"
        let statementEndDate = createDate(year: 2026, month: 1, day: 7, hour: 4)!

        // When: Parse transaction
        let transaction = try parser.parseTransaction(
            line: transactionLine,
            layout: .fiveColumn,
            statementEndDate: statementEndDate
        )

        // Then: Should use previous year (2025) since Dec < Jan
        let calendar = Calendar.current
        let year = calendar.component(.year, from: transaction!.transactionDate)
        XCTAssertEqual(year, 2025)
    }

    // MARK: - Event Categorization Tests

    func testCategorizeTipTransaction() {
        // Given: Tip event
        let transaction = UberTransaction(
            transactionDate: Date(),
            eventType: "Tip",
            amount: 5.00,
            tollReimbursement: nil
        )

        // When: Categorize
        let category = parser.categorize(transaction: transaction)

        // Then: Should be categorized as tip
        XCTAssertEqual(category, .tip)
    }

    func testCategorizeQuestTransaction() {
        // Given: Quest event
        let transaction = UberTransaction(
            transactionDate: Date(),
            eventType: "Quest",
            amount: 20.00,
            tollReimbursement: nil
        )

        // When: Categorize
        let category = parser.categorize(transaction: transaction)

        // Then: Should be categorized as promotion
        XCTAssertEqual(category, .promotion)
    }

    func testCategorizeIncentiveTransaction() {
        // Given: Incentive event
        let transaction = UberTransaction(
            transactionDate: Date(),
            eventType: "Incentive",
            amount: 9.00,
            tollReimbursement: nil
        )

        // When: Categorize
        let category = parser.categorize(transaction: transaction)

        // Then: Should be categorized as promotion
        XCTAssertEqual(category, .promotion)
    }

    func testCategorizeRideTransaction() {
        // Given: Ride event (UberX, Delivery, Share, etc.)
        let rideTypes = ["UberX", "UberX Priority", "Share", "Delivery"]

        for rideType in rideTypes {
            let transaction = UberTransaction(
                transactionDate: Date(),
                eventType: rideType,
                amount: 25.00,
                tollReimbursement: nil
            )

            // When: Categorize
            let category = parser.categorize(transaction: transaction)

            // Then: Should be categorized as net fare
            XCTAssertEqual(category, .netFare, "Ride type '\(rideType)' should be net fare")
        }
    }

    func testCategorizeBankTransferIgnored() {
        // Given: Bank transfer event
        let transaction = UberTransaction(
            transactionDate: Date(),
            eventType: "Transferred to Bank Account ending in 1234",
            amount: 450.00,
            tollReimbursement: nil
        )

        // When: Categorize
        let category = parser.categorize(transaction: transaction)

        // Then: Should be ignored
        XCTAssertEqual(category, .ignore)
    }

    // MARK: - Integration Tests with Real PDF Structure

    func testParseMultipleTransactions() throws {
        // Given: Multiple transaction lines
        let transactionsText = """
        Oct 19 7:49 PM   UberX   $21.55   $2.71   $0.00   $448.32
        Oct 19 9:15 PM   Tip   $5.00   $0.00   $453.32
        Oct 20 12:30 AM   Delivery   $12.00   $0.00   $465.32
        Oct 20 2:00 AM   Quest   $20.00   $0.00   $485.32
        """
        let statementEndDate = createDate(year: 2025, month: 10, day: 20, hour: 4)!

        // When: Parse all transactions
        let transactions = try parser.parseTransactions(
            from: transactionsText,
            layout: .sixColumn,
            statementEndDate: statementEndDate
        )

        // Then: Should parse all 4 transactions
        XCTAssertEqual(transactions.count, 4)
        XCTAssertEqual(transactions[0].eventType, "UberX")
        XCTAssertEqual(transactions[1].eventType, "Tip")
        XCTAssertEqual(transactions[2].eventType, "Delivery")
        XCTAssertEqual(transactions[3].eventType, "Quest")
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
