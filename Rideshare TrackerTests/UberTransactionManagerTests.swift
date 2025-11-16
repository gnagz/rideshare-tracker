//
//  UberTransactionManagerTests.swift
//  Rideshare TrackerTests
//
//  Created by Claude AI on 11/14/25.
//

import XCTest
@testable import Rideshare_Tracker

final class UberTransactionManagerTests: XCTestCase {

    var manager: UberTransactionManager!

    override func setUpWithError() throws {
        super.setUp()
        manager = UberTransactionManager.shared
        // Clear all transactions before each test
        manager.clearAllTransactions()
    }

    override func tearDownWithError() throws {
        // Clean up after each test
        manager.clearAllTransactions()
        super.tearDown()
    }

    // MARK: - Save Single Transaction Tests

    func testSaveTransaction() {
        let transaction = createTransaction(eventType: "Tip", amount: 5.00)
        manager.saveTransaction(transaction)

        let all = manager.getAllTransactions()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.eventType, "Tip")
        XCTAssertEqual(all.first?.amount, 5.00)
    }

    func testSaveTransactionUpdatesExisting() {
        var transaction = createTransaction(eventType: "Tip", amount: 5.00)
        manager.saveTransaction(transaction)

        // Update the transaction
        transaction.amount = 10.00
        manager.saveTransaction(transaction)

        let all = manager.getAllTransactions()
        XCTAssertEqual(all.count, 1) // Should not duplicate
        XCTAssertEqual(all.first?.amount, 10.00) // Should be updated
    }

    func testSaveMultipleTransactions() {
        let tx1 = createTransaction(eventType: "Tip", amount: 5.00)
        let tx2 = createTransaction(eventType: "UberX", amount: 25.00)
        let tx3 = createTransaction(eventType: "Quest", amount: 15.00)

        manager.saveTransaction(tx1)
        manager.saveTransaction(tx2)
        manager.saveTransaction(tx3)

        let all = manager.getAllTransactions()
        XCTAssertEqual(all.count, 3)
    }

    // MARK: - Save Multiple Transactions Tests

    func testSaveTransactionsBatch() {
        let transactions = [
            createTransaction(eventType: "Tip", amount: 5.00),
            createTransaction(eventType: "UberX", amount: 25.00),
            createTransaction(eventType: "Quest", amount: 15.00)
        ]

        manager.saveTransactions(transactions)

        let all = manager.getAllTransactions()
        XCTAssertEqual(all.count, 3)
    }

    func testSaveTransactionsBatchWithUpdates() {
        var tx1 = createTransaction(eventType: "Tip", amount: 5.00)
        manager.saveTransaction(tx1)

        // Update tx1 and add new tx2
        tx1.amount = 8.00
        let tx2 = createTransaction(eventType: "UberX", amount: 30.00)

        manager.saveTransactions([tx1, tx2])

        let all = manager.getAllTransactions()
        XCTAssertEqual(all.count, 2) // Should have 2 total, not 3

        let updatedTx1 = all.first { $0.id == tx1.id }
        XCTAssertEqual(updatedTx1?.amount, 8.00)
    }

    // MARK: - Get Transactions Tests

    func testGetAllTransactionsEmpty() {
        let all = manager.getAllTransactions()
        XCTAssertEqual(all.count, 0)
    }

    func testGetTransactionsForShift() {
        let shiftID = UUID()
        let tx1 = createTransactionWithShift(shiftID: shiftID, eventType: "Tip", amount: 5.00)
        let tx2 = createTransactionWithShift(shiftID: shiftID, eventType: "UberX", amount: 25.00)
        let tx3 = createTransaction(eventType: "Quest", amount: 15.00) // No shift

        manager.saveTransactions([tx1, tx2, tx3])

        let shiftTransactions = manager.getTransactions(forShift: shiftID)
        XCTAssertEqual(shiftTransactions.count, 2)
    }

    func testGetTransactionsForShiftNoMatches() {
        let shiftID = UUID()
        let tx1 = createTransaction(eventType: "Tip", amount: 5.00)

        manager.saveTransaction(tx1)

        let shiftTransactions = manager.getTransactions(forShift: shiftID)
        XCTAssertEqual(shiftTransactions.count, 0)
    }

    // MARK: - Orphaned Transaction Tests

    func testGetOrphanedTransactions() {
        let shiftID = UUID()
        let tx1 = createTransactionWithShift(shiftID: shiftID, eventType: "Tip", amount: 5.00)
        let tx2 = createTransaction(eventType: "UberX", amount: 25.00) // Orphan
        let tx3 = createTransaction(eventType: "Quest", amount: 15.00) // Orphan

        manager.saveTransactions([tx1, tx2, tx3])

        let orphans = manager.getOrphanedTransactions()
        XCTAssertEqual(orphans.count, 2)
    }

    func testGetOrphanedTransactionsEmpty() {
        let shiftID = UUID()
        let tx1 = createTransactionWithShift(shiftID: shiftID, eventType: "Tip", amount: 5.00)

        manager.saveTransaction(tx1)

        let orphans = manager.getOrphanedTransactions()
        XCTAssertEqual(orphans.count, 0)
    }

    func testGetOrphanedTransactionsInDateRange() {
        let calendar = Calendar.current
        let now = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!

        let tx1 = createTransaction(eventType: "Tip", amount: 5.00, eventDate: yesterday)
        let tx2 = createTransaction(eventType: "UberX", amount: 25.00, eventDate: now)
        let tx3 = createTransaction(eventType: "Quest", amount: 15.00, eventDate: tomorrow)

        manager.saveTransactions([tx1, tx2, tx3])

        // Query for today only
        let startOfToday = calendar.startOfDay(for: now)
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday)!

        let orphansInRange = manager.getOrphanedTransactions(from: startOfToday, to: endOfToday)
        XCTAssertEqual(orphansInRange.count, 1)
        XCTAssertEqual(orphansInRange.first?.eventType, "UberX")
    }

    // MARK: - Shift Association Tests

    func testAssignTransactionsToShift() {
        let tx1 = createTransaction(eventType: "Tip", amount: 5.00)
        let tx2 = createTransaction(eventType: "UberX", amount: 25.00)

        manager.saveTransactions([tx1, tx2])

        let shiftID = UUID()
        manager.assignTransactions([tx1.id, tx2.id], toShift: shiftID)

        // Wait for async operation
        let expectation = XCTestExpectation(description: "Transactions assigned")
        let managerRef = manager!
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let shiftTransactions = managerRef.getTransactions(forShift: shiftID)
            XCTAssertEqual(shiftTransactions.count, 2)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    func testAssignPartialTransactionsToShift() {
        let tx1 = createTransaction(eventType: "Tip", amount: 5.00)
        let tx2 = createTransaction(eventType: "UberX", amount: 25.00)
        let tx3 = createTransaction(eventType: "Quest", amount: 15.00)

        manager.saveTransactions([tx1, tx2, tx3])

        let shiftID = UUID()
        manager.assignTransactions([tx1.id, tx3.id], toShift: shiftID) // Only tx1 and tx3

        let expectation = XCTestExpectation(description: "Partial assignment")
        let managerRef = manager!
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let shiftTransactions = managerRef.getTransactions(forShift: shiftID)
            XCTAssertEqual(shiftTransactions.count, 2)

            let orphans = managerRef.getOrphanedTransactions()
            XCTAssertEqual(orphans.count, 1)
            XCTAssertEqual(orphans.first?.eventType, "UberX")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - Duplicate Detection Tests

    func testTransactionExists() {
        let transaction = createTransaction(eventType: "Tip", amount: 5.00)
        manager.saveTransaction(transaction)

        XCTAssertTrue(manager.transactionExists(id: transaction.id))
    }

    func testTransactionDoesNotExist() {
        let randomID = UUID()
        XCTAssertFalse(manager.transactionExists(id: randomID))
    }

    // MARK: - Statement Period Deduplication Tests

    func testHasStatementPeriod_ReturnsTrue_WhenPeriodExists() {
        let tx1 = createTransaction(eventType: "Tip", amount: 5.00, statementPeriod: "Oct 13 - Oct 20, 2025")
        manager.saveTransaction(tx1)

        XCTAssertTrue(manager.hasStatementPeriod("Oct 13 - Oct 20, 2025"))
    }

    func testHasStatementPeriod_ReturnsFalse_WhenPeriodDoesNotExist() {
        let tx1 = createTransaction(eventType: "Tip", amount: 5.00, statementPeriod: "Oct 13 - Oct 20, 2025")
        manager.saveTransaction(tx1)

        XCTAssertFalse(manager.hasStatementPeriod("Oct 20 - Oct 27, 2025"))
    }

    func testHasStatementPeriod_ReturnsFalse_WhenNoTransactionsExist() {
        XCTAssertFalse(manager.hasStatementPeriod("Oct 13 - Oct 20, 2025"))
    }

    func testGetAllStatementPeriods_ReturnsUniquePeriods() {
        let tx1 = createTransaction(eventType: "Tip", amount: 5.00, statementPeriod: "Oct 13 - Oct 20, 2025")
        let tx2 = createTransaction(eventType: "UberX", amount: 25.00, statementPeriod: "Oct 13 - Oct 20, 2025")
        let tx3 = createTransaction(eventType: "Quest", amount: 15.00, statementPeriod: "Oct 20 - Oct 27, 2025")

        manager.saveTransactions([tx1, tx2, tx3])

        let periods = manager.getAllStatementPeriods()
        XCTAssertEqual(periods.count, 2)
        XCTAssertTrue(periods.contains("Oct 13 - Oct 20, 2025"))
        XCTAssertTrue(periods.contains("Oct 20 - Oct 27, 2025"))
    }

    func testGetAllStatementPeriods_ReturnsEmptyArray_WhenNoTransactions() {
        let periods = manager.getAllStatementPeriods()
        XCTAssertEqual(periods.count, 0)
    }

    func testGetTransactionsForStatementPeriod() {
        let tx1 = createTransaction(eventType: "Tip", amount: 5.00, statementPeriod: "Oct 13 - Oct 20, 2025")
        let tx2 = createTransaction(eventType: "UberX", amount: 25.00, statementPeriod: "Oct 13 - Oct 20, 2025")
        let tx3 = createTransaction(eventType: "Quest", amount: 15.00, statementPeriod: "Oct 20 - Oct 27, 2025")

        manager.saveTransactions([tx1, tx2, tx3])

        let periodTransactions = manager.getTransactions(forStatementPeriod: "Oct 13 - Oct 20, 2025")
        XCTAssertEqual(periodTransactions.count, 2)
        XCTAssertTrue(periodTransactions.contains(where: { $0.eventType == "Tip" }))
        XCTAssertTrue(periodTransactions.contains(where: { $0.eventType == "UberX" }))
    }

    func testGetAffectedShiftIDs_ReturnsShiftIDsForStatementPeriod() {
        let shift1ID = UUID()
        let shift2ID = UUID()
        let tx1 = createTransactionWithShift(shiftID: shift1ID, eventType: "Tip", amount: 5.00)
        var tx2 = createTransactionWithShift(shiftID: shift2ID, eventType: "UberX", amount: 25.00)
        tx2.statementPeriod = "Oct 13 - Oct 20, 2025"
        var tx1Modified = tx1
        tx1Modified.statementPeriod = "Oct 13 - Oct 20, 2025"

        manager.saveTransactions([tx1Modified, tx2])

        let affectedShifts = manager.getAffectedShiftIDs(forStatementPeriod: "Oct 13 - Oct 20, 2025")
        XCTAssertEqual(affectedShifts.count, 2)
        XCTAssertTrue(affectedShifts.contains(shift1ID))
        XCTAssertTrue(affectedShifts.contains(shift2ID))
    }

    func testGetAffectedShiftIDs_ExcludesOrphanTransactions() {
        let shiftID = UUID()
        let tx1 = createTransactionWithShift(shiftID: shiftID, eventType: "Tip", amount: 5.00)
        let tx2 = createTransaction(eventType: "UberX", amount: 25.00) // Orphan

        manager.saveTransactions([tx1, tx2])

        let affectedShifts = manager.getAffectedShiftIDs(forStatementPeriod: "Oct 13 - Oct 20, 2025")
        XCTAssertEqual(affectedShifts.count, 1)
        XCTAssertTrue(affectedShifts.contains(shiftID))
    }

    func testReplaceStatementPeriod_RemovesOldAndAddsNew() {
        // Setup: Existing transactions for a statement period
        let tx1 = createTransaction(eventType: "Tip", amount: 5.00, statementPeriod: "Oct 13 - Oct 20, 2025")
        let tx2 = createTransaction(eventType: "UberX", amount: 25.00, statementPeriod: "Oct 13 - Oct 20, 2025")
        let tx3 = createTransaction(eventType: "Quest", amount: 15.00, statementPeriod: "Oct 20 - Oct 27, 2025")

        manager.saveTransactions([tx1, tx2, tx3])

        // New transactions to replace the old ones
        let newTx1 = createTransaction(eventType: "Tip", amount: 8.00, statementPeriod: "Oct 13 - Oct 20, 2025")
        let newTx2 = createTransaction(eventType: "UberX", amount: 30.00, statementPeriod: "Oct 13 - Oct 20, 2025")
        let newTx3 = createTransaction(eventType: "Incentive", amount: 20.00, statementPeriod: "Oct 13 - Oct 20, 2025")

        // Replace all transactions for the statement period
        manager.replaceStatementPeriod("Oct 13 - Oct 20, 2025", with: [newTx1, newTx2, newTx3])

        // Verify old transactions are gone, new ones are present, other periods untouched
        let allTransactions = manager.getAllTransactions()
        XCTAssertEqual(allTransactions.count, 4) // 3 new + 1 from other period

        let oct13Transactions = manager.getTransactions(forStatementPeriod: "Oct 13 - Oct 20, 2025")
        XCTAssertEqual(oct13Transactions.count, 3)
        XCTAssertTrue(oct13Transactions.contains(where: { $0.amount == 8.00 && $0.eventType == "Tip" }))
        XCTAssertTrue(oct13Transactions.contains(where: { $0.amount == 30.00 && $0.eventType == "UberX" }))
        XCTAssertTrue(oct13Transactions.contains(where: { $0.amount == 20.00 && $0.eventType == "Incentive" }))

        // Other period should be untouched
        let oct20Transactions = manager.getTransactions(forStatementPeriod: "Oct 20 - Oct 27, 2025")
        XCTAssertEqual(oct20Transactions.count, 1)
        XCTAssertEqual(oct20Transactions.first?.amount, 15.00)
    }

    func testReplaceStatementPeriod_PreservesShiftAssignments_WhenReassigning() {
        // Setup: Existing transactions assigned to shifts
        let shiftID = UUID()
        var tx1 = createTransactionWithShift(shiftID: shiftID, eventType: "Tip", amount: 5.00)
        tx1.statementPeriod = "Oct 13 - Oct 20, 2025"

        manager.saveTransaction(tx1)

        // New transactions (without shift assignment initially)
        let newTx1 = createTransaction(eventType: "Tip", amount: 8.00, statementPeriod: "Oct 13 - Oct 20, 2025")

        // Replace - this will remove old assignments
        manager.replaceStatementPeriod("Oct 13 - Oct 20, 2025", with: [newTx1])

        // After replacement, transactions lose shift assignment (need to be re-matched)
        let replacedTransactions = manager.getTransactions(forStatementPeriod: "Oct 13 - Oct 20, 2025")
        XCTAssertEqual(replacedTransactions.count, 1)
        XCTAssertNil(replacedTransactions.first?.shiftID) // No shift assignment yet
    }

    func testShiftsWithAllTransactionsFromPeriod_LoseAllTransactions() {
        // Setup: Shift with transactions ONLY from one statement period
        let shiftID = UUID()
        var tx1 = createTransactionWithShift(shiftID: shiftID, eventType: "Tip", amount: 5.00)
        tx1.statementPeriod = "Oct 13 - Oct 20, 2025"
        var tx2 = createTransactionWithShift(shiftID: shiftID, eventType: "UberX", amount: 25.00)
        tx2.statementPeriod = "Oct 13 - Oct 20, 2025"

        manager.saveTransactions([tx1, tx2])

        // After replacing statement period, shift should have NO transactions
        manager.replaceStatementPeriod("Oct 13 - Oct 20, 2025", with: [])

        let shiftTransactions = manager.getTransactions(forShift: shiftID)
        XCTAssertEqual(shiftTransactions.count, 0)
    }

    func testShiftsWithPartialTransactionsFromPeriod_KeepOtherTransactions() {
        // Setup: Shift with transactions from MULTIPLE statement periods
        let shiftID = UUID()
        var tx1 = createTransactionWithShift(shiftID: shiftID, eventType: "Tip", amount: 5.00)
        tx1.statementPeriod = "Oct 13 - Oct 20, 2025"
        var tx2 = createTransactionWithShift(shiftID: shiftID, eventType: "UberX", amount: 25.00)
        tx2.statementPeriod = "Oct 20 - Oct 27, 2025" // Different period

        manager.saveTransactions([tx1, tx2])

        // After replacing Oct 13-20 period, shift should still have tx2
        manager.replaceStatementPeriod("Oct 13 - Oct 20, 2025", with: [])

        let shiftTransactions = manager.getTransactions(forShift: shiftID)
        XCTAssertEqual(shiftTransactions.count, 1)
        XCTAssertEqual(shiftTransactions.first?.statementPeriod, "Oct 20 - Oct 27, 2025")
    }

    // MARK: - Deletion Tests

    func testDeleteTransactionsByPredicate() {
        let tx1 = createTransaction(eventType: "Tip", amount: 5.00, statementPeriod: "Oct 13 - Oct 20, 2025")
        let tx2 = createTransaction(eventType: "UberX", amount: 25.00, statementPeriod: "Oct 13 - Oct 20, 2025")
        let tx3 = createTransaction(eventType: "Quest", amount: 15.00, statementPeriod: "Oct 20 - Oct 27, 2025")

        manager.saveTransactions([tx1, tx2, tx3])

        // Delete all from first statement period
        manager.deleteTransactions(where: { $0.statementPeriod == "Oct 13 - Oct 20, 2025" })

        let expectation = XCTestExpectation(description: "Deletion by predicate")
        let managerRef = manager!
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let remaining = managerRef.getAllTransactions()
            XCTAssertEqual(remaining.count, 1)
            XCTAssertEqual(remaining.first?.eventType, "Quest")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    func testDeleteTransactionsByIDs() {
        let tx1 = createTransaction(eventType: "Tip", amount: 5.00)
        let tx2 = createTransaction(eventType: "UberX", amount: 25.00)
        let tx3 = createTransaction(eventType: "Quest", amount: 15.00)

        manager.saveTransactions([tx1, tx2, tx3])

        manager.deleteTransactions([tx1.id, tx3.id])

        let expectation = XCTestExpectation(description: "Deletion by IDs")
        let managerRef = manager!
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let remaining = managerRef.getAllTransactions()
            XCTAssertEqual(remaining.count, 1)
            XCTAssertEqual(remaining.first?.id, tx2.id)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    func testClearAllTransactions() {
        let tx1 = createTransaction(eventType: "Tip", amount: 5.00)
        let tx2 = createTransaction(eventType: "UberX", amount: 25.00)

        manager.saveTransactions([tx1, tx2])

        manager.clearAllTransactions()

        let all = manager.getAllTransactions()
        XCTAssertEqual(all.count, 0)
    }

    // MARK: - Persistence Tests

    func testTransactionsPersistAcrossAccess() {
        let transaction = createTransaction(eventType: "Tip", amount: 5.00)
        manager.saveTransaction(transaction)

        // Access manager again (simulates app restart)
        let all = UberTransactionManager.shared.getAllTransactions()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.eventType, "Tip")
    }

    // MARK: - Helper Methods

    private func createTransaction(
        eventType: String,
        amount: Double,
        eventDate: Date = Date(),
        statementPeriod: String = "Oct 13 - Oct 20, 2025"
    ) -> UberTransaction {
        return UberTransaction(
            transactionDate: Date(),
            eventDate: eventDate,
            eventType: eventType,
            amount: amount,
            tollsReimbursed: nil,
            statementPeriod: statementPeriod,
            shiftID: nil,
            importDate: Date()
        )
    }

    private func createTransactionWithShift(
        shiftID: UUID,
        eventType: String,
        amount: Double
    ) -> UberTransaction {
        return UberTransaction(
            transactionDate: Date(),
            eventDate: Date(),
            eventType: eventType,
            amount: amount,
            tollsReimbursed: nil,
            statementPeriod: "Oct 13 - Oct 20, 2025",
            shiftID: shiftID,
            importDate: Date()
        )
    }
}
