//
//  UberShiftMatcherTests.swift
//  Rideshare TrackerTests
//
//  Created by Claude AI on 11/8/25.
//

import XCTest
@testable import Rideshare_Tracker

/// Tests for Uber transaction to shift matching using 4 AM boundaries
@MainActor
final class UberShiftMatcherTests: RideshareTrackerTestBase {

    var matcher: UberShiftMatcher!

    override func setUp() async throws {
        try await super.setUp()
        matcher = UberShiftMatcher()
    }

    override func tearDown() async throws {
        matcher = nil
        try await super.tearDown()
    }

    // MARK: - 4 AM Boundary Matching Tests

    func testMatchTransactionWithinShiftWindow() throws {
        // Given: Shift from 7 PM to 2 AM next day
        let shift = createShift(
            startDate: createDate(year: 2025, month: 10, day: 19, hour: 19)!,  // 7 PM
            endDate: createDate(year: 2025, month: 10, day: 20, hour: 2)!       // 2 AM next day
        )

        // Transaction at 9 PM same day (within shift time)
        let transaction = UberTransaction(
            transactionDate: createDate(year: 2025, month: 10, day: 19, hour: 21)!,  // 9 PM
            eventType: "UberX",
            amount: 25.00,
            tollReimbursement: nil
        )

        // When: Match transaction to shifts
        let matchedShift = matcher.findMatchingShift(for: transaction, in: [shift])

        // Then: Should match
        XCTAssertNotNil(matchedShift, "Transaction within shift window should match")
        XCTAssertEqual(matchedShift?.id, shift.id)
    }

    func testMatchTransactionOutsideShiftWindow() throws {
        // Given: Shift from 7 PM to 2 AM next day
        let shift = createShift(
            startDate: createDate(year: 2025, month: 10, day: 19, hour: 19)!,  // 7 PM
            endDate: createDate(year: 2025, month: 10, day: 20, hour: 2)!       // 2 AM next day
        )

        // Transaction at 5 PM (before shift starts, outside 4 AM window)
        let transaction = UberTransaction(
            transactionDate: createDate(year: 2025, month: 10, day: 19, hour: 17)!,  // 5 PM
            eventType: "UberX",
            amount: 25.00,
            tollReimbursement: nil
        )

        // When: Match transaction to shifts
        let matchedShift = matcher.findMatchingShift(for: transaction, in: [shift])

        // Then: Should not match
        XCTAssertNil(matchedShift, "Transaction before shift start should not match")
    }

    func testTransactionAt359AMMatchesPreviousDayShift() throws {
        // Given: Shift on Oct 19 from 8 PM to 3:59 AM (late shift)
        let shift = createShift(
            startDate: createDate(year: 2025, month: 10, day: 19, hour: 20)!,  // 8 PM Oct 19
            endDate: createDate(year: 2025, month: 10, day: 20, hour: 3, minute: 59)!  // 3:59 AM Oct 20
        )

        // Transaction at 3:59 AM Oct 20 (belongs to Oct 19's 4 AM window)
        let transaction = UberTransaction(
            transactionDate: createDate(year: 2025, month: 10, day: 20, hour: 3, minute: 59)!,
            eventType: "Tip",
            amount: 5.00,
            tollReimbursement: nil
        )

        // When: Match transaction to shifts
        let matchedShift = matcher.findMatchingShift(for: transaction, in: [shift])

        // Then: Should match (3:59 AM is still in Oct 19's 4 AM window and within shift time)
        XCTAssertNotNil(matchedShift, "Transaction at 3:59 AM should match previous day's shift")
    }

    func testTransactionAt4AMDoesNotMatchPreviousDayShift() throws {
        // Given: Shift on Oct 19 from 8 PM to 1 AM
        let shift = createShift(
            startDate: createDate(year: 2025, month: 10, day: 19, hour: 20)!,  // 8 PM Oct 19
            endDate: createDate(year: 2025, month: 10, day: 20, hour: 1)!       // 1 AM Oct 20
        )

        // Transaction at exactly 4:00 AM Oct 20 (starts Oct 20's window)
        let transaction = UberTransaction(
            transactionDate: createDate(year: 2025, month: 10, day: 20, hour: 4, minute: 0)!,
            eventType: "UberX",
            amount: 20.00,
            tollReimbursement: nil
        )

        // When: Match transaction to shifts
        let matchedShift = matcher.findMatchingShift(for: transaction, in: [shift])

        // Then: Should not match (4 AM starts new day's window)
        XCTAssertNil(matchedShift, "Transaction at 4:00 AM should not match previous day's shift")
    }

    func testMatchMultipleTransactionsToSameShift() throws {
        // Given: Single shift
        let shift = createShift(
            startDate: createDate(year: 2025, month: 10, day: 19, hour: 18)!,
            endDate: createDate(year: 2025, month: 10, day: 20, hour: 2)!
        )

        // Multiple transactions
        let transactions = [
            UberTransaction(transactionDate: createDate(year: 2025, month: 10, day: 19, hour: 19)!, eventType: "UberX", amount: 20.0, tollReimbursement: nil),
            UberTransaction(transactionDate: createDate(year: 2025, month: 10, day: 19, hour: 21)!, eventType: "Tip", amount: 5.0, tollReimbursement: nil),
            UberTransaction(transactionDate: createDate(year: 2025, month: 10, day: 20, hour: 1)!, eventType: "UberX", amount: 15.0, tollReimbursement: 2.5)
        ]

        // When: Match all transactions
        let (matched, _) = matcher.matchTransactionsToShifts(transactions: transactions, existingShifts: [shift])

        // Then: All 3 should match to same shift
        XCTAssertEqual(matched.count, 3, "All transactions should match")
        XCTAssertTrue(matched.allSatisfy { $0.shift.id == shift.id }, "All should match same shift")
    }

    func testNoMatchWhenTransactionAfterShiftEnd() throws {
        // Given: Shift ends at 2 AM
        let shift = createShift(
            startDate: createDate(year: 2025, month: 10, day: 19, hour: 18)!,
            endDate: createDate(year: 2025, month: 10, day: 20, hour: 2)!
        )

        // Transaction at 3 AM (after shift ended but before 4 AM boundary)
        let transaction = UberTransaction(
            transactionDate: createDate(year: 2025, month: 10, day: 20, hour: 3)!,
            eventType: "Tip",
            amount: 5.00,
            tollReimbursement: nil
        )

        // When: Match transaction
        let matchedShift = matcher.findMatchingShift(for: transaction, in: [shift])

        // Then: Should not match (transaction after shift ended)
        XCTAssertNil(matchedShift, "Transaction after shift end time should not match")
    }

    func testMatchWithMultipleShiftsSelectsCorrectOne() throws {
        // Given: Two shifts on different days
        let shift1 = createShift(
            startDate: createDate(year: 2025, month: 10, day: 19, hour: 18)!,
            endDate: createDate(year: 2025, month: 10, day: 20, hour: 2)!
        )

        let shift2 = createShift(
            startDate: createDate(year: 2025, month: 10, day: 20, hour: 18)!,
            endDate: createDate(year: 2025, month: 10, day: 21, hour: 1)!
        )

        // Transaction on Oct 20 at 8 PM (should match shift2)
        let transaction = UberTransaction(
            transactionDate: createDate(year: 2025, month: 10, day: 20, hour: 20)!,
            eventType: "UberX",
            amount: 25.00,
            tollReimbursement: nil
        )

        // When: Match transaction
        let matchedShift = matcher.findMatchingShift(for: transaction, in: [shift1, shift2])

        // Then: Should match shift2
        XCTAssertNotNil(matchedShift)
        XCTAssertEqual(matchedShift?.id, shift2.id, "Should match the correct shift")
    }

    func testReportUnmatchedTransactions() throws {
        // Given: Shift on Oct 19
        let shift = createShift(
            startDate: createDate(year: 2025, month: 10, day: 19, hour: 18)!,
            endDate: createDate(year: 2025, month: 10, day: 20, hour: 2)!
        )

        // Transactions: 2 match, 1 doesn't
        let transactions = [
            UberTransaction(transactionDate: createDate(year: 2025, month: 10, day: 19, hour: 19)!, eventType: "UberX", amount: 20.0, tollReimbursement: nil),  // Matches
            UberTransaction(transactionDate: createDate(year: 2025, month: 10, day: 21, hour: 10)!, eventType: "UberX", amount: 15.0, tollReimbursement: nil),  // No match
            UberTransaction(transactionDate: createDate(year: 2025, month: 10, day: 19, hour: 23)!, eventType: "Tip", amount: 5.0, tollReimbursement: nil)       // Matches
        ]

        // When: Match transactions
        let (matched, unmatched) = matcher.matchTransactionsToShifts(transactions: transactions, existingShifts: [shift])

        // Then: 2 matched, 1 unmatched
        XCTAssertEqual(matched.count, 2, "Should have 2 matched transactions")
        XCTAssertEqual(unmatched.count, 1, "Should have 1 unmatched transaction")
        XCTAssertEqual(unmatched[0].eventType, "UberX")
        XCTAssertEqual(unmatched[0].amount, 15.0, accuracy: 0.01)
    }

    func testHandleEmptyShiftList() throws {
        // Given: No shifts
        let transactions = [
            UberTransaction(transactionDate: Date(), eventType: "UberX", amount: 20.0, tollReimbursement: nil)
        ]

        // When: Match transactions
        let (matched, unmatched) = matcher.matchTransactionsToShifts(transactions: transactions, existingShifts: [])

        // Then: All unmatched
        XCTAssertEqual(matched.count, 0, "Should have no matches with empty shift list")
        XCTAssertEqual(unmatched.count, 1, "All transactions should be unmatched")
    }

    func testHandleEmptyTransactionList() throws {
        // Given: Shifts but no transactions
        let shift = createShift(
            startDate: createDate(year: 2025, month: 10, day: 19, hour: 18)!,
            endDate: createDate(year: 2025, month: 10, day: 20, hour: 2)!
        )

        // When: Match transactions
        let (matched, unmatched) = matcher.matchTransactionsToShifts(transactions: [], existingShifts: [shift])

        // Then: No matches, no unmatched
        XCTAssertEqual(matched.count, 0, "Should have no matches with empty transaction list")
        XCTAssertEqual(unmatched.count, 0, "Should have no unmatched with empty transaction list")
    }

    func testMatchWithMultipleShiftsInSameDay() throws {
        // Given: Two shifts on the same calendar day (Oct 19)
        let morningShift = createShift(
            startDate: createDate(year: 2025, month: 10, day: 19, hour: 6)!,   // 6 AM
            endDate: createDate(year: 2025, month: 10, day: 19, hour: 12)!     // 12 PM
        )

        let eveningShift = createShift(
            startDate: createDate(year: 2025, month: 10, day: 19, hour: 18)!,  // 6 PM
            endDate: createDate(year: 2025, month: 10, day: 20, hour: 2)!      // 2 AM next day
        )

        // Transactions at different times
        let morningTransaction = UberTransaction(
            transactionDate: createDate(year: 2025, month: 10, day: 19, hour: 10)!,  // 10 AM
            eventType: "UberX",
            amount: 20.00,
            tollReimbursement: nil
        )

        let eveningTransaction = UberTransaction(
            transactionDate: createDate(year: 2025, month: 10, day: 19, hour: 21)!,  // 9 PM
            eventType: "UberX",
            amount: 25.00,
            tollReimbursement: nil
        )

        // When: Match transactions
        let morningMatch = matcher.findMatchingShift(for: morningTransaction, in: [morningShift, eveningShift])
        let eveningMatch = matcher.findMatchingShift(for: eveningTransaction, in: [morningShift, eveningShift])

        // Then: Each should match the correct shift
        XCTAssertEqual(morningMatch?.id, morningShift.id, "Morning transaction should match morning shift")
        XCTAssertEqual(eveningMatch?.id, eveningShift.id, "Evening transaction should match evening shift")
    }

    func testIgnoreBankTransferTransactions() throws {
        // Given: Shift
        let shift = createShift(
            startDate: createDate(year: 2025, month: 10, day: 19, hour: 18)!,
            endDate: createDate(year: 2025, month: 10, day: 20, hour: 2)!
        )

        // Transactions including bank transfer
        let transactions = [
            UberTransaction(transactionDate: createDate(year: 2025, month: 10, day: 19, hour: 19)!, eventType: "UberX", amount: 20.0, tollReimbursement: nil),
            UberTransaction(transactionDate: createDate(year: 2025, month: 10, day: 19, hour: 20)!, eventType: "Transferred to Bank Account ending in 1234", amount: 450.0, tollReimbursement: nil)
        ]

        // When: Match transactions
        let (matched, unmatched) = matcher.matchTransactionsToShifts(transactions: transactions, existingShifts: [shift])

        // Then: Only UberX should be matched, bank transfer ignored
        XCTAssertEqual(matched.count, 1, "Should only match non-ignored transactions")
        XCTAssertEqual(matched[0].transaction.eventType, "UberX")
        XCTAssertEqual(unmatched.count, 0, "Bank transfer should be filtered out")
    }

    // MARK: - Helper Methods

    private func createShift(startDate: Date, endDate: Date) -> RideshareShift {
        var shift = RideshareShift(
            startDate: startDate,
            startMileage: 10000.0,
            startTankReading: 8.0,
            hasFullTankAtStart: true,
            gasPrice: 2.00,
            standardMileageRate: 0.67
        )
        shift.endDate = endDate
        shift.endMileage = 10100.0
        shift.endTankReading = 6.0
        return shift
    }

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
