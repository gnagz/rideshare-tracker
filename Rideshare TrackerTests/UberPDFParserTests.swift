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

    var parser: UberStatementManager!

    override func setUp() async throws {
        try await super.setUp()
        parser = UberStatementManager.shared
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

    // MARK: - Coordinate-Based Parsing Tests

    func testCoordinateParsing_BankTransferWithNegativeAmounts() {
        // Given: Bank transfer transaction with "-$600.15-$600.15" (no spaces)
        // From Oct 13 PDF diagnostic: X and Y coordinates from actual PDF
        let elements: [(text: String, x: CGFloat, y: CGFloat)] = [
            ("Mon, Oct 6", 36.8, 271.2),
            ("6:00 AM", 140.0, 271.2),
            ("Transferred To Bank", 220.0, 271.2),
            ("-$473.61-$473.61", 455.2, 271.2)  // Both amounts together, first is payout, second is balance
        ]

        // When: Parse using coordinate-based logic
        let transaction = parser.parseTransactionFromElements(elements, layout: .fiveColumn)

        // Then: Should extract first amount as transaction amount, ignore second (balance)
        XCTAssertNotNil(transaction, "Should parse bank transfer transaction")
        if let transaction = transaction {
            XCTAssertEqual(transaction.eventType, "Transferred To Bank")
            XCTAssertEqual(transaction.amount, -473.61, accuracy: 0.01, "Should extract first negative amount")
            XCTAssertNil(transaction.tollReimbursement, "Bank transfers don't have tolls")
        }
    }

    func testCoordinateParsing_QuestWithEmbeddedAmounts() {
        // Given: Quest transaction with amounts embedded in event type (line 3+)
        // This tests that amounts on lines beyond line 2 stay in the event type
        let elements: [(text: String, x: CGFloat, y: CGFloat)] = [
            ("Sat, Sep 14", 36.8, 400.0),
            ("11:59 PM", 140.0, 400.0),
            ("Quest", 220.0, 400.0),
            ("$20.00", 455.2, 400.0),        // Line 1: Quest earning amount
            ("$0.00", 520.0, 400.0),         // Line 1: Payout (no cash out)
            ("$473.26", 36.8, 385.0),        // Line 2: Balance - should be ignored!
            ("Completed 10 trips", 140.0, 370.0)  // Line 3: Additional event info
        ]

        // When: Parse transaction
        let transaction = parser.parseTransactionFromElements(elements, layout: .fiveColumn)

        // Then: Should NOT treat balance as toll
        XCTAssertNotNil(transaction, "Should parse Quest transaction")
        if let transaction = transaction {
            XCTAssertEqual(transaction.eventType, "Quest Completed 10 trips")
            XCTAssertEqual(transaction.amount, 20.00, accuracy: 0.01, "Should use first line amount")
            XCTAssertNil(transaction.tollReimbursement, "Quest should not have toll (balance was on line 2)")
        }
    }

    func testCoordinateParsing_RideWithToll() {
        // Given: Standard UberX ride with toll reimbursement (6-column layout)
        let elements: [(text: String, x: CGFloat, y: CGFloat)] = [
            ("Sat, Oct 19", 36.8, 500.0),
            ("7:49 PM", 140.0, 500.0),
            ("UberX", 220.0, 500.0),
            ("Priority", 280.0, 500.0),      // Multi-word event type
            ("$21.55", 400.0, 500.0),        // Earnings
            ("$2.71", 470.0, 500.0),         // Toll reimbursement
            ("$0.00", 520.0, 500.0),         // Payout
            ("Oct 19 6:45 PM", 140.0, 485.0), // Event date/time on next line
            ("$448.32", 520.0, 485.0)        // Balance on line 2 - should be ignored
        ]

        // When: Parse transaction
        let transaction = parser.parseTransactionFromElements(elements, layout: .sixColumn)

        // Then: Should parse toll correctly
        XCTAssertNotNil(transaction, "Should parse ride transaction")
        if let transaction = transaction {
            XCTAssertEqual(transaction.eventType, "UberX Priority")
            XCTAssertEqual(transaction.amount, 21.55, accuracy: 0.01)
            XCTAssertEqual(transaction.tollReimbursement ?? 0, 2.71, accuracy: 0.01, "Should extract toll from line 1")
        }
    }

    func testCoordinateParsing_PromotionWithEmbeddedAmount() {
        // Given: Real-world Promotion from Aug 11 PDF
        // Has embedded $15.00 in description and multi-line event text
        let elements: [(text: String, x: CGFloat, y: CGFloat)] = [
            ("Sun, Aug 24", 36.82375382567686, 373.2678899514913),
            ("Promotion - $15.00 extra for", 129.25758037426726, 373.2678899514913),
            ("$15.00 $15.00", 334.66608381557927, 373.2678899514913),
            ("5:28 PM", 36.82375382567686, 359.57398972207056),
            ("completing 3 Shop & Deliver orders", 129.25758037426726, 359.57398972207056),
            ("$180.41", 529.1194670733546, 359.57398972207056),
            ("Aug 24 5:28 PM", 129.25758037426726, 345.88008949264974),
        ]

        // When: Parse transaction
        let transaction = parser.parseTransactionFromElements(elements, layout: .fiveColumn)

        // Then: Should parse correctly
        XCTAssertNotNil(transaction, "Should parse Promotion transaction")
        if let transaction = transaction {
            // Event type should include full description with embedded amount
            XCTAssertTrue(transaction.eventType.hasPrefix("Promotion"), "Should identify as Promotion")
            XCTAssertTrue(transaction.eventType.contains("$15.00"), "Should keep embedded amount in description")
            XCTAssertTrue(transaction.eventType.contains("completing 3 Shop & Deliver"), "Should include full description")

            // Amount should come from standalone amount on line 1
            XCTAssertEqual(transaction.amount, 15.00, accuracy: 0.01, "Should use standalone amount from line 1")

            // No toll reimbursement
            XCTAssertNil(transaction.tollReimbursement, "Promotions don't have tolls")
        }
    }

    func testCoordinateParsing_IncentiveWithLongDescription() {
        // Given: Real-world Incentive-Quest from Nov 3 PDF, transaction #40
        // Has a very long multi-line description with embedded $2.00 amount
        let elements: [(text: String, x: CGFloat, y: CGFloat)] = [
            ("Thu, Oct 30", 36.82375382567686, 321.23123995968547),
            ("Incentive - Quest (Thursday Oct 30,", 138.8433105348618, 321.23123995968547),
            ("$2.00 $2.00", 368.9008343891313, 321.23123995968547),
            ("5:52 PM", 36.82375382567686, 307.53733973026476),
            ("2025 5:00:00 PM - Thursday Oct 30,", 138.8433105348618, 307.53733973026476),
            ("$194.94", 528.4347720618836, 307.53733973026476),
            ("2025 8:59:59 PM): You completed 3", 138.8433105348618, 293.84343950084406),
            ("trips (level 3) and we've added $2.00", 138.8433105348618, 280.14953927142335),
            ("to your payment statement.", 138.8433105348618, 266.4556390420022),
            ("Oct 30 5:52 PM", 138.8433105348618, 252.76173881258148),
        ]

        // When: Parse transaction
        let transaction = parser.parseTransactionFromElements(elements, layout: .fiveColumn)

        // Then: Should parse correctly
        XCTAssertNotNil(transaction, "Should parse Incentive-Quest transaction")
        if let transaction = transaction {
            // Event type should include full description with embedded amounts on line 3+
            XCTAssertTrue(transaction.eventType.hasPrefix("Incentive"), "Should identify as Incentive")
            XCTAssertTrue(transaction.eventType.contains("completed 3 trips"), "Should include full description")
            XCTAssertTrue(transaction.eventType.contains("$2.00"), "Should keep embedded amount in description (line 3+)")
            XCTAssertTrue(transaction.eventType.contains("to your payment statement"), "Should include all description lines")

            // Amount should come from standalone amount on line 1, not embedded text
            XCTAssertEqual(transaction.amount, 2.00, accuracy: 0.01, "Should use standalone amount from line 1")

            // Balance on line 2 should NOT be treated as toll
            XCTAssertNil(transaction.tollReimbursement, "Incentives don't have tolls")
        }
    }

    func testCoordinateParsing_RealWorldQuestWithLongDescription() {
        // Given: Real-world Quest transaction from Oct 13 PDF, transaction #17
        // This Quest has a very long multi-line description with embedded $20.00 amount
        let elements: [(text: String, x: CGFloat, y: CGFloat)] = [
            ("Sat, Oct 11", 36.82375382567686, 321.2307244397066),
            ("Quest (Friday Oct 10, 2025", 120.35654522514372, 321.2307244397066),
            ("$20.00 $20.00", 281.2598729208382, 321.2307244397066),
            ("10:27 PM", 36.82375382567686, 307.5368242102858),
            ("4:00:00 AM - Monday Oct", 120.35654522514372, 307.5368242102858),
            ("$370.20", 527.0653820389415, 307.5368242102858),
            ("13, 2025 4:00:00 AM): You", 120.35654522514372, 293.84292398086507),
            ("completed 20 trips (level", 120.35654522514372, 280.14902375144413),
            ("1) and we've added $20.00", 120.35654522514372, 266.4551235220234),
            ("to your payment", 120.35654522514372, 252.76122329260272),
            ("statement.", 120.35654522514372, 239.0673230631818),
            ("Oct 11 10:27 PM", 120.35654522514372, 225.37342283376108),
        ]

        // When: Parse transaction
        let transaction = parser.parseTransactionFromElements(elements, layout: .fiveColumn)

        // Then: Should parse correctly with full event description
        XCTAssertNotNil(transaction, "Should parse real-world Quest transaction")
        if let transaction = transaction {
            // Event type should include the full description, including embedded amounts on line 3+
            XCTAssertTrue(transaction.eventType.hasPrefix("Quest"), "Should identify as Quest")
            XCTAssertTrue(transaction.eventType.contains("completed 20 trips"), "Should include full description")
            XCTAssertTrue(transaction.eventType.contains("$20.00"), "Should keep embedded amount in description (line 3+)")

            // Amount should come from first line, not embedded text
            XCTAssertEqual(transaction.amount, 20.00, accuracy: 0.01, "Should use standalone amount from line 1")

            // Balance on line 2 should NOT be treated as toll
            XCTAssertNil(transaction.tollReimbursement, "Balance on line 2 should not be treated as toll")
        }
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
