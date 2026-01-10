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
            // Use eventDate (when trip occurred) if available, fallback to transactionDate (when processed)
            let effectiveDate = transaction.eventDate ?? transaction.transactionDate
            let shiftDate = calculateShiftDate(for: effectiveDate)
            grouped[shiftDate, default: []].append(transaction)
        }

        return grouped
    }

    /// Calculate shift start/end times from transactions
    /// Uses earliest transaction as start, latest as end (per user's improved approach)
    /// - Parameter transactions: Transactions for this shift
    /// - Returns: Tuple of (startTime, endTime)
    func calculateShiftTimes(for transactions: [UberTransaction]) -> (startTime: Date, endTime: Date) {
        // Use eventDate (when trip occurred) if available, fallback to transactionDate (when processed)
        let dates = transactions.map { $0.eventDate ?? $0.transactionDate }
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
        // Simplified columns matching import format (no spaces in headers)
        // Note: HasFullTankAtStart and DidRefuelAtEnd removed - inferred from tank readings
        return [
            "StartDate",
            "StartTime",
            "EndDate",
            "EndTime",
            "StartMileage",
            "EndMileage",
            "StartTankReading",
            "EndTankReading",
            "RefuelGallons",
            "RefuelCost",
            "GasPrice",
            "StandardMileageRate",
            "Trips",
            "NetFare",
            "Tips",
            "CashTips",
            "Promotions",
            "Tolls",
            "TollsReimbursed",
            "ParkingFees",
            "MiscFees"
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
        var netFare = 0.0
        var tips = 0.0
        var promotions = 0.0
        var tollsReimbursed = 0.0

        for transaction in transactions {
            let category = categorize(transaction)

            switch category {
            case .netFare:
                netFare += transaction.amount
            case .tip:
                tips += transaction.amount
            case .promotion:
                promotions += transaction.amount
            case .ignore:
                continue
            }

            // Add toll reimbursement if present
            if let toll = transaction.tollsReimbursed {
                tollsReimbursed += toll
            }
        }

        // Date formatter for date column (MM/dd/yyyy)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM/dd/yyyy"

        // Time formatter for time column (h:mm:ss a -> "4:01:00 PM")
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm:ss a"

        // Build row with Uber data prefilled, vehicle fields blank
        // Tank readings use string format: "E", "1/8", "1/4", "3/8", "1/2", "5/8", "3/4", "7/8", "F"
        return [
            dateFormatter.string(from: startTime),           // StartDate
            timeFormatter.string(from: startTime),           // StartTime
            dateFormatter.string(from: endTime),             // EndDate
            timeFormatter.string(from: endTime),             // EndTime
            "",                                              // StartMileage (blank - user fills)
            "",                                              // EndMileage (blank - user fills)
            "",                                              // StartTankReading (blank - user fills, e.g. "1/2", "F")
            "",                                              // EndTankReading (blank - user fills, e.g. "1/4", "E")
            "",                                              // RefuelGallons (blank - user fills)
            "",                                              // RefuelCost (blank - user fills)
            "",                                              // GasPrice (blank - user fills)
            "",                                              // StandardMileageRate (blank - user fills)
            "",                                              // Trips (blank - user fills)
            formatAmount(netFare),                           // NetFare (prefilled)
            formatAmount(tips),                              // Tips (prefilled)
            "",                                              // CashTips (blank - user fills)
            formatAmount(promotions),                        // Promotions (prefilled)
            "",                                              // Tolls (blank - user fills)
            formatAmount(tollsReimbursed),                   // TollsReimbursed (prefilled)
            "",                                              // ParkingFees (blank - user fills)
            ""                                               // MiscFees (blank - user fills)
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
