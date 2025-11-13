//
//  UberShiftMatcher.swift
//  Rideshare Tracker
//
//  Created by Claude AI on 11/8/25.
//

import Foundation

/// Matches Uber transactions to existing shifts using 4 AM boundary logic
/// Uber's statement periods run from 4 AM to 3:59:59 AM next day
class UberShiftMatcher {

    private let calendar = Calendar.current
    private let parser = UberStatementManager.shared

    // MARK: - Public Methods

    /// Match transactions to existing shifts
    /// - Parameters:
    ///   - transactions: Array of Uber transactions
    ///   - existingShifts: Array of existing rideshare shifts
    /// - Returns: Tuple of (matched, unmatched) transactions
    func matchTransactionsToShifts(
        transactions: [UberTransaction],
        existingShifts: [RideshareShift]
    ) -> (matched: [ShiftMatch], unmatched: [UberTransaction]) {

        var matched: [ShiftMatch] = []
        var unmatched: [UberTransaction] = []

        for transaction in transactions {
            // Skip ignored transactions (bank transfers)
            if parser.categorize(transaction: transaction) == .ignore {
                continue
            }

            if let shift = findMatchingShift(for: transaction, in: existingShifts) {
                matched.append(ShiftMatch(shift: shift, transaction: transaction))
            } else {
                unmatched.append(transaction)
            }
        }

        return (matched, unmatched)
    }

    /// Find shift that matches a transaction
    /// - Parameters:
    ///   - transaction: Uber transaction to match
    ///   - shifts: Array of existing shifts
    /// - Returns: Matching shift or nil
    func findMatchingShift(
        for transaction: UberTransaction,
        in shifts: [RideshareShift]
    ) -> RideshareShift? {

        let transactionDate = transaction.transactionDate

        for shift in shifts {
            let shiftStart = shift.startDate
            guard let shiftEnd = shift.endDate else { continue }

            // Calculate 4 AM boundary for the shift's date
            // The shift's 4 AM window is based on the day the shift started
            guard let fourAMWindow = calculate4AMWindow(for: shiftStart) else { continue }

            // Check if transaction falls in this shift's 4 AM window
            if transactionDate >= fourAMWindow.start && transactionDate < fourAMWindow.end {
                // Additional validation: transaction should be between shift start and end times
                // This handles multiple shifts in the same day - we match to the specific shift
                // where the transaction time falls between start and end
                if transactionDate >= shiftStart && transactionDate <= shiftEnd {
                    return shift
                }
            }
        }

        return nil
    }

    // MARK: - Private Helper Methods

    /// Calculate 4 AM window for a given date
    /// - Parameter date: Date to calculate window for
    /// - Returns: Tuple of (start, end) dates for the 4 AM window
    private func calculate4AMWindow(for date: Date) -> (start: Date, end: Date)? {
        // Get the calendar day of the shift start
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)

        // Create 4 AM on this calendar day
        var fourAMComponents = dateComponents
        fourAMComponents.hour = 4
        fourAMComponents.minute = 0
        fourAMComponents.second = 0

        guard let fourAM = calendar.date(from: fourAMComponents) else { return nil }

        // Window runs from 4 AM this day to 3:59:59 AM next day
        // Which is the same as 4 AM next day (exclusive)
        guard let nextFourAM = calendar.date(byAdding: .day, value: 1, to: fourAM) else { return nil }

        return (start: fourAM, end: nextFourAM)
    }
}

// MARK: - Supporting Types

/// Represents a matched shift and transaction pair
struct ShiftMatch {
    var shift: RideshareShift
    var transaction: UberTransaction
}
