//
//  BackupRestoreTests.swift
//  Rideshare TrackerTests
//
//  Created by Claude on 11/5/25.
//

import XCTest
import Foundation
import SwiftUI
@testable import Rideshare_Tracker

/// Tests for backup restore functionality with duplicate handling
/// Tests all three restore actions: Clear & Restore, Restore Missing, Merge & Restore
@MainActor
final class BackupRestoreTests: RideshareTrackerTestBase {

    // MARK: - Test Helpers

    /// Helper to create clean manager instances for testing
    private func createCleanManagers() -> (ShiftDataManager, ExpenseDataManager, PreferencesManager, BackupRestoreManager) {
        let shiftManager = ShiftDataManager(forEnvironment: true)
        let expenseManager = ExpenseDataManager(forEnvironment: true)

        // Clear any existing data from UserDefaults
        shiftManager.shifts.removeAll()
        expenseManager.expenses.removeAll()

        return (shiftManager, expenseManager, PreferencesManager.shared, BackupRestoreManager.shared)
    }

    /// Creates a test shift with a specific UUID
    
    private func createTestShift(id: UUID, startDate: Date, startMileage: Double, earnings: Double) -> RideshareShift {
        var shift = RideshareShift(
            startDate: startDate,
            startMileage: startMileage,
            startTankReading: 8.0,
            hasFullTankAtStart: true,
            gasPrice: 2.00,
            standardMileageRate: 0.67
        )
        shift.id = id
        shift.endDate = startDate.addingTimeInterval(3600) // 1 hour later
        shift.endMileage = startMileage + 50.0
        shift.endTankReading = 6.0
        shift.netFare = earnings // Use netFare instead of earnings
        shift.tolls = 5.0 // Use tolls instead of tollAmount
        return shift
    }

    /// Creates a test expense with a specific UUID
    
    private func createTestExpense(id: UUID, date: Date, amount: Double, description: String) -> ExpenseItem {
        var expense = ExpenseItem(
            date: date,
            category: .vehicle,
            description: description,
            amount: amount
        )
        expense.id = id
        return expense
    }

    /// Creates a BackupData object for testing

    private func createBackupData(shifts: [RideshareShift], expenses: [ExpenseItem], uberTransactions: [UberTransaction]? = nil) -> BackupData {
        return BackupData(
            shifts: shifts,
            expenses: expenses,
            uberTransactions: uberTransactions,
            preferences: BackupPreferences(
                tankCapacity: 15.0,
                gasPrice: 2.50,
                standardMileageRate: 0.70,
                weekStartDay: 1,
                dateFormat: "MM/dd/yyyy",
                timeFormat: "h:mm a",
                timeZoneIdentifier: "America/New_York",
                tipDeductionEnabled: true,
                effectivePersonalTaxRate: 0.22,
                incrementalSyncEnabled: false,
                syncFrequency: "daily", // String value, not enum
                lastIncrementalSyncDate: nil
            ),
            exportDate: Date(),
            appVersion: "1.0"
        )
    }

    /// Creates a test Uber transaction with a specific UUID
    private func createTestTransaction(id: UUID, shiftID: UUID?, date: Date, amount: Double, type: String = "Tip") -> UberTransaction {
        return UberTransaction(
            id: id,
            transactionDate: date,
            eventDate: date,
            eventType: type,
            amount: amount,
            tollsReimbursed: type == "UberX" ? 5.0 : nil,
            statementPeriod: "Test Period",
            shiftID: shiftID,
            importDate: date
        )
    }

    // MARK: - Clear & Restore Tests


    func testClearAndRestoreRemovesAllExistingData() async throws {
        // Create clean manager instances for this test
        let (shiftManager, expenseManager, preferencesManager, backupRestoreManager) = createCleanManagers()

        // Given: Current data with 3 shifts and 2 expenses
        let currentShiftA = createTestShift(id: UUID(), startDate: Date(), startMileage: 100, earnings: 50)
        let currentShiftB = createTestShift(id: UUID(), startDate: Date().addingTimeInterval(3600), startMileage: 150, earnings: 60)
        let currentShiftC = createTestShift(id: UUID(), startDate: Date().addingTimeInterval(7200), startMileage: 200, earnings: 70)

        shiftManager.addShift(currentShiftA)
        shiftManager.addShift(currentShiftB)
        shiftManager.addShift(currentShiftC)

        let currentExpenseA = createTestExpense(id: UUID(), date: Date(), amount: 25, description: "Current Expense A")
        let currentExpenseB = createTestExpense(id: UUID(), date: Date(), amount: 30, description: "Current Expense B")

        expenseManager.addExpense(currentExpenseA)
        expenseManager.addExpense(currentExpenseB)

        XCTAssertEqual(shiftManager.shifts.count, 3, "Should start with 3 shifts")
        XCTAssertEqual(expenseManager.expenses.count, 2, "Should start with 2 expenses")

        // When: Restore backup with 2 different shifts and 1 different expense using Clear & Restore
        let backupShiftD = createTestShift(id: UUID(), startDate: Date().addingTimeInterval(10800), startMileage: 300, earnings: 80)
        let backupShiftE = createTestShift(id: UUID(), startDate: Date().addingTimeInterval(14400), startMileage: 350, earnings: 90)
        let backupExpenseC = createTestExpense(id: UUID(), date: Date(), amount: 40, description: "Backup Expense C")

        let backupData = createBackupData(shifts: [backupShiftD, backupShiftE], expenses: [backupExpenseC])

        let result = backupRestoreManager.restoreFromBackup(
            backupData: backupData,
            shiftManager: shiftManager,
            expenseManager: expenseManager,
            preferencesManager: preferencesManager,
            action: .replaceAll
        )

        // Then: All current data removed, only backup data present
        XCTAssertEqual(shiftManager.shifts.count, 2, "Should have exactly 2 shifts from backup")
        XCTAssertEqual(expenseManager.expenses.count, 1, "Should have exactly 1 expense from backup")

        // Verify result counts
        XCTAssertEqual(result.shiftsAdded, 2, "Should add 2 shifts")
        XCTAssertEqual(result.shiftsUpdated, 0, "Should not update any shifts")
        XCTAssertEqual(result.shiftsSkipped, 0, "Should not skip any shifts")
        XCTAssertEqual(result.expensesAdded, 1, "Should add 1 expense")
        XCTAssertEqual(result.expensesUpdated, 0, "Should not update any expenses")
        XCTAssertEqual(result.expensesSkipped, 0, "Should not skip any expenses")

        // Verify correct shifts are present
        XCTAssertTrue(shiftManager.shifts.contains { $0.id == backupShiftD.id }, "Should contain backup shift D")
        XCTAssertTrue(shiftManager.shifts.contains { $0.id == backupShiftE.id }, "Should contain backup shift E")
        XCTAssertFalse(shiftManager.shifts.contains { $0.id == currentShiftA.id }, "Should not contain current shift A")
        XCTAssertFalse(shiftManager.shifts.contains { $0.id == currentShiftB.id }, "Should not contain current shift B")
        XCTAssertFalse(shiftManager.shifts.contains { $0.id == currentShiftC.id }, "Should not contain current shift C")

        // Verify correct expenses are present
        XCTAssertTrue(expenseManager.expenses.contains { $0.id == backupExpenseC.id }, "Should contain backup expense C")
        XCTAssertFalse(expenseManager.expenses.contains { $0.id == currentExpenseA.id }, "Should not contain current expense A")
        XCTAssertFalse(expenseManager.expenses.contains { $0.id == currentExpenseB.id }, "Should not contain current expense B")
    }


    func testClearAndRestoreWithEmptyBackup() async throws {
        // Create clean manager instances for this test
        let (shiftManager, expenseManager, preferencesManager, backupRestoreManager) = createCleanManagers()

        // Given: Current data exists
        let currentShift = createTestShift(id: UUID(), startDate: Date(), startMileage: 100, earnings: 50)
        shiftManager.addShift(currentShift)

        XCTAssertEqual(shiftManager.shifts.count, 1, "Should start with 1 shift")

        // When: Restore empty backup using Clear & Restore
        let backupData = createBackupData(shifts: [], expenses: [])

        let result = backupRestoreManager.restoreFromBackup(
            backupData: backupData,
            shiftManager: shiftManager,
            expenseManager: expenseManager,
            preferencesManager: preferencesManager,
            action: .replaceAll
        )

        // Then: All data should be cleared
        XCTAssertEqual(shiftManager.shifts.count, 0, "Should have no shifts")
        XCTAssertEqual(expenseManager.expenses.count, 0, "Should have no expenses")
        XCTAssertEqual(result.shiftsAdded, 0, "Should not add any shifts")
    }

    // MARK: - Restore Missing (Skip Duplicates) Tests


    func testRestoreMissingSkipsDuplicatesAddsMissing() async throws {
        // Create clean manager instances for this test
        let (shiftManager, expenseManager, preferencesManager, backupRestoreManager) = createCleanManagers()

        // Given: Current data with shifts A, B, C
        let shiftIdA = UUID()
        let shiftIdB = UUID()
        let shiftIdC = UUID()

        let currentShiftA = createTestShift(id: shiftIdA, startDate: Date(), startMileage: 100, earnings: 50)
        let currentShiftB = createTestShift(id: shiftIdB, startDate: Date().addingTimeInterval(3600), startMileage: 150, earnings: 60)
        let currentShiftC = createTestShift(id: shiftIdC, startDate: Date().addingTimeInterval(7200), startMileage: 200, earnings: 70)

        shiftManager.addShift(currentShiftA)
        shiftManager.addShift(currentShiftB)
        shiftManager.addShift(currentShiftC)

        let expenseIdA = UUID()
        let currentExpenseA = createTestExpense(id: expenseIdA, date: Date(), amount: 25, description: "Current Expense A")
        expenseManager.addExpense(currentExpenseA)

        XCTAssertEqual(shiftManager.shifts.count, 3, "Should start with 3 shifts")
        XCTAssertEqual(expenseManager.expenses.count, 1, "Should start with 1 expense")

        // When: Restore backup with shifts B (duplicate), C (duplicate), D (new), E (new)
        let shiftIdD = UUID()
        let shiftIdE = UUID()

        // Create backup versions of B and C with modified values
        let backupShiftB = createTestShift(id: shiftIdB, startDate: Date().addingTimeInterval(3600), startMileage: 150, earnings: 999) // Different earnings
        let backupShiftC = createTestShift(id: shiftIdC, startDate: Date().addingTimeInterval(7200), startMileage: 200, earnings: 888) // Different earnings
        let backupShiftD = createTestShift(id: shiftIdD, startDate: Date().addingTimeInterval(10800), startMileage: 300, earnings: 80)
        let backupShiftE = createTestShift(id: shiftIdE, startDate: Date().addingTimeInterval(14400), startMileage: 350, earnings: 90)

        let expenseIdB = UUID()
        let backupExpenseA = createTestExpense(id: expenseIdA, date: Date(), amount: 999, description: "Modified Expense A") // Duplicate
        let backupExpenseB = createTestExpense(id: expenseIdB, date: Date(), amount: 30, description: "Backup Expense B") // New

        let backupData = createBackupData(
            shifts: [backupShiftB, backupShiftC, backupShiftD, backupShiftE],
            expenses: [backupExpenseA, backupExpenseB]
        )

        let result = backupRestoreManager.restoreFromBackup(
            backupData: backupData,
            shiftManager: shiftManager,
            expenseManager: expenseManager,
            preferencesManager: preferencesManager,
            action: .skipDuplicates
        )

        // Then: Should have A, B, C (original), D, E (added)
        XCTAssertEqual(shiftManager.shifts.count, 5, "Should have 5 shifts total")
        XCTAssertEqual(expenseManager.expenses.count, 2, "Should have 2 expenses total")

        // Verify result counts
        XCTAssertEqual(result.shiftsAdded, 2, "Should add 2 new shifts (D, E)")
        XCTAssertEqual(result.shiftsUpdated, 0, "Should not update any shifts")
        XCTAssertEqual(result.shiftsSkipped, 2, "Should skip 2 duplicate shifts (B, C)")
        XCTAssertEqual(result.expensesAdded, 1, "Should add 1 new expense (B)")
        XCTAssertEqual(result.expensesUpdated, 0, "Should not update any expenses")
        XCTAssertEqual(result.expensesSkipped, 1, "Should skip 1 duplicate expense (A)")

        // Verify original values preserved (not modified by backup)
        let preservedShiftB = shiftManager.shifts.first { $0.id == shiftIdB }
        XCTAssertNotNil(preservedShiftB, "Shift B should exist")
        XCTAssertEqual(preservedShiftB?.netFare ?? 0, 60, accuracy: 0.01, "Shift B should keep original netFare, not backup value")

        let preservedShiftC = shiftManager.shifts.first { $0.id == shiftIdC }
        XCTAssertNotNil(preservedShiftC, "Shift C should exist")
        XCTAssertEqual(preservedShiftC?.netFare ?? 0, 70, accuracy: 0.01, "Shift C should keep original netFare, not backup value")

        let preservedExpenseA = expenseManager.expenses.first { $0.id == expenseIdA }
        XCTAssertNotNil(preservedExpenseA, "Expense A should exist")
        XCTAssertEqual(preservedExpenseA?.amount ?? 0, 25, accuracy: 0.01, "Expense A should keep original amount, not backup value")

        // Verify new shifts added
        XCTAssertTrue(shiftManager.shifts.contains { $0.id == shiftIdA }, "Should contain shift A")
        XCTAssertTrue(shiftManager.shifts.contains { $0.id == shiftIdD }, "Should contain shift D")
        XCTAssertTrue(shiftManager.shifts.contains { $0.id == shiftIdE }, "Should contain shift E")

        // Verify new expense added
        XCTAssertTrue(expenseManager.expenses.contains { $0.id == expenseIdB }, "Should contain expense B")
    }


    func testRestoreMissingWithEmptyCurrentData() async throws {
        // Create clean manager instances for this test
        let (shiftManager, expenseManager, preferencesManager, backupRestoreManager) = createCleanManagers()

        // Given: No current data
        XCTAssertEqual(shiftManager.shifts.count, 0, "Should start with no shifts")

        // When: Restore backup with 2 shifts
        let shiftA = createTestShift(id: UUID(), startDate: Date(), startMileage: 100, earnings: 50)
        let shiftB = createTestShift(id: UUID(), startDate: Date().addingTimeInterval(3600), startMileage: 150, earnings: 60)

        let backupData = createBackupData(shifts: [shiftA, shiftB], expenses: [])

        let result = backupRestoreManager.restoreFromBackup(
            backupData: backupData,
            shiftManager: shiftManager,
            expenseManager: expenseManager,
            preferencesManager: preferencesManager,
            action: .skipDuplicates
        )

        // Then: All backup data should be added
        XCTAssertEqual(shiftManager.shifts.count, 2, "Should add all shifts from backup")
        XCTAssertEqual(result.shiftsAdded, 2, "Should add 2 shifts")
        XCTAssertEqual(result.shiftsSkipped, 0, "Should skip 0 shifts")
    }

    // MARK: - Merge & Restore Tests


    func testMergeAndRestoreUpdatesExistingAddsNew() async throws {
        // Create clean manager instances for this test
        let (shiftManager, expenseManager, preferencesManager, backupRestoreManager) = createCleanManagers()

        // Given: Current data with shifts A, B, C
        let shiftIdA = UUID()
        let shiftIdB = UUID()
        let shiftIdC = UUID()

        let currentShiftA = createTestShift(id: shiftIdA, startDate: Date(), startMileage: 100, earnings: 50)
        let currentShiftB = createTestShift(id: shiftIdB, startDate: Date().addingTimeInterval(3600), startMileage: 150, earnings: 60)
        let currentShiftC = createTestShift(id: shiftIdC, startDate: Date().addingTimeInterval(7200), startMileage: 200, earnings: 70)

        shiftManager.addShift(currentShiftA)
        shiftManager.addShift(currentShiftB)
        shiftManager.addShift(currentShiftC)

        let expenseIdA = UUID()
        let expenseIdB = UUID()
        let currentExpenseA = createTestExpense(id: expenseIdA, date: Date(), amount: 25, description: "Current Expense A")
        let currentExpenseB = createTestExpense(id: expenseIdB, date: Date(), amount: 30, description: "Current Expense B")

        expenseManager.addExpense(currentExpenseA)
        expenseManager.addExpense(currentExpenseB)

        XCTAssertEqual(shiftManager.shifts.count, 3, "Should start with 3 shifts")
        XCTAssertEqual(expenseManager.expenses.count, 2, "Should start with 2 expenses")

        // When: Restore backup with modified B, C and new D
        let shiftIdD = UUID()

        let backupShiftB = createTestShift(id: shiftIdB, startDate: Date().addingTimeInterval(3600), startMileage: 150, earnings: 999) // Modified
        let backupShiftC = createTestShift(id: shiftIdC, startDate: Date().addingTimeInterval(7200), startMileage: 200, earnings: 888) // Modified
        let backupShiftD = createTestShift(id: shiftIdD, startDate: Date().addingTimeInterval(10800), startMileage: 300, earnings: 80) // New

        let expenseIdC = UUID()
        let backupExpenseA = createTestExpense(id: expenseIdA, date: Date(), amount: 999, description: "Modified Expense A") // Modified
        let backupExpenseC = createTestExpense(id: expenseIdC, date: Date(), amount: 40, description: "Backup Expense C") // New

        let backupData = createBackupData(
            shifts: [backupShiftB, backupShiftC, backupShiftD],
            expenses: [backupExpenseA, backupExpenseC]
        )

        let result = backupRestoreManager.restoreFromBackup(
            backupData: backupData,
            shiftManager: shiftManager,
            expenseManager: expenseManager,
            preferencesManager: preferencesManager,
            action: .merge
        )

        // Then: Should have A (unchanged), B (updated), C (updated), D (added)
        XCTAssertEqual(shiftManager.shifts.count, 4, "Should have 4 shifts total")
        XCTAssertEqual(expenseManager.expenses.count, 3, "Should have 3 expenses total")

        // Verify result counts
        XCTAssertEqual(result.shiftsAdded, 1, "Should add 1 new shift (D)")
        XCTAssertEqual(result.shiftsUpdated, 2, "Should update 2 shifts (B, C)")
        XCTAssertEqual(result.shiftsSkipped, 0, "Should skip 0 shifts")
        XCTAssertEqual(result.expensesAdded, 1, "Should add 1 new expense (C)")
        XCTAssertEqual(result.expensesUpdated, 1, "Should update 1 expense (A)")
        XCTAssertEqual(result.expensesSkipped, 0, "Should skip 0 expenses")

        // Verify shift A unchanged
        let shiftA = shiftManager.shifts.first { $0.id == shiftIdA }
        XCTAssertNotNil(shiftA, "Shift A should exist")
        XCTAssertEqual(shiftA?.netFare ?? 0, 50, accuracy: 0.01, "Shift A should keep original netFare")

        // Verify shift B updated to backup values
        let shiftB = shiftManager.shifts.first { $0.id == shiftIdB }
        XCTAssertNotNil(shiftB, "Shift B should exist")
        XCTAssertEqual(shiftB?.netFare ?? 0, 999, accuracy: 0.01, "Shift B should have backup netFare")

        // Verify shift C updated to backup values
        let shiftC = shiftManager.shifts.first { $0.id == shiftIdC }
        XCTAssertNotNil(shiftC, "Shift C should exist")
        XCTAssertEqual(shiftC?.netFare ?? 0, 888, accuracy: 0.01, "Shift C should have backup netFare")

        // Verify shift D added
        let shiftD = shiftManager.shifts.first { $0.id == shiftIdD }
        XCTAssertNotNil(shiftD, "Shift D should exist")
        XCTAssertEqual(shiftD?.netFare ?? 0, 80, accuracy: 0.01, "Shift D should have backup netFare")

        // Verify expense A updated
        let expenseA = expenseManager.expenses.first { $0.id == expenseIdA }
        XCTAssertNotNil(expenseA, "Expense A should exist")
        XCTAssertEqual(expenseA?.amount ?? 0, 999, accuracy: 0.01, "Expense A should have backup amount")

        // Verify expense B unchanged
        let expenseB = expenseManager.expenses.first { $0.id == expenseIdB }
        XCTAssertNotNil(expenseB, "Expense B should exist")
        XCTAssertEqual(expenseB?.amount ?? 0, 30, accuracy: 0.01, "Expense B should keep original amount")

        // Verify expense C added
        let expenseC = expenseManager.expenses.first { $0.id == expenseIdC }
        XCTAssertNotNil(expenseC, "Expense C should exist")
        XCTAssertEqual(expenseC?.amount ?? 0, 40, accuracy: 0.01, "Expense C should have backup amount")
    }


    func testMergeAndRestoreKeepsShiftsNotInBackup() async throws {
        // Create clean manager instances for this test
        let (shiftManager, expenseManager, preferencesManager, backupRestoreManager) = createCleanManagers()

        // Given: Current data with shifts A, B, C
        let shiftIdA = UUID()
        let shiftIdB = UUID()
        let shiftIdC = UUID()

        let currentShiftA = createTestShift(id: shiftIdA, startDate: Date(), startMileage: 100, earnings: 50)
        let currentShiftB = createTestShift(id: shiftIdB, startDate: Date().addingTimeInterval(3600), startMileage: 150, earnings: 60)
        let currentShiftC = createTestShift(id: shiftIdC, startDate: Date().addingTimeInterval(7200), startMileage: 200, earnings: 70)

        shiftManager.addShift(currentShiftA)
        shiftManager.addShift(currentShiftB)
        shiftManager.addShift(currentShiftC)

        XCTAssertEqual(shiftManager.shifts.count, 3, "Should start with 3 shifts")

        // When: Restore backup with only shift B (modified)
        let backupShiftB = createTestShift(id: shiftIdB, startDate: Date().addingTimeInterval(3600), startMileage: 150, earnings: 999)

        let backupData = createBackupData(shifts: [backupShiftB], expenses: [])

        let result = backupRestoreManager.restoreFromBackup(
            backupData: backupData,
            shiftManager: shiftManager,
            expenseManager: expenseManager,
            preferencesManager: preferencesManager,
            action: .merge
        )

        // Then: Should have A (unchanged), B (updated), C (unchanged)
        XCTAssertEqual(shiftManager.shifts.count, 3, "Should still have 3 shifts")
        XCTAssertEqual(result.shiftsAdded, 0, "Should add 0 shifts")
        XCTAssertEqual(result.shiftsUpdated, 1, "Should update 1 shift (B)")

        // Verify all shifts present
        XCTAssertTrue(shiftManager.shifts.contains { $0.id == shiftIdA }, "Should contain shift A")
        XCTAssertTrue(shiftManager.shifts.contains { $0.id == shiftIdB }, "Should contain shift B")
        XCTAssertTrue(shiftManager.shifts.contains { $0.id == shiftIdC }, "Should contain shift C")

        // Verify shift B updated
        let shiftB = shiftManager.shifts.first { $0.id == shiftIdB }
        XCTAssertEqual(shiftB?.netFare ?? 0, 999, accuracy: 0.01, "Shift B should have backup netFare")

        // Verify shifts A and C unchanged
        let shiftA = shiftManager.shifts.first { $0.id == shiftIdA }
        XCTAssertEqual(shiftA?.netFare ?? 0, 50, accuracy: 0.01, "Shift A should keep original netFare")

        let shiftC = shiftManager.shifts.first { $0.id == shiftIdC }
        XCTAssertEqual(shiftC?.netFare ?? 0, 70, accuracy: 0.01, "Shift C should keep original netFare")
    }

    // MARK: - Preferences Restore Tests


    func testRestoreAlwaysUpdatesPreferences() async throws {
        // Create clean manager instances for this test
        let (shiftManager, expenseManager, preferencesManager, backupRestoreManager) = createCleanManagers()

        // Given: Current preferences
        let currentPrefs = preferencesManager.preferences
        XCTAssertEqual(currentPrefs.tankCapacity, 15.0, accuracy: 0.01, "Should have default tank capacity")

        // When: Restore backup with different preferences
        let backupData = createBackupData(shifts: [], expenses: [])

        _ = backupRestoreManager.restoreFromBackup(
            backupData: backupData,
            shiftManager: shiftManager,
            expenseManager: expenseManager,
            preferencesManager: preferencesManager,
            action: .skipDuplicates // Action doesn't matter for preferences
        )

        // Then: Preferences should be updated from backup
        let updatedPrefs = preferencesManager.preferences
        XCTAssertEqual(updatedPrefs.tankCapacity, 15.0, accuracy: 0.01, "Tank capacity should be restored from backup")
        XCTAssertEqual(updatedPrefs.gasPrice, 2.50, accuracy: 0.01, "Gas price should be restored from backup")
        XCTAssertEqual(updatedPrefs.standardMileageRate, 0.70, accuracy: 0.01, "Mileage rate should be restored from backup")
    }

    // MARK: - Edge Case Tests


    func testRestoreWithIdenticalDataSkipsAll() async throws {
        // Create clean manager instances for this test
        let (shiftManager, expenseManager, preferencesManager, backupRestoreManager) = createCleanManagers()

        // Given: Current data
        let shiftIdA = UUID()
        let shiftA = createTestShift(id: shiftIdA, startDate: Date(), startMileage: 100, earnings: 50)
        shiftManager.addShift(shiftA)

        // When: Restore identical data using skipDuplicates
        let backupShiftA = createTestShift(id: shiftIdA, startDate: Date(), startMileage: 100, earnings: 50)
        let backupData = createBackupData(shifts: [backupShiftA], expenses: [])

        let result = backupRestoreManager.restoreFromBackup(
            backupData: backupData,
            shiftManager: shiftManager,
            expenseManager: expenseManager,
            preferencesManager: preferencesManager,
            action: .skipDuplicates
        )

        // Then: Nothing should be added or updated
        XCTAssertEqual(shiftManager.shifts.count, 1, "Should still have 1 shift")
        XCTAssertEqual(result.shiftsAdded, 0, "Should add 0 shifts")
        XCTAssertEqual(result.shiftsSkipped, 1, "Should skip 1 shift")
    }


    func testRestoreWithNoExpensesInBackup() async throws {
        // Create clean manager instances for this test
        let (shiftManager, expenseManager, preferencesManager, backupRestoreManager) = createCleanManagers()

        // Given: Current expenses
        let expense = createTestExpense(id: UUID(), date: Date(), amount: 25, description: "Test")
        expenseManager.addExpense(expense)

        XCTAssertEqual(expenseManager.expenses.count, 1, "Should start with 1 expense")

        // When: Restore backup with nil expenses using Merge
        var backupData = createBackupData(shifts: [], expenses: [])
        backupData = BackupData(
            shifts: backupData.shifts,
            expenses: nil, // nil expenses
            uberTransactions: nil,
            preferences: backupData.preferences,
            exportDate: backupData.exportDate,
            appVersion: backupData.appVersion
        )

        let result = backupRestoreManager.restoreFromBackup(
            backupData: backupData,
            shiftManager: shiftManager,
            expenseManager: expenseManager,
            preferencesManager: preferencesManager,
            action: .merge
        )

        // Then: Existing expense should remain
        XCTAssertEqual(expenseManager.expenses.count, 1, "Should still have 1 expense")
        XCTAssertEqual(result.expensesAdded, 0, "Should add 0 expenses")
        XCTAssertEqual(result.expensesUpdated, 0, "Should update 0 expenses")
    }

    // MARK: - Uber Transaction Backup/Restore Tests

    func testClearAndRestoreWithUberTransactions() async throws {
        // Create clean manager instances for this test
        let (shiftManager, expenseManager, preferencesManager, backupRestoreManager) = createCleanManagers()
        let transactionManager = UberTransactionManager.shared
        transactionManager.clearAllTransactions()

        // Given: Current Uber transactions
        let shiftID = UUID()
        let currentTxnA = createTestTransaction(id: UUID(), shiftID: shiftID, date: Date(), amount: 10.0)
        let currentTxnB = createTestTransaction(id: UUID(), shiftID: shiftID, date: Date(), amount: 15.0)
        transactionManager.saveTransactions([currentTxnA, currentTxnB])

        XCTAssertEqual(transactionManager.getAllTransactions().count, 2, "Should start with 2 transactions")

        // When: Restore backup with different transactions using Clear & Restore
        let backupShiftID = UUID()
        let backupTxnC = createTestTransaction(id: UUID(), shiftID: backupShiftID, date: Date(), amount: 20.0)
        let backupTxnD = createTestTransaction(id: UUID(), shiftID: backupShiftID, date: Date(), amount: 25.0)
        let backupTxnE = createTestTransaction(id: UUID(), shiftID: nil, date: Date(), amount: 30.0) // Orphaned

        let backupData = createBackupData(shifts: [], expenses: [], uberTransactions: [backupTxnC, backupTxnD, backupTxnE])

        let result = backupRestoreManager.restoreFromBackup(
            backupData: backupData,
            shiftManager: shiftManager,
            expenseManager: expenseManager,
            preferencesManager: preferencesManager,
            action: .replaceAll
        )

        // Then: All current transactions removed, only backup transactions present
        let allTransactions = transactionManager.getAllTransactions()
        XCTAssertEqual(allTransactions.count, 3, "Should have exactly 3 transactions from backup")

        XCTAssertEqual(result.transactionsAdded, 3, "Should add 3 transactions")
        XCTAssertEqual(result.transactionsUpdated, 0, "Should not update any transactions")
        XCTAssertEqual(result.transactionsSkipped, 0, "Should not skip any transactions")

        // Verify correct transactions are present
        XCTAssertTrue(allTransactions.contains { $0.id == backupTxnC.id }, "Should contain backup transaction C")
        XCTAssertTrue(allTransactions.contains { $0.id == backupTxnD.id }, "Should contain backup transaction D")
        XCTAssertTrue(allTransactions.contains { $0.id == backupTxnE.id }, "Should contain backup transaction E")
        XCTAssertFalse(allTransactions.contains { $0.id == currentTxnA.id }, "Should not contain current transaction A")
        XCTAssertFalse(allTransactions.contains { $0.id == currentTxnB.id }, "Should not contain current transaction B")

        // Cleanup
        transactionManager.clearAllTransactions()
    }

    func testRestoreMissingSkipsDuplicateUberTransactions() async throws {
        // Create clean manager instances for this test
        let (shiftManager, expenseManager, preferencesManager, backupRestoreManager) = createCleanManagers()
        let transactionManager = UberTransactionManager.shared
        transactionManager.clearAllTransactions()

        // Given: Current transactions A, B from "Test Period"
        let txnIdA = UUID()
        let txnIdB = UUID()
        let shiftID = UUID()

        let currentTxnA = createTestTransaction(id: txnIdA, shiftID: shiftID, date: Date(), amount: 10.0)
        let currentTxnB = createTestTransaction(id: txnIdB, shiftID: shiftID, date: Date(), amount: 15.0)
        transactionManager.saveTransactions([currentTxnA, currentTxnB])

        XCTAssertEqual(transactionManager.getAllTransactions().count, 2, "Should start with 2 transactions")

        // When: Restore backup with A (same period - skip), C (NEW period - add)
        let txnIdC = UUID()
        let backupTxnA = createTestTransaction(id: txnIdA, shiftID: shiftID, date: Date(), amount: 999.0) // Same period as local - will be skipped
        let backupTxnC = createTransactionWithPeriod(id: txnIdC, shiftID: shiftID, date: Date(), amount: 20.0, type: "Tip", statementPeriod: "New Period") // NEW period - will be added

        let backupData = createBackupData(shifts: [], expenses: [], uberTransactions: [backupTxnA, backupTxnC])

        let result = backupRestoreManager.restoreFromBackup(
            backupData: backupData,
            shiftManager: shiftManager,
            expenseManager: expenseManager,
            preferencesManager: preferencesManager,
            action: .skipDuplicates
        )

        // Then: Should have A, B (preserved from local "Test Period"), C (added from new period)
        let allTransactions = transactionManager.getAllTransactions()
        XCTAssertEqual(allTransactions.count, 3, "Should have 3 transactions total")

        XCTAssertEqual(result.transactionsAdded, 1, "Should add 1 new transaction (C from new period)")
        XCTAssertEqual(result.transactionsUpdated, 0, "Should not update any transactions")
        XCTAssertEqual(result.transactionsSkipped, 1, "Should skip 1 transaction (A from existing period)")

        // Verify original value preserved (statement period based)
        let preservedTxnA = allTransactions.first { $0.id == txnIdA }
        XCTAssertNotNil(preservedTxnA, "Transaction A should exist")
        XCTAssertEqual(preservedTxnA?.amount ?? 0, 10.0, accuracy: 0.01, "Transaction A should keep original amount")

        // Verify new transaction added (from new period)
        XCTAssertTrue(allTransactions.contains { $0.id == txnIdC }, "Should contain transaction C")

        // Cleanup
        transactionManager.clearAllTransactions()
    }

    func testMergeAndRestoreUpdatesExistingUberTransactions() async throws {
        // Create clean manager instances for this test
        let (shiftManager, expenseManager, preferencesManager, backupRestoreManager) = createCleanManagers()
        let transactionManager = UberTransactionManager.shared
        transactionManager.clearAllTransactions()

        // Given: Current transactions A, B from "Test Period"
        let txnIdA = UUID()
        let txnIdB = UUID()
        let shiftID = UUID()

        let currentTxnA = createTestTransaction(id: txnIdA, shiftID: shiftID, date: Date(), amount: 10.0)
        let currentTxnB = createTestTransaction(id: txnIdB, shiftID: shiftID, date: Date(), amount: 15.0)
        transactionManager.saveTransactions([currentTxnA, currentTxnB])

        XCTAssertEqual(transactionManager.getAllTransactions().count, 2, "Should start with 2 transactions")

        // When: Restore backup with A (same period - preserved), C (NEW period - added)
        // NOTE: Merge for Uber transactions preserves local statement periods (same as skipDuplicates)
        let txnIdC = UUID()
        let backupTxnA = createTestTransaction(id: txnIdA, shiftID: shiftID, date: Date(), amount: 999.0) // Same period - will be skipped
        let backupTxnC = createTransactionWithPeriod(id: txnIdC, shiftID: shiftID, date: Date(), amount: 20.0, type: "Tip", statementPeriod: "New Period") // NEW period - will be added

        let backupData = createBackupData(shifts: [], expenses: [], uberTransactions: [backupTxnA, backupTxnC])

        let result = backupRestoreManager.restoreFromBackup(
            backupData: backupData,
            shiftManager: shiftManager,
            expenseManager: expenseManager,
            preferencesManager: preferencesManager,
            action: .merge
        )

        // Then: Should have A, B (preserved from local "Test Period"), C (added from new period)
        // For Uber transactions, merge preserves existing statement periods (no update behavior)
        let allTransactions = transactionManager.getAllTransactions()
        XCTAssertEqual(allTransactions.count, 3, "Should have 3 transactions total")

        XCTAssertEqual(result.transactionsAdded, 1, "Should add 1 new transaction (C from new period)")
        XCTAssertEqual(result.transactionsUpdated, 0, "Should not update (Uber uses statement-period preservation)")
        XCTAssertEqual(result.transactionsSkipped, 1, "Should skip 1 transaction (A from existing period)")

        // Verify transaction A preserved (not updated)
        let preservedTxnA = allTransactions.first { $0.id == txnIdA }
        XCTAssertNotNil(preservedTxnA, "Transaction A should exist")
        XCTAssertEqual(preservedTxnA?.amount ?? 0, 10.0, accuracy: 0.01, "Transaction A should keep original amount (period preserved)")

        // Verify transaction B unchanged
        let unchangedTxnB = allTransactions.first { $0.id == txnIdB }
        XCTAssertNotNil(unchangedTxnB, "Transaction B should exist")
        XCTAssertEqual(unchangedTxnB?.amount ?? 0, 15.0, accuracy: 0.01, "Transaction B should keep original amount")

        // Verify transaction C added (from new period)
        XCTAssertTrue(allTransactions.contains { $0.id == txnIdC }, "Should contain transaction C")

        // Cleanup
        transactionManager.clearAllTransactions()
    }

    func testRestoreWithNoUberTransactionsInBackup() async throws {
        // Create clean manager instances for this test
        let (shiftManager, expenseManager, preferencesManager, backupRestoreManager) = createCleanManagers()
        let transactionManager = UberTransactionManager.shared
        transactionManager.clearAllTransactions()

        // Given: Current transactions
        let txn = createTestTransaction(id: UUID(), shiftID: UUID(), date: Date(), amount: 10.0)
        transactionManager.saveTransaction(txn)

        XCTAssertEqual(transactionManager.getAllTransactions().count, 1, "Should start with 1 transaction")

        // When: Restore backup with nil uberTransactions using Merge
        let backupData = createBackupData(shifts: [], expenses: [], uberTransactions: nil)

        let result = backupRestoreManager.restoreFromBackup(
            backupData: backupData,
            shiftManager: shiftManager,
            expenseManager: expenseManager,
            preferencesManager: preferencesManager,
            action: .merge
        )

        // Then: Existing transaction should remain
        XCTAssertEqual(transactionManager.getAllTransactions().count, 1, "Should still have 1 transaction")
        XCTAssertEqual(result.transactionsAdded, 0, "Should add 0 transactions")
        XCTAssertEqual(result.transactionsUpdated, 0, "Should update 0 transactions")

        // Cleanup
        transactionManager.clearAllTransactions()
    }

    func testBackwardCompatibilityWithoutUberTransactions() async throws {
        // Create clean manager instances for this test
        let (shiftManager, expenseManager, preferencesManager, backupRestoreManager) = createCleanManagers()

        // Given: A backup without uberTransactions field (legacy backup)
        let backupData = BackupData(
            shifts: [],
            expenses: [],
            uberTransactions: nil, // Simulating old backup format
            preferences: BackupPreferences(
                tankCapacity: 15.0,
                gasPrice: 2.50,
                standardMileageRate: 0.70,
                weekStartDay: 1,
                dateFormat: "MM/dd/yyyy",
                timeFormat: "h:mm a",
                timeZoneIdentifier: "America/New_York",
                tipDeductionEnabled: true,
                effectivePersonalTaxRate: 0.22,
                incrementalSyncEnabled: false,
                syncFrequency: "daily",
                lastIncrementalSyncDate: nil
            ),
            exportDate: Date(),
            appVersion: "1.0"
        )

        // When: Restore using any action
        let result = backupRestoreManager.restoreFromBackup(
            backupData: backupData,
            shiftManager: shiftManager,
            expenseManager: expenseManager,
            preferencesManager: preferencesManager,
            action: .replaceAll
        )

        // Then: Should handle gracefully with no transaction operations
        XCTAssertEqual(result.transactionsAdded, 0, "Should add 0 transactions")
        XCTAssertEqual(result.transactionsUpdated, 0, "Should update 0 transactions")
        XCTAssertEqual(result.transactionsSkipped, 0, "Should skip 0 transactions")
    }

    // MARK: - Statement Period Based Deduplication Tests

    /// Helper to create a test transaction with specific statement period
    private func createTransactionWithPeriod(
        id: UUID = UUID(),
        shiftID: UUID?,
        date: Date,
        amount: Double,
        type: String = "Tip",
        statementPeriod: String
    ) -> UberTransaction {
        return UberTransaction(
            id: id,
            transactionDate: date,
            eventDate: date,
            eventType: type,
            amount: amount,
            tollsReimbursed: type == "UberX" ? 5.0 : nil,
            statementPeriod: statementPeriod,
            shiftID: shiftID,
            importDate: date
        )
    }

    func testRestoreSkipDuplicates_PreservesLocalStatementPeriods() async throws {
        // Create clean manager instances for this test
        let (shiftManager, expenseManager, preferencesManager, backupRestoreManager) = createCleanManagers()
        let transactionManager = UberTransactionManager.shared
        transactionManager.clearAllTransactions()

        // Given: Local transactions from "Oct 13 - Oct 20, 2025" period
        let shiftID = UUID()
        let localTxn1 = createTransactionWithPeriod(shiftID: shiftID, date: Date(), amount: 10.0, type: "Tip", statementPeriod: "Oct 13 - Oct 20, 2025")
        let localTxn2 = createTransactionWithPeriod(shiftID: shiftID, date: Date(), amount: 25.0, type: "UberX", statementPeriod: "Oct 13 - Oct 20, 2025")

        transactionManager.saveTransactions([localTxn1, localTxn2])

        XCTAssertEqual(transactionManager.getAllTransactions().count, 2, "Should start with 2 local transactions")

        // When: Restore backup with SAME statement period (different amounts - should be ignored)
        let backupTxn1 = createTransactionWithPeriod(shiftID: shiftID, date: Date(), amount: 999.0, type: "Tip", statementPeriod: "Oct 13 - Oct 20, 2025")
        let backupTxn2 = createTransactionWithPeriod(shiftID: shiftID, date: Date(), amount: 888.0, type: "UberX", statementPeriod: "Oct 13 - Oct 20, 2025")

        let backupData = createBackupData(shifts: [], expenses: [], uberTransactions: [backupTxn1, backupTxn2])

        _ = backupRestoreManager.restoreFromBackup(
            backupData: backupData,
            shiftManager: shiftManager,
            expenseManager: expenseManager,
            preferencesManager: preferencesManager,
            action: .skipDuplicates
        )

        // Then: Local transactions should be preserved, backup ignored
        let allTransactions = transactionManager.getAllTransactions()
        XCTAssertEqual(allTransactions.count, 2, "Should still have 2 transactions (local preserved)")

        // Verify local amounts preserved (not replaced by backup)
        let tipTransaction = allTransactions.first { $0.eventType == "Tip" }
        XCTAssertNotNil(tipTransaction, "Tip transaction should exist")
        XCTAssertEqual(tipTransaction?.amount ?? 0, 10.0, accuracy: 0.01, "Local tip amount should be preserved")

        let uberXTransaction = allTransactions.first { $0.eventType == "UberX" }
        XCTAssertNotNil(uberXTransaction, "UberX transaction should exist")
        XCTAssertEqual(uberXTransaction?.amount ?? 0, 25.0, accuracy: 0.01, "Local UberX amount should be preserved")

        // Cleanup
        transactionManager.clearAllTransactions()
    }

    func testRestoreSkipDuplicates_AddsNewStatementPeriodsOnly() async throws {
        // Create clean manager instances for this test
        let (shiftManager, expenseManager, preferencesManager, backupRestoreManager) = createCleanManagers()
        let transactionManager = UberTransactionManager.shared
        transactionManager.clearAllTransactions()

        // Given: Local transactions from "Oct 13 - Oct 20, 2025" period
        let shiftID = UUID()
        let localTxn = createTransactionWithPeriod(shiftID: shiftID, date: Date(), amount: 10.0, type: "Tip", statementPeriod: "Oct 13 - Oct 20, 2025")

        transactionManager.saveTransaction(localTxn)

        XCTAssertEqual(transactionManager.getAllTransactions().count, 1, "Should start with 1 local transaction")

        // When: Restore backup with NEW statement period "Oct 20 - Oct 27, 2025"
        let backupTxn1 = createTransactionWithPeriod(shiftID: shiftID, date: Date(), amount: 15.0, type: "Tip", statementPeriod: "Oct 20 - Oct 27, 2025")
        let backupTxn2 = createTransactionWithPeriod(shiftID: shiftID, date: Date(), amount: 30.0, type: "UberX", statementPeriod: "Oct 20 - Oct 27, 2025")

        let backupData = createBackupData(shifts: [], expenses: [], uberTransactions: [backupTxn1, backupTxn2])

        _ = backupRestoreManager.restoreFromBackup(
            backupData: backupData,
            shiftManager: shiftManager,
            expenseManager: expenseManager,
            preferencesManager: preferencesManager,
            action: .skipDuplicates
        )

        // Then: Should have local + new transactions
        let allTransactions = transactionManager.getAllTransactions()
        XCTAssertEqual(allTransactions.count, 3, "Should have 3 transactions (1 local + 2 from new period)")

        // Verify both periods exist
        let oct13Transactions = allTransactions.filter { $0.statementPeriod == "Oct 13 - Oct 20, 2025" }
        XCTAssertEqual(oct13Transactions.count, 1, "Should have 1 transaction from Oct 13 period")

        let oct20Transactions = allTransactions.filter { $0.statementPeriod == "Oct 20 - Oct 27, 2025" }
        XCTAssertEqual(oct20Transactions.count, 2, "Should have 2 transactions from Oct 20 period")

        // Cleanup
        transactionManager.clearAllTransactions()
    }

    func testRestoreMerge_PreservesLocalStatementPeriods() async throws {
        // Create clean manager instances for this test
        let (shiftManager, expenseManager, preferencesManager, backupRestoreManager) = createCleanManagers()
        let transactionManager = UberTransactionManager.shared
        transactionManager.clearAllTransactions()

        // Given: Local transactions from specific period
        let shiftID = UUID()
        let localTxn = createTransactionWithPeriod(shiftID: shiftID, date: Date(), amount: 20.0, type: "Tip", statementPeriod: "Oct 13 - Oct 20, 2025")

        transactionManager.saveTransaction(localTxn)

        // When: Restore backup with SAME period (even merge should preserve local)
        let backupTxn = createTransactionWithPeriod(shiftID: shiftID, date: Date(), amount: 999.0, type: "Tip", statementPeriod: "Oct 13 - Oct 20, 2025")

        let backupData = createBackupData(shifts: [], expenses: [], uberTransactions: [backupTxn])

        _ = backupRestoreManager.restoreFromBackup(
            backupData: backupData,
            shiftManager: shiftManager,
            expenseManager: expenseManager,
            preferencesManager: preferencesManager,
            action: .merge
        )

        // Then: Local transaction amount should be preserved
        let allTransactions = transactionManager.getAllTransactions()
        XCTAssertEqual(allTransactions.count, 1, "Should have 1 transaction")
        XCTAssertEqual(allTransactions.first?.amount ?? 0, 20.0, accuracy: 0.01, "Local amount should be preserved")

        // Cleanup
        transactionManager.clearAllTransactions()
    }

    func testRestoreWithMixedStatementPeriods() async throws {
        // Create clean manager instances for this test
        let (shiftManager, expenseManager, preferencesManager, backupRestoreManager) = createCleanManagers()
        let transactionManager = UberTransactionManager.shared
        transactionManager.clearAllTransactions()

        // Given: Local transactions from two periods
        let shiftID = UUID()
        let localTxn1 = createTransactionWithPeriod(shiftID: shiftID, date: Date(), amount: 10.0, type: "Tip", statementPeriod: "Oct 13 - Oct 20, 2025")
        let localTxn2 = createTransactionWithPeriod(shiftID: shiftID, date: Date(), amount: 15.0, type: "Tip", statementPeriod: "Oct 27 - Nov 3, 2025")

        transactionManager.saveTransactions([localTxn1, localTxn2])

        XCTAssertEqual(transactionManager.getAllTransactions().count, 2, "Should start with 2 transactions")

        // When: Restore backup with:
        // - Oct 13-20 (existing - should skip)
        // - Oct 20-27 (new - should add)
        // - Oct 27-Nov 3 (existing - should skip)
        let backupTxn1 = createTransactionWithPeriod(shiftID: shiftID, date: Date(), amount: 999.0, type: "Tip", statementPeriod: "Oct 13 - Oct 20, 2025")
        let backupTxn2 = createTransactionWithPeriod(shiftID: shiftID, date: Date(), amount: 20.0, type: "Tip", statementPeriod: "Oct 20 - Oct 27, 2025")
        let backupTxn3 = createTransactionWithPeriod(shiftID: shiftID, date: Date(), amount: 888.0, type: "Tip", statementPeriod: "Oct 27 - Nov 3, 2025")

        let backupData = createBackupData(shifts: [], expenses: [], uberTransactions: [backupTxn1, backupTxn2, backupTxn3])

        _ = backupRestoreManager.restoreFromBackup(
            backupData: backupData,
            shiftManager: shiftManager,
            expenseManager: expenseManager,
            preferencesManager: preferencesManager,
            action: .skipDuplicates
        )

        // Then: Should have 3 transactions (2 local preserved + 1 new period added)
        let allTransactions = transactionManager.getAllTransactions()
        XCTAssertEqual(allTransactions.count, 3, "Should have 3 transactions")

        // Verify local amounts preserved
        let oct13Txn = allTransactions.first { $0.statementPeriod == "Oct 13 - Oct 20, 2025" }
        XCTAssertEqual(oct13Txn?.amount ?? 0, 10.0, accuracy: 0.01, "Oct 13 transaction should preserve local amount")

        let oct27Txn = allTransactions.first { $0.statementPeriod == "Oct 27 - Nov 3, 2025" }
        XCTAssertEqual(oct27Txn?.amount ?? 0, 15.0, accuracy: 0.01, "Oct 27 transaction should preserve local amount")

        // Verify new period added
        let oct20Txn = allTransactions.first { $0.statementPeriod == "Oct 20 - Oct 27, 2025" }
        XCTAssertNotNil(oct20Txn, "Oct 20 transaction should be added")
        XCTAssertEqual(oct20Txn?.amount ?? 0, 20.0, accuracy: 0.01, "Oct 20 transaction should have backup amount")

        // Cleanup
        transactionManager.clearAllTransactions()
    }

    func testClearAndRestore_ReplacesAllStatementPeriods() async throws {
        // Create clean manager instances for this test
        let (shiftManager, expenseManager, preferencesManager, backupRestoreManager) = createCleanManagers()
        let transactionManager = UberTransactionManager.shared
        transactionManager.clearAllTransactions()

        // Given: Local transactions from a period
        let shiftID = UUID()
        let localTxn = createTransactionWithPeriod(shiftID: shiftID, date: Date(), amount: 10.0, type: "Tip", statementPeriod: "Oct 13 - Oct 20, 2025")

        transactionManager.saveTransaction(localTxn)

        // When: Clear & Restore with different period
        let backupTxn = createTransactionWithPeriod(shiftID: shiftID, date: Date(), amount: 25.0, type: "Tip", statementPeriod: "Oct 20 - Oct 27, 2025")

        let backupData = createBackupData(shifts: [], expenses: [], uberTransactions: [backupTxn])

        _ = backupRestoreManager.restoreFromBackup(
            backupData: backupData,
            shiftManager: shiftManager,
            expenseManager: expenseManager,
            preferencesManager: preferencesManager,
            action: .replaceAll
        )

        // Then: Only backup transactions should exist (local cleared)
        let allTransactions = transactionManager.getAllTransactions()
        XCTAssertEqual(allTransactions.count, 1, "Should have 1 transaction from backup")
        XCTAssertEqual(allTransactions.first?.statementPeriod, "Oct 20 - Oct 27, 2025", "Should be from backup period")
        XCTAssertEqual(allTransactions.first?.amount ?? 0, 25.0, accuracy: 0.01, "Should have backup amount")

        // Cleanup
        transactionManager.clearAllTransactions()
    }
}


