//
//  UberPDFParser.swift
//  Rideshare Tracker
//
//  Created by Claude AI on 11/8/25.
//

import Foundation
import PDFKit

/// Parser for Uber weekly statement PDFs
/// Extracts statement period, transactions, and handles dynamic column layouts (5 or 6 columns)
class UberPDFParser {

    // MARK: - Public Methods

    /// Parse statement period from PDF text
    /// - Parameter text: Text from PDF page 1
    /// - Returns: Tuple with start date, end date, and formatted period string
    func parseStatementPeriod(from text: String) throws -> (startDate: Date, endDate: Date, period: String)? {
        // Pattern: "Oct 13, 2025 4 AM - Oct 20, 2025 4 AM"
        let pattern = #"([A-Za-z]+)\s+(\d+),\s+(\d{4})\s+4\s+AM\s+-\s+([A-Za-z]+)\s+(\d+),\s+(\d{4})\s+4\s+AM"#

        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else {
            return nil
        }

        // Extract components
        guard let startMonthRange = Range(match.range(at: 1), in: text),
              let startDayRange = Range(match.range(at: 2), in: text),
              let startYearRange = Range(match.range(at: 3), in: text),
              let endMonthRange = Range(match.range(at: 4), in: text),
              let endDayRange = Range(match.range(at: 5), in: text),
              let endYearRange = Range(match.range(at: 6), in: text) else {
            return nil
        }

        let startMonthStr = String(text[startMonthRange])
        let startDay = Int(text[startDayRange]) ?? 0
        let startYear = Int(text[startYearRange]) ?? 0
        let endMonthStr = String(text[endMonthRange])
        let endDay = Int(text[endDayRange]) ?? 0
        let endYear = Int(text[endYearRange]) ?? 0

        // Convert month names to numbers
        let startMonth = monthNumber(from: startMonthStr)
        let endMonth = monthNumber(from: endMonthStr)

        // Create dates
        let calendar = Calendar.current
        var startComponents = DateComponents()
        startComponents.year = startYear
        startComponents.month = startMonth
        startComponents.day = startDay
        startComponents.hour = 4
        startComponents.minute = 0
        startComponents.second = 0

        var endComponents = DateComponents()
        endComponents.year = endYear
        endComponents.month = endMonth
        endComponents.day = endDay
        endComponents.hour = 4
        endComponents.minute = 0
        endComponents.second = 0

        guard let startDate = calendar.date(from: startComponents),
              let endDate = calendar.date(from: endComponents) else {
            return nil
        }

        let periodString = "\(startMonthStr) \(startDay), \(startYear) - \(endMonthStr) \(endDay), \(endYear)"

        return (startDate, endDate, periodString)
    }

    /// Detect column layout from table header
    /// - Parameter headerText: Transaction table header text
    /// - Returns: Column layout (.fiveColumn or .sixColumn)
    func detectColumnLayout(from headerText: String) -> ColumnLayout {
        // Check if "Refunds & Expenses" column exists
        if headerText.contains("Refunds & Expenses") || headerText.contains("Refunds &amp; Expenses") {
            return .sixColumn
        } else {
            return .fiveColumn
        }
    }

    /// Parse a single transaction line
    /// - Parameters:
    ///   - line: Transaction line from PDF
    ///   - layout: Column layout (5 or 6 columns)
    ///   - statementEndDate: Statement end date for year inference
    /// - Returns: Parsed transaction or nil if invalid
    func parseTransaction(line: String, layout: ColumnLayout, statementEndDate: Date) throws -> UberTransaction? {
        // Skip empty lines or header lines
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty || trimmed.contains("Processed") {
            return nil
        }

        // Pattern for transaction line:
        // "Oct 19 7:49 PM   UberX   $21.55   $2.71   $0.00   $448.32" (6 columns)
        // "Nov 5 2:30 AM   Delivery   $12.25   $0.00   $156.78" (5 columns)

        // Split by multiple spaces (columns are separated by 2+ spaces)
        let components = trimmed.components(separatedBy: "  ").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }

        guard components.count >= 5 else {
            return nil // Invalid line
        }

        // Parse date/time (first component): "Oct 19 7:49 PM"
        let dateTimeStr = components[0]
        guard let transactionDate = parseTransactionDate(dateTimeStr, statementEndDate: statementEndDate) else {
            return nil
        }

        // Parse event type (second component)
        let eventType = components[1]

        // Parse amount (third component): "$21.55"
        let amountStr = components[2].replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "")
        guard let amount = Double(amountStr) else {
            return nil
        }

        // Parse toll reimbursement (if 6-column layout)
        var tollReimbursement: Double? = nil
        if layout == .sixColumn && components.count >= 6 {
            let tollStr = components[3].replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "")
            tollReimbursement = Double(tollStr)
        }

        return UberTransaction(
            transactionDate: transactionDate,
            eventType: eventType,
            amount: amount,
            tollReimbursement: tollReimbursement
        )
    }

    /// Parse multiple transactions from text
    /// - Parameters:
    ///   - text: Transaction table text
    ///   - layout: Column layout
    ///   - statementEndDate: Statement end date for year inference
    /// - Returns: Array of parsed transactions
    func parseTransactions(from text: String, layout: ColumnLayout, statementEndDate: Date) throws -> [UberTransaction] {
        let lines = text.components(separatedBy: .newlines)
        var transactions: [UberTransaction] = []

        for line in lines {
            if let transaction = try parseTransaction(line: line, layout: layout, statementEndDate: statementEndDate) {
                transactions.append(transaction)
            }
        }

        return transactions
    }

    /// Categorize transaction by event type
    /// - Parameter transaction: Transaction to categorize
    /// - Returns: Transaction category
    func categorize(transaction: UberTransaction) -> TransactionCategory {
        let eventType = transaction.eventType

        if eventType == "Tip" {
            return .tip
        } else if eventType == "Quest" || eventType == "Incentive" {
            return .promotion
        } else if eventType.lowercased().contains("transferred to bank") {
            return .ignore
        } else {
            // All ride types: UberX, UberX Priority, Share, Delivery, etc.
            return .netFare
        }
    }

    // MARK: - Private Helper Methods

    /// Parse transaction date/time with year inference
    /// - Parameters:
    ///   - dateTimeStr: Date/time string from PDF ("Oct 19 7:49 PM")
    ///   - statementEndDate: Statement end date for year inference
    /// - Returns: Parsed date or nil
    private func parseTransactionDate(_ dateTimeStr: String, statementEndDate: Date) -> Date? {
        // Format: "Oct 19 7:49 PM" or "Nov 5 2:30 AM"
        let components = dateTimeStr.components(separatedBy: " ")
        guard components.count >= 4 else { return nil }

        let monthStr = components[0]
        guard let day = Int(components[1]) else { return nil }
        let timeStr = components[2]
        let amPm = components[3]

        // Parse time
        let timeComponents = timeStr.components(separatedBy: ":")
        guard timeComponents.count == 2,
              let hour12 = Int(timeComponents[0]),
              let minute = Int(timeComponents[1]) else {
            return nil
        }

        // Convert to 24-hour format
        var hour24 = hour12
        if amPm == "PM" && hour12 != 12 {
            hour24 += 12
        } else if amPm == "AM" && hour12 == 12 {
            hour24 = 0
        }

        // Infer year
        let calendar = Calendar.current
        let statementYear = calendar.component(.year, from: statementEndDate)
        let statementMonth = calendar.component(.month, from: statementEndDate)
        let transactionMonth = monthNumber(from: monthStr)

        // If transaction month > statement month, it's from previous year
        let year = (transactionMonth > statementMonth) ? statementYear - 1 : statementYear

        // Create date
        var dateComponents = DateComponents()
        dateComponents.year = year
        dateComponents.month = transactionMonth
        dateComponents.day = day
        dateComponents.hour = hour24
        dateComponents.minute = minute
        dateComponents.second = 0

        return calendar.date(from: dateComponents)
    }

    /// Convert month name to number
    /// - Parameter monthName: Month name ("Jan", "Feb", etc.)
    /// - Returns: Month number (1-12)
    private func monthNumber(from monthName: String) -> Int {
        let months = ["Jan": 1, "Feb": 2, "Mar": 3, "Apr": 4, "May": 5, "Jun": 6,
                      "Jul": 7, "Aug": 8, "Sep": 9, "Oct": 10, "Nov": 11, "Dec": 12]
        return months[monthName] ?? 1
    }
}

// MARK: - Supporting Types

/// Column layout for Uber statement transaction table
enum ColumnLayout {
    case fiveColumn  // Without "Refunds & Expenses" (no tolls)
    case sixColumn   // With "Refunds & Expenses" (has tolls)
}

/// Uber transaction from statement
struct UberTransaction: Codable, Equatable {
    var transactionDate: Date
    var eventType: String
    var amount: Double
    var tollReimbursement: Double?
}

/// Transaction category based on event type
enum TransactionCategory {
    case tip
    case promotion
    case netFare
    case ignore
}
