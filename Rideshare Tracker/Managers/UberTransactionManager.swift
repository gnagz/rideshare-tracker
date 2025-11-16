//
//  UberTransactionManager.swift
//  Rideshare Tracker
//
//  Created by Claude AI on 11/14/25.
//

import Foundation

/// Manages persistent storage of all Uber transactions
class UberTransactionManager: @unchecked Sendable {
    static let shared = UberTransactionManager()
    private let userDefaultsKey = "uberTransactions"
    private let queue = DispatchQueue(label: "com.rideshare.uberTransactions")

    private init() {}

    // MARK: - Core CRUD

    /// Save or update a transaction (synchronous for consistent test behavior)
    func saveTransaction(_ transaction: UberTransaction) {
        var all = getAllTransactionsInternal()

        if let index = all.firstIndex(where: { $0.id == transaction.id }) {
            all[index] = transaction  // Update
        } else {
            all.append(transaction)   // Insert
        }

        persist(all)
    }

    /// Save multiple transactions (synchronous for consistent test behavior)
    func saveTransactions(_ transactions: [UberTransaction]) {
        var all = getAllTransactionsInternal()

        for transaction in transactions {
            if let index = all.firstIndex(where: { $0.id == transaction.id }) {
                all[index] = transaction
            } else {
                all.append(transaction)
            }
        }

        persist(all)
    }

    /// Get all transactions
    func getAllTransactions() -> [UberTransaction] {
        return getAllTransactionsInternal()
    }

    /// Get transactions for specific shift
    func getTransactions(forShift shiftID: UUID) -> [UberTransaction] {
        getAllTransactionsInternal().filter { $0.shiftID == shiftID }
    }

    /// Get orphaned transactions (no shift assigned)
    func getOrphanedTransactions() -> [UberTransaction] {
        getAllTransactionsInternal().filter { $0.shiftID == nil }
    }

    /// Get orphaned transactions within date range (uses eventDate)
    func getOrphanedTransactions(from: Date, to: Date) -> [UberTransaction] {
        getOrphanedTransactions().filter {
            guard let eventDate = $0.eventDate else { return false }
            return eventDate >= from && eventDate < to
        }
    }

    // MARK: - Shift Association

    /// Assign transactions to a shift (async for batch operations)
    func assignTransactions(_ transactionIDs: [UUID], toShift shiftID: UUID) {
        queue.async {
            var all = self.getAllTransactionsInternal()

            for i in 0..<all.count {
                if transactionIDs.contains(all[i].id) {
                    all[i].shiftID = shiftID
                }
            }

            self.persist(all)
        }
    }

    // MARK: - Duplicate Detection

    /// Check if transaction exists by ID
    func transactionExists(id: UUID) -> Bool {
        getAllTransactionsInternal().contains(where: { $0.id == id })
    }

    /// Check if transaction exists by content (date + type + amount)
    /// Returns the existing transaction if found
    func findDuplicate(for transaction: UberTransaction) -> UberTransaction? {
        getAllTransactionsInternal().first { existing in
            existing.transactionDate == transaction.transactionDate &&
            existing.eventType == transaction.eventType &&
            abs(existing.amount - transaction.amount) < 0.01
        }
    }

    /// Save transaction if not duplicate, or update existing duplicate
    /// Returns true if saved/updated, false if skipped
    @discardableResult
    func saveTransactionIfNotDuplicate(_ transaction: UberTransaction) -> Bool {
        if let existing = findDuplicate(for: transaction) {
            // Update existing transaction with new shift assignment if needed
            if existing.shiftID != transaction.shiftID && transaction.shiftID != nil {
                var updated = existing
                updated.shiftID = transaction.shiftID
                saveTransaction(updated)
                return true
            }
            // Already exists with same or better data - skip
            return false
        } else {
            // New transaction - save it
            saveTransaction(transaction)
            return true
        }
    }

    // MARK: - Statement Period Deduplication

    /// Check if any transactions exist for a given statement period
    func hasStatementPeriod(_ period: String) -> Bool {
        getAllTransactionsInternal().contains(where: { $0.statementPeriod == period })
    }

    /// Get all unique statement periods from stored transactions
    func getAllStatementPeriods() -> [String] {
        let all = getAllTransactionsInternal()
        let periods = Set(all.map { $0.statementPeriod })
        return Array(periods)
    }

    /// Get all transactions for a specific statement period
    func getTransactions(forStatementPeriod period: String) -> [UberTransaction] {
        getAllTransactionsInternal().filter { $0.statementPeriod == period }
    }

    /// Get shift IDs affected by a statement period (excludes orphan transactions)
    func getAffectedShiftIDs(forStatementPeriod period: String) -> Set<UUID> {
        let periodTransactions = getTransactions(forStatementPeriod: period)
        let shiftIDs = periodTransactions.compactMap { $0.shiftID }
        return Set(shiftIDs)
    }

    /// Replace all transactions for a statement period with new transactions (atomic operation)
    /// This removes all existing transactions for the period and adds the new ones
    func replaceStatementPeriod(_ period: String, with newTransactions: [UberTransaction]) {
        var all = getAllTransactionsInternal()

        // Remove all existing transactions for this period
        all.removeAll(where: { $0.statementPeriod == period })

        // Add new transactions
        all.append(contentsOf: newTransactions)

        persist(all)
    }

    // MARK: - Deletion

    /// Delete transactions matching a predicate (async)
    func deleteTransactions(where predicate: @escaping @Sendable (UberTransaction) -> Bool) {
        queue.async {
            var all = self.getAllTransactionsInternal()
            all.removeAll(where: predicate)
            self.persist(all)
        }
    }

    /// Delete specific transactions by ID (async)
    func deleteTransactions(_ ids: [UUID]) {
        deleteTransactions(where: { ids.contains($0.id) })
    }

    /// Clear all transactions (for testing)
    func clearAllTransactions() {
        persist([])
    }

    // MARK: - Orphaning

    /// Orphan transactions assigned to a specific shift (set shiftID to nil)
    func orphanTransactions(forShift shiftID: UUID) {
        var all = getAllTransactionsInternal()
        var modified = false

        for i in 0..<all.count {
            if all[i].shiftID == shiftID {
                all[i].shiftID = nil
                modified = true
            }
        }

        if modified {
            persist(all)
        }
    }

    /// Orphan transactions assigned to any of the given shift IDs (synchronous)
    func orphanTransactions(forShifts shiftIDs: Set<UUID>) {
        var all = getAllTransactionsInternal()
        var modified = false

        for i in 0..<all.count {
            if let currentShiftID = all[i].shiftID, shiftIDs.contains(currentShiftID) {
                all[i].shiftID = nil
                modified = true
            }
        }

        if modified {
            persist(all)
        }
    }

    // MARK: - Private Helpers

    private func getAllTransactionsInternal() -> [UberTransaction] {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let transactions = try? JSONDecoder().decode([UberTransaction].self, from: data) else {
            return []
        }
        return transactions
    }

    private func persist(_ transactions: [UberTransaction]) {
        if let data = try? JSONEncoder().encode(transactions) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }
}
