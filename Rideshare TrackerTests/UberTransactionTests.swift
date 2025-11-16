//
//  UberTransactionTests.swift
//  Rideshare TrackerTests
//
//  Created by Claude AI on 11/14/25.
//

import XCTest
@testable import Rideshare_Tracker

final class UberTransactionTests: XCTestCase {

    // MARK: - Model Initialization Tests

    func testUberTransactionInitialization() {
        let date = Date()
        let eventDate = Calendar.current.date(byAdding: .hour, value: -2, to: date)!

        let transaction = UberTransaction(
            transactionDate: date,
            eventDate: eventDate,
            eventType: "UberX",
            amount: 25.50,
            tollsReimbursed: 3.50,
            statementPeriod: "Oct 13 - Oct 20, 2025",
            shiftID: nil,
            importDate: date
        )

        XCTAssertEqual(transaction.eventType, "UberX")
        XCTAssertEqual(transaction.amount, 25.50)
        XCTAssertEqual(transaction.tollsReimbursed, 3.50)
        XCTAssertEqual(transaction.statementPeriod, "Oct 13 - Oct 20, 2025")
        XCTAssertNil(transaction.shiftID)
        XCTAssertFalse(transaction.needsManualVerification)
    }

    func testUberTransactionWithoutTollReimbursement() {
        let transaction = UberTransaction(
            transactionDate: Date(),
            eventDate: Date(),
            eventType: "Tip",
            amount: 5.00,
            tollsReimbursed: nil,
            statementPeriod: "Oct 13 - Oct 20, 2025",
            shiftID: nil,
            importDate: Date()
        )

        XCTAssertNil(transaction.tollsReimbursed)
        XCTAssertEqual(transaction.amount, 5.00)
    }

    func testUberTransactionWithShiftAssignment() {
        let shiftID = UUID()
        let transaction = UberTransaction(
            transactionDate: Date(),
            eventDate: Date(),
            eventType: "UberX Priority",
            amount: 30.00,
            tollsReimbursed: nil,
            statementPeriod: "Oct 13 - Oct 20, 2025",
            shiftID: shiftID,
            importDate: Date()
        )

        XCTAssertEqual(transaction.shiftID, shiftID)
    }

    // MARK: - Categorization Tests

    func testCategorizeTipTransaction() {
        let transaction = createTransaction(eventType: "Tip", amount: 8.00)
        let category = categorize(transaction)
        XCTAssertEqual(category, .tip)
    }

    func testCategorizeQuestTransaction() {
        let transaction = createTransaction(eventType: "Quest", amount: 15.00)
        let category = categorize(transaction)
        XCTAssertEqual(category, .promotion)
    }

    func testCategorizeIncentiveTransaction() {
        let transaction = createTransaction(eventType: "Incentive", amount: 10.00)
        let category = categorize(transaction)
        XCTAssertEqual(category, .promotion)
    }

    func testCategorizeUberXTransaction() {
        let transaction = createTransaction(eventType: "UberX", amount: 25.00)
        let category = categorize(transaction)
        XCTAssertEqual(category, .netFare)
    }

    func testCategorizeUberXPriorityTransaction() {
        let transaction = createTransaction(eventType: "UberX Priority", amount: 32.00)
        let category = categorize(transaction)
        XCTAssertEqual(category, .netFare)
    }

    func testCategorizeShareTransaction() {
        let transaction = createTransaction(eventType: "Share", amount: 18.00)
        let category = categorize(transaction)
        XCTAssertEqual(category, .netFare)
    }

    func testCategorizeDeliveryTransaction() {
        let transaction = createTransaction(eventType: "Delivery", amount: 12.00)
        let category = categorize(transaction)
        XCTAssertEqual(category, .netFare)
    }

    func testCategorizeBankTransferIgnored() {
        let transaction = createTransaction(eventType: "Transferred to Bank Account", amount: -150.00)
        let category = categorize(transaction)
        XCTAssertEqual(category, .ignore)
    }

    func testCategorizeBankTransferLowercaseIgnored() {
        let transaction = createTransaction(eventType: "transferred to bank", amount: -100.00)
        let category = categorize(transaction)
        XCTAssertEqual(category, .ignore)
    }

    // MARK: - TransactionTotals Aggregation Tests

    func testEmptyArrayTotals() {
        let transactions: [UberTransaction] = []
        let totals = transactions.totals()

        XCTAssertEqual(totals.tips, 0)
        XCTAssertEqual(totals.tollsReimbursed, 0)
        XCTAssertEqual(totals.promotions, 0)
        XCTAssertEqual(totals.netFare, 0)
        XCTAssertEqual(totals.count, 0)
    }

    func testSingleTipTransactionTotals() {
        let transactions = [
            createTransaction(eventType: "Tip", amount: 8.50)
        ]
        let totals = transactions.totals()

        XCTAssertEqual(totals.tips, 8.50)
        XCTAssertEqual(totals.netFare, 0)
        XCTAssertEqual(totals.count, 1)
    }

    func testMixedTransactionsTotals() {
        let transactions = [
            createTransaction(eventType: "UberX", amount: 25.00, tollsReimbursed: 3.50),
            createTransaction(eventType: "Tip", amount: 5.00),
            createTransaction(eventType: "UberX Priority", amount: 30.00, tollsReimbursed: 2.75),
            createTransaction(eventType: "Quest", amount: 15.00),
            createTransaction(eventType: "Tip", amount: 8.00),
            createTransaction(eventType: "Transferred to Bank Account", amount: -100.00)
        ]
        let totals = transactions.totals()

        XCTAssertEqual(totals.tips, 13.00) // 5.00 + 8.00
        XCTAssertEqual(totals.tollsReimbursed, 6.25) // 3.50 + 2.75
        XCTAssertEqual(totals.promotions, 15.00) // Quest only
        XCTAssertEqual(totals.netFare, 55.00) // 25.00 + 30.00
        XCTAssertEqual(totals.count, 6) // All transactions counted
    }

    func testTollsReimbursedAggregation() {
        let transactions = [
            createTransaction(eventType: "UberX", amount: 20.00, tollsReimbursed: 4.00),
            createTransaction(eventType: "Share", amount: 15.00, tollsReimbursed: 2.50),
            createTransaction(eventType: "UberX", amount: 25.00, tollsReimbursed: nil)
        ]
        let totals = transactions.totals()

        XCTAssertEqual(totals.tollsReimbursed, 6.50) // 4.00 + 2.50
        XCTAssertEqual(totals.netFare, 60.00) // 20 + 15 + 25
    }

    func testBankTransfersIgnoredInTotals() {
        let transactions = [
            createTransaction(eventType: "UberX", amount: 50.00),
            createTransaction(eventType: "Transferred to Bank Account", amount: -50.00)
        ]
        let totals = transactions.totals()

        XCTAssertEqual(totals.netFare, 50.00)
        XCTAssertEqual(totals.count, 2) // Both counted in total count
    }

    // MARK: - Date Range Filtering Tests

    func testTotalsWithDateRangeFiltering() {
        let calendar = Calendar.current
        let now = Date()

        // Create dates
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        let today = now
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!

        let transactions = [
            createTransaction(eventType: "Tip", amount: 5.00, transactionDate: yesterday),
            createTransaction(eventType: "UberX", amount: 25.00, transactionDate: today),
            createTransaction(eventType: "Tip", amount: 8.00, transactionDate: tomorrow)
        ]

        // Filter from start of today to end of today
        let startOfToday = calendar.startOfDay(for: today)
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday)!

        let totals = transactions.totals(from: startOfToday, to: endOfToday)

        XCTAssertEqual(totals.netFare, 25.00)
        XCTAssertEqual(totals.tips, 0)
        XCTAssertEqual(totals.count, 1)
    }

    func testTotalsEmptyDateRange() {
        let calendar = Calendar.current
        let now = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!

        let transactions = [
            createTransaction(eventType: "Tip", amount: 5.00, transactionDate: now)
        ]

        // Query range that doesn't include the transaction
        let startOfYesterday = calendar.startOfDay(for: yesterday)
        let endOfYesterday = calendar.date(byAdding: .hour, value: 12, to: startOfYesterday)!

        let totals = transactions.totals(from: startOfYesterday, to: endOfYesterday)

        XCTAssertEqual(totals.count, 0)
        XCTAssertEqual(totals.tips, 0)
    }

    // MARK: - Equatable and Identifiable Tests

    func testUberTransactionEquatable() {
        let id = UUID()
        let date = Date()

        var tx1 = createTransaction(eventType: "Tip", amount: 5.00)
        tx1.id = id
        tx1.transactionDate = date

        var tx2 = createTransaction(eventType: "Tip", amount: 5.00)
        tx2.id = id
        tx2.transactionDate = date

        // Same ID and properties should be equal
        XCTAssertEqual(tx1.id, tx2.id)
    }

    func testUberTransactionIdentifiable() {
        let tx1 = createTransaction(eventType: "Tip", amount: 5.00)
        let tx2 = createTransaction(eventType: "Tip", amount: 5.00)

        // Different instances should have different IDs
        XCTAssertNotEqual(tx1.id, tx2.id)
    }

    // MARK: - Codable Tests

    func testUberTransactionEncodeDecode() throws {
        let shiftID = UUID()
        let original = UberTransaction(
            transactionDate: Date(),
            eventDate: Date(),
            eventType: "UberX",
            amount: 25.50,
            tollsReimbursed: 3.75,
            needsManualVerification: true,
            statementPeriod: "Oct 13 - Oct 20, 2025",
            shiftID: shiftID,
            importDate: Date()
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(UberTransaction.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.eventType, original.eventType)
        XCTAssertEqual(decoded.amount, original.amount)
        XCTAssertEqual(decoded.tollsReimbursed, original.tollsReimbursed)
        XCTAssertEqual(decoded.needsManualVerification, true)
        XCTAssertEqual(decoded.statementPeriod, original.statementPeriod)
        XCTAssertEqual(decoded.shiftID, shiftID)
    }

    func testTransactionTotalsValues() {
        let totals = TransactionTotals(
            tips: 25.50,
            tollsReimbursed: 8.75,
            promotions: 15.00,
            netFare: 125.00,
            count: 10
        )

        XCTAssertEqual(totals.tips, 25.50)
        XCTAssertEqual(totals.tollsReimbursed, 8.75)
        XCTAssertEqual(totals.promotions, 15.00)
        XCTAssertEqual(totals.netFare, 125.00)
        XCTAssertEqual(totals.count, 10)
    }

    // MARK: - Helper Methods

    private func createTransaction(
        eventType: String,
        amount: Double,
        tollsReimbursed: Double? = nil,
        transactionDate: Date = Date()
    ) -> UberTransaction {
        return UberTransaction(
            transactionDate: transactionDate,
            eventDate: transactionDate,
            eventType: eventType,
            amount: amount,
            tollsReimbursed: tollsReimbursed,
            statementPeriod: "Oct 13 - Oct 20, 2025",
            shiftID: nil,
            importDate: Date()
        )
    }
}
