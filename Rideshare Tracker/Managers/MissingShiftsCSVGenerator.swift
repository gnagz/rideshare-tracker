//
//  MissingShiftsCSVGenerator.swift
//  Rideshare Tracker
//
//  Created by Claude AI on 11/8/25.
//

import Foundation

/// Generates CSV files for unmatched Uber transactions (missing shifts)
/// Uses earliest transaction time as start, latest as end to avoid overlaps with existing shifts
class MissingShiftsCSVGenerator {

    private let calendar = Calendar.current
    private let parser = UberStatementManager.shared

    // MARK: - Public Methods

    /// Generate CSV for missing shifts from unmatched transactions
    /// - Parameters:
    ///   - unmatchedTransactions: Transactions that didn't match existing shifts
    ///   - statementPeriod: Statement period string for reference
    /// - Returns: CSV string ready for export
    func generateMissingShiftsCSV(
        unmatchedTransactions: [UberTransaction],
        statementPeriod: String
    ) throws -> String {

        // Group transactions by shift date (4 AM boundaries)
        let grouped = groupTransactionsByShiftDate(unmatchedTransactions)

        // Build CSV header
        var csv = buildCSVHeader()

        // Generate row for each shift date
        for (shiftDate, transactions) in grouped.sorted(by: { $0.key < $1.key }) {
            let row = try buildCSVRow(shiftDate: shiftDate, transactions: transactions)
            csv += row + "\n"
        }

        return csv
    }

    /// Group transactions by their shift date (4 AM boundary)
    /// - Parameter transactions: Transactions to group
    /// - Returns: Dictionary keyed by shift date (4 AM of that day)
    func groupTransactionsByShiftDate(_ transactions: [UberTransaction]) -> [Date: [UberTransaction]] {
        var grouped: [Date: [UberTransaction]] = [:]

        for transaction in transactions {
            let shiftDate = calculateShiftDate(for: transaction.transactionDate)
            grouped[shiftDate, default: []].append(transaction)
        }

        return grouped
    }

    /// Calculate shift start/end times from transactions
    /// Uses earliest transaction as start, latest as end (per user's improved approach)
    /// - Parameter transactions: Transactions for this shift
    /// - Returns: Tuple of (startTime, endTime)
    func calculateShiftTimes(for transactions: [UberTransaction]) -> (startTime: Date, endTime: Date) {
        let dates = transactions.map { $0.transactionDate }
        let startTime = dates.min() ?? Date()
        let endTime = dates.max() ?? Date()
        return (startTime, endTime)
    }

    // MARK: - Private Helper Methods

    /// Calculate which shift date a transaction belongs to (4 AM boundary logic)
    /// - Parameter transactionDate: Transaction date/time
    /// - Returns: Shift date (4 AM of that day)
    private func calculateShiftDate(for transactionDate: Date) -> Date {
        // Get calendar components
        let components = calendar.dateComponents([.year, .month, .day, .hour], from: transactionDate)
        guard let hour = components.hour else { return transactionDate }

        // If before 4 AM, belongs to previous day's shift
        var shiftComponents = calendar.dateComponents([.year, .month, .day], from: transactionDate)
        if hour < 4 {
            // Move back one day
            if let date = calendar.date(from: shiftComponents),
               let previousDay = calendar.date(byAdding: .day, value: -1, to: date) {
                shiftComponents = calendar.dateComponents([.year, .month, .day], from: previousDay)
            }
        }

        // Set to 4 AM
        shiftComponents.hour = 4
        shiftComponents.minute = 0
        shiftComponents.second = 0

        return calendar.date(from: shiftComponents) ?? transactionDate
    }

    /// Build CSV header row
    /// - Returns: CSV header string
    private func buildCSVHeader() -> String {
        // Match existing import structure (32 columns from ImportExportManager)
        return [
            "Start Date",
            "End Date",
            "Start Mileage",
            "End Mileage",
            "Start Tank Reading",
            "End Tank Reading",
            "Has Full Tank at Start",
            "Gas Price",
            "Standard Mileage Rate",
            "Uber Net Fare",
            "Uber Tips",
            "Uber Promotions",
            "Uber Tolls",
            "Lyft Net Fare",
            "Lyft Tips",
            "Lyft Bonuses",
            "Other Income",
            "Cash Tips",
            "Refuel Amount",
            "Refuel Gallons",
            "Other Expense 1 Amount",
            "Other Expense 1 Description",
            "Other Expense 2 Amount",
            "Other Expense 2 Description",
            "Other Expense 3 Amount",
            "Other Expense 3 Description",
            "Notes",
            "Uber Statement Period",
            "Miles Driven",
            "Gas Used (gallons)",
            "MPG",
            "Total Earnings"
        ].joined(separator: ",") + "\n"
    }

    /// Build CSV row for a shift
    /// - Parameters:
    ///   - shiftDate: Shift date (4 AM boundary)
    ///   - transactions: Transactions for this shift
    /// - Returns: CSV row string
    private func buildCSVRow(shiftDate: Date, transactions: [UberTransaction]) throws -> String {
        // Calculate start/end times from transaction times
        let (startTime, endTime) = calculateShiftTimes(for: transactions)

        // Aggregate transaction amounts by category
        var uberNetFare = 0.0
        var uberTips = 0.0
        var uberPromotions = 0.0
        var uberTolls = 0.0

        for transaction in transactions {
            let category = parser.categorize(transaction: transaction)

            switch category {
            case .netFare:
                uberNetFare += transaction.amount
            case .tip:
                uberTips += transaction.amount
            case .promotion:
                uberPromotions += transaction.amount
            case .ignore:
                continue
            }

            // Add toll reimbursement if present
            if let toll = transaction.tollReimbursement {
                uberTolls += toll
            }
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"

        // Build row with Uber data prefilled, vehicle fields blank
        return [
            dateFormatter.string(from: startTime),           // Start Date
            dateFormatter.string(from: endTime),             // End Date
            "",                                              // Start Mileage (blank - user fills)
            "",                                              // End Mileage (blank - user fills)
            "",                                              // Start Tank Reading (blank - user fills)
            "",                                              // End Tank Reading (blank - user fills)
            "",                                              // Has Full Tank at Start (blank - user fills)
            "",                                              // Gas Price (blank - user fills)
            "",                                              // Standard Mileage Rate (blank - user fills)
            formatAmount(uberNetFare),                       // Uber Net Fare (prefilled)
            formatAmount(uberTips),                          // Uber Tips (prefilled)
            formatAmount(uberPromotions),                    // Uber Promotions (prefilled)
            formatAmount(uberTolls),                         // Uber Tolls (prefilled)
            "",                                              // Lyft Net Fare
            "",                                              // Lyft Tips
            "",                                              // Lyft Bonuses
            "",                                              // Other Income
            "",                                              // Cash Tips
            "",                                              // Refuel Amount
            "",                                              // Refuel Gallons
            "",                                              // Other Expense 1 Amount
            "",                                              // Other Expense 1 Description
            "",                                              // Other Expense 2 Amount
            "",                                              // Other Expense 2 Description
            "",                                              // Other Expense 3 Amount
            "",                                              // Other Expense 3 Description
            "",                                              // Notes
            "",                                              // Uber Statement Period (could add but leaving blank)
            "",                                              // Miles Driven (calculated on import)
            "",                                              // Gas Used (calculated on import)
            "",                                              // MPG (calculated on import)
            ""                                               // Total Earnings (calculated on import)
        ].joined(separator: ",")
    }

    /// Format amount for CSV (empty string if 0.0)
    /// - Parameter amount: Amount to format
    /// - Returns: Formatted string
    private func formatAmount(_ amount: Double) -> String {
        if amount == 0.0 {
            return ""
        }
        return String(format: "%.2f", amount)
    }
}
