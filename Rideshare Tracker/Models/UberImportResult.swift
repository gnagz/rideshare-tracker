//
//  UberImportResult.swift
//  Rideshare Tracker
//
//  Created by George Knaggs in collaboration with Claude AI on 1/10/26.
//

import Foundation

/// Result from processing a single statement PDF
struct SingleStatementResult: Identifiable {
    let id = UUID()
    let filename: String
    let statementPeriod: String
    let success: Bool
    let errorMessage: String?
    let matchedCount: Int
    let unmatchedCount: Int
    let importableCount: Int
    let ignoredCount: Int
    let wasSkippedAsDuplicate: Bool
}

/// Combined result from importing one or more Uber statement PDFs
struct UberImportResult {
    let statementPeriod: String
    let totalTransactions: Int      // All parsed transactions (including ignored)
    let importableCount: Int        // Tips + tolls (excluding ignored like bank transfers)
    let matchedCount: Int
    let unmatchedCount: Int
    let transactionsNeedingVerification: Int
    let updatedShifts: [RideshareShift]
    let missingShiftsCSV: String?

    // Per-statement breakdown for multi-file imports
    let statementResults: [SingleStatementResult]

    /// Number of ignored transactions (bank transfers, etc.)
    var ignoredCount: Int {
        totalTransactions - importableCount
    }

    /// True if statement had no importable data (only bank transfers, etc.)
    var hasNoImportableTransactions: Bool {
        importableCount == 0
    }

    /// True if multiple statements were processed
    var hasMultipleStatements: Bool {
        statementResults.count > 1
    }

    /// Count of successful statement imports
    var successfulStatementCount: Int {
        statementResults.filter { $0.success }.count
    }

    /// Count of skipped duplicates
    var skippedStatementCount: Int {
        statementResults.filter { $0.wasSkippedAsDuplicate }.count
    }

    /// Count of failed statements
    var failedStatementCount: Int {
        statementResults.filter { !$0.success && !$0.wasSkippedAsDuplicate }.count
    }

    /// Convenience initializer for single-statement result (backwards compatibility)
    init(
        statementPeriod: String,
        totalTransactions: Int,
        importableCount: Int,
        matchedCount: Int,
        unmatchedCount: Int,
        transactionsNeedingVerification: Int,
        updatedShifts: [RideshareShift],
        missingShiftsCSV: String?
    ) {
        self.statementPeriod = statementPeriod
        self.totalTransactions = totalTransactions
        self.importableCount = importableCount
        self.matchedCount = matchedCount
        self.unmatchedCount = unmatchedCount
        self.transactionsNeedingVerification = transactionsNeedingVerification
        self.updatedShifts = updatedShifts
        self.missingShiftsCSV = missingShiftsCSV
        self.statementResults = [
            SingleStatementResult(
                filename: "",
                statementPeriod: statementPeriod,
                success: true,
                errorMessage: nil,
                matchedCount: matchedCount,
                unmatchedCount: unmatchedCount,
                importableCount: importableCount,
                ignoredCount: totalTransactions - importableCount,
                wasSkippedAsDuplicate: false
            )
        ]
    }

    /// Full initializer with statement results
    init(
        statementPeriod: String,
        totalTransactions: Int,
        importableCount: Int,
        matchedCount: Int,
        unmatchedCount: Int,
        transactionsNeedingVerification: Int,
        updatedShifts: [RideshareShift],
        missingShiftsCSV: String?,
        statementResults: [SingleStatementResult]
    ) {
        self.statementPeriod = statementPeriod
        self.totalTransactions = totalTransactions
        self.importableCount = importableCount
        self.matchedCount = matchedCount
        self.unmatchedCount = unmatchedCount
        self.transactionsNeedingVerification = transactionsNeedingVerification
        self.updatedShifts = updatedShifts
        self.missingShiftsCSV = missingShiftsCSV
        self.statementResults = statementResults
    }
}
