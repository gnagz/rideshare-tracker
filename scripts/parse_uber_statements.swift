#!/usr/bin/env swift

import Foundation
import PDFKit

/// Comprehensive validation script for all Uber PDF statements
/// Validates parsing quality across all your local Uber earnings PDFs
///
/// ⚠️ ENTIRE SYNC POINT SECTION ⚠️
/// Lines 87-576 duplicate parsing logic from Rideshare Tracker/Utilities/UberStatementParser.swift
/// Keep this section byte-for-byte identical with UberStatementParser.swift
/// All parsing logic should be duplicated between the app and this validation script

// MARK: - Configuration

// Parse command line arguments
var pdfDirectory: String = ""
var verboseMode: Bool = false
var targetFile: String? = nil
var csvOutputPath: String? = nil

var i = 1
while i < CommandLine.arguments.count {
    let arg = CommandLine.arguments[i]
    if arg == "-v" || arg == "--verbose" {
        verboseMode = true
    } else if arg == "-f" || arg == "--file" {
        i += 1
        if i < CommandLine.arguments.count {
            targetFile = CommandLine.arguments[i]
        }
    } else if arg == "-o" || arg == "--output" {
        // Check if next arg exists and doesn't start with "-"
        if i + 1 < CommandLine.arguments.count && !CommandLine.arguments[i + 1].hasPrefix("-") {
            i += 1
            csvOutputPath = CommandLine.arguments[i]
        } else {
            csvOutputPath = "" // Empty string signals: use PDF filename
        }
    } else if pdfDirectory.isEmpty {
        pdfDirectory = arg
    }
    i += 1
}

if pdfDirectory.isEmpty {
    // Default to common iCloud location
    let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
    pdfDirectory = "\(homeDir)/Library/Mobile Documents/com~apple~CloudDocs/Uber_Statements"
}

print("=== UBER PDF STATEMENT VALIDATOR ===")
print("Scanning directory: \(pdfDirectory)")
if verboseMode {
    print("Verbose mode: ENABLED (ASCII table output)")
}
if let file = targetFile {
    print("Target file: \(file)")
}
if let csvPath = csvOutputPath {
    if csvPath.isEmpty {
        print("CSV output: Enabled (auto-naming)")
    } else {
        print("CSV output: \(csvPath)")
    }
}
print()

// MARK: - Data Models

struct UberTransaction {
    let transactionDate: Date
    let eventDate: Date?
    let eventType: String
    let amount: Double?
    let tollsReimbursed: Double?
    let sourceRow: Int  // For debugging (not in production UberTransaction)
}

struct ValidationResult {
    let filename: String
    let success: Bool
    let transactionCount: Int
    let errors: [String]
    let warnings: [String]
    let transactions: [UberTransaction]  // For verbose output
}

// MARK: - Core Parsing Logic

class SimplifiedUberParser {

    let datePattern = #"^(?:Mon|Tue|Wed|Thu|Fri|Sat|Sun|T\s+ue),\s+([A-Za-z]+)\s+(\d+)$"#
    let dateRegex: NSRegularExpression

    init() {
        guard let regex = try? NSRegularExpression(pattern: datePattern) else {
            fatalError("Could not create date regex")
        }
        self.dateRegex = regex
    }

    func parsePDF(at url: URL) -> (transactions: [UberTransaction], errors: [String], warnings: [String]) {
        guard let pdfDocument = PDFDocument(url: url) else {
            return ([], ["Could not load PDF"], [])
        }

        var allTransactions: [UberTransaction] = []
        var errors: [String] = []
        var warnings: [String] = []

        for pageNum in 0..<pdfDocument.pageCount {
            guard let page = pdfDocument.page(at: pageNum) else { continue }
            guard let fullSelection = page.selection(for: page.bounds(for: .mediaBox)) else { continue }

            let selections = fullSelection.selectionsByLine()

            // Group by Y-coordinate (rows)
            var rows: [(y: CGFloat, elements: [(x: CGFloat, text: String)])] = []

            for selection in selections {
                let bounds = selection.bounds(for: page)
                let y = bounds.origin.y
                let x = bounds.origin.x
                let text = (selection.string ?? "").trimmingCharacters(in: .whitespaces)

                if text.isEmpty { continue }

                if let rowIndex = rows.firstIndex(where: { abs($0.y - y) < 1.0 }) {
                    rows[rowIndex].elements.append((x, text))
                } else {
                    rows.append((y, [(x, text)]))
                }
            }

            // Sort rows by Y coordinate (descending - higher Y = top of page)
            rows.sort { $0.y > $1.y }

            // Detect column layout from header row
            var columnLayout: ColumnLayout = .fiveColumn
            for row in rows {
                let rowText = row.elements.map { $0.text }.joined(separator: " ")
                if rowText.contains("Processed") && rowText.contains("Event") && rowText.contains("Your earnings") {
                    columnLayout = detectColumnLayout(from: rowText)
                    break
                }
            }

            // Parse transactions
            for (rowIdx, row) in rows.enumerated() {
                let sortedElements = row.elements.sorted { $0.x < $1.x }

                // Check if first element matches transaction date pattern
                if let firstElement = sortedElements.first,
                   firstElement.x < 40.0,
                   dateRegex.firstMatch(in: firstElement.text, range: NSRange(firstElement.text.startIndex..., in: firstElement.text)) != nil {

                    // Collect all rows for this transaction
                    var transactionElements: [(text: String, x: CGFloat, y: CGFloat)] = []
                    var offset = 0
                    let maxRows = 15

                    while rowIdx + offset < rows.count && offset < maxRows {
                        let targetRow = rows[rowIdx + offset]
                        let sortedElems = targetRow.elements.sorted { $0.x < $1.x }

                        // Check if this row starts a new transaction (skip first row)
                        if offset > 0 {
                            if let firstElement = sortedElems.first,
                               firstElement.x < 40.0,
                               dateRegex.firstMatch(in: firstElement.text, range: NSRange(firstElement.text.startIndex..., in: firstElement.text)) != nil {
                                break
                            }
                        }

                        // Add all elements from this row
                        for elem in sortedElems {
                            transactionElements.append((elem.text, elem.x, targetRow.y))
                        }

                        offset += 1
                    }

                    // Parse the transaction from elements
                    if let transaction = parseTransactionFromElements(transactionElements, layout: columnLayout, rowIndex: rowIdx) {
                        allTransactions.append(transaction)
                    } else {
                        errors.append("Page \(pageNum + 1), Row \(rowIdx): Failed to parse transaction")
                    }
                }
            }
        }

        return (allTransactions, errors, warnings)
    }

    // MARK: ⚠️ SYNC POINT START ⚠️
    // Keep byte-for-byte identical with Rideshare Tracker/Utilities/UberStatementParser.swift

    /// Column layout for Uber statement transaction table
    enum ColumnLayout {
        case fiveColumn  // Without "Refunds & Expenses" (no tolls)
        case sixColumn   // With "Refunds & Expenses" (has tolls)
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

    /// Parse transaction from coordinate elements (test-friendly version)
    /// - Parameters:
    ///   - elements: Array of (text, x, y) tuples representing PDF elements
    ///   - layout: Column layout (5 or 6 column)
    ///   - rowIndex: Row index for debugging
    /// - Returns: Parsed transaction or nil
    internal func parseTransactionFromElements(_ elements: [(text: String, x: CGFloat, y: CGFloat)], layout: ColumnLayout, rowIndex: Int) -> UberTransaction? {
        guard !elements.isEmpty else { return nil }

        // Convert to format used by parsing logic
        var allElements: [(text: String, x: Double, y: Double)] = elements.map {
            ($0.text, Double($0.x), Double($0.y))
        }

        // Filter out page footer rows (e.g., "Page 1 of 3")
        let pageFooterPattern = #"\d+\s+of\s+\d+$"#
        var footerYCoordinates: Set<Double> = []

        // First pass: identify Y coordinates of rows containing page footer text
        for element in allElements {
            if element.text.range(of: pageFooterPattern, options: .regularExpression) != nil {
                footerYCoordinates.insert(element.y)
            }
        }

        // Second pass: remove all elements with those Y coordinates
        allElements.removeAll { element in
            footerYCoordinates.contains { abs($0 - element.y) < 5.0 }
        }

        // Sort elements by position (top-to-bottom via descending Y, then left-to-right via ascending X)
        allElements.sort { first, second in
            if abs(first.y - second.y) < 5.0 {
                return first.x < second.x
            }
            return first.y > second.y
        }

        // Parse processed date (first row should have date and time)
        var processedDate: Date?
        var eventDate: Date?
        var eventType = ""
        var amounts: [Double] = []

        // Find date elements (format: "Sat, Aug 9" or "T ue, Aug 5")
        let datePattern = #"^(?:Mon|Tue|Wed|Thu|Fri|Sat|Sun|T\s+ue),\s+([A-Za-z]+)\s+(\d+)$"#
        let timePattern = #"^\d+:\d+\s+(?:AM|PM)$"#
        let eventDatePattern = #"^([A-Za-z]+)\s+(\d+)\s+(\d+):(\d+)\s+(AM|PM)$"#
        let trailingAmountsPattern = #"([-+]?\$\d+\.\d+)+$"#

        var datePart: String?
        var timePart: String?
        var foundEventDate = false
        var firstLineY: Double?
        var secondLineY: Double?

        for element in allElements {
            // Track which line we're on by Y-coordinate
            if firstLineY == nil {
                firstLineY = element.y
            } else if secondLineY == nil && abs(element.y - (firstLineY ?? 0)) >= 5.0 {
                secondLineY = element.y
            }

            let isFirstLine = firstLineY != nil && abs(element.y - firstLineY!) < 5.0
            let isSecondLine = secondLineY != nil && abs(element.y - secondLineY!) < 5.0

            // Check for processed date
            if element.text.range(of: datePattern, options: .regularExpression) != nil {
                datePart = element.text
            }
            // Check for processed time
            else if element.text.range(of: timePattern, options: .regularExpression) != nil {
                timePart = element.text
            }
            // Check for event date/time
            else if element.text.range(of: eventDatePattern, options: .regularExpression) != nil {
                let calendar = Calendar.current
                let currentYear = calendar.component(.year, from: Date())
                eventDate = parseEventDateTime(text: element.text, year: currentYear)
                foundEventDate = true
            }
            // Check for standalone amounts - Only if text is ONLY amounts (no other text)
            // This handles cases like "$15.00 $15.00" or "$2.00 $2.00"
            else if !foundEventDate && isFirstLine && element.text.range(of: #"^([-+]?\$\d+\.\d+\s*)+$"#, options: .regularExpression) != nil {
                let amountPattern = #"[-+]?\$\d+\.\d+"#
                let amountRegex = try! NSRegularExpression(pattern: amountPattern)
                let amountMatches = amountRegex.matches(in: element.text, range: NSRange(element.text.startIndex..., in: element.text))

                for amountMatch in amountMatches {
                    if let amountRange = Range(amountMatch.range, in: element.text) {
                        let amountStr = String(element.text[amountRange])
                        let numStr = amountStr.replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "")
                        if let amount = Double(numStr) {
                            amounts.append(amount)
                        }
                    }
                }
            }
            // Check for embedded amounts at end of text
            else if element.text.range(of: trailingAmountsPattern, options: .regularExpression) != nil {
                if isFirstLine && !foundEventDate {
                    var textToProcess = element.text
                    let regex = try! NSRegularExpression(pattern: trailingAmountsPattern)
                    if let match = regex.firstMatch(in: textToProcess, range: NSRange(textToProcess.startIndex..., in: textToProcess)) {
                        let matchRange = match.range
                        if let range = Range(matchRange, in: textToProcess) {
                            let amountsString = String(textToProcess[range])
                            let amountPattern = #"[-+]?\$\d+\.\d+"#
                            let amountRegex = try! NSRegularExpression(pattern: amountPattern)
                            let amountMatches = amountRegex.matches(in: amountsString, range: NSRange(amountsString.startIndex..., in: amountsString))

                            for amountMatch in amountMatches {
                                if let amountRange = Range(amountMatch.range, in: amountsString) {
                                    let amountStr = String(amountsString[amountRange])
                                    let numStr = amountStr.replacingOccurrences(of: "$", with: "")
                                    if let amount = Double(numStr) {
                                        amounts.append(amount)
                                    }
                                }
                            }

                            textToProcess.removeSubrange(range)
                            textToProcess = textToProcess.trimmingCharacters(in: .whitespaces)
                        }
                    }

                    if !textToProcess.isEmpty {
                        if !eventType.isEmpty { eventType += " " }
                        eventType += textToProcess
                    }
                } else if isSecondLine {
                    var textToProcess = element.text
                    let regex = try! NSRegularExpression(pattern: trailingAmountsPattern)
                    if let match = regex.firstMatch(in: textToProcess, range: NSRange(textToProcess.startIndex..., in: textToProcess)) {
                        if let range = Range(match.range, in: textToProcess) {
                            textToProcess.removeSubrange(range)
                            textToProcess = textToProcess.trimmingCharacters(in: .whitespaces)
                        }
                    }

                    if !textToProcess.isEmpty {
                        if !eventType.isEmpty { eventType += " " }
                        eventType += textToProcess
                    }
                } else {
                    if !eventType.isEmpty { eventType += " " }
                    eventType += element.text
                }
            }
            // Build event type from non-amount, non-date elements
            else {
                if !eventType.isEmpty { eventType += " " }
                eventType += element.text
            }
        }

        // Parse processed date from collected parts
        if let datePart = datePart, let timePart = timePart {
            let calendar = Calendar.current
            let currentYear = calendar.component(.year, from: Date())
            processedDate = parseCoordinateBasedDate(datePart: datePart, timePart: timePart, year: currentYear)
        }

        guard let processedDate = processedDate else { return nil }

        // Parse amounts based on event type and column layout
        let (amount, tollsReimbursed) = parseAmountsByEventType(amounts, eventType: eventType, layout: layout)

        return UberTransaction(
            transactionDate: processedDate,
            eventDate: eventDate,
            eventType: eventType.trimmingCharacters(in: .whitespaces),
            amount: amount,
            tollsReimbursed: tollsReimbursed,
            sourceRow: rowIndex
        )
    }

    /// Parse event date/time from combined string (e.g., "Aug 24 4:45 PM")
    /// - Parameters:
    ///   - text: Event date/time string
    ///   - year: Year to use
    /// - Returns: Parsed date or nil
    private func parseEventDateTime(text: String, year: Int) -> Date? {
        // Parse format: "Aug 24 4:45 PM"
        let pattern = #"^([A-Za-z]+)\s+(\d+)\s+(\d+):(\d+)\s+(AM|PM)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let monthRange = Range(match.range(at: 1), in: text),
              let dayRange = Range(match.range(at: 2), in: text),
              let hourRange = Range(match.range(at: 3), in: text),
              let minuteRange = Range(match.range(at: 4), in: text),
              let amPmRange = Range(match.range(at: 5), in: text) else {
            return nil
        }

        let monthStr = String(text[monthRange])
        guard let day = Int(text[dayRange]),
              let hour12 = Int(text[hourRange]),
              let minute = Int(text[minuteRange]) else {
            return nil
        }

        let amPm = String(text[amPmRange])

        // Convert 12-hour to 24-hour
        var hour24 = hour12
        if amPm == "AM" {
            if hour12 == 12 {
                hour24 = 0
            }
        } else { // PM
            if hour12 != 12 {
                hour24 = hour12 + 12
            }
        }

        // Create date
        let month = monthNumber(from: monthStr)
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour24
        components.minute = minute

        return Calendar.current.date(from: components)
    }

    /// Parse date from separate date and time parts
    /// - Parameters:
    ///   - datePart: Date string (e.g., "Sat, Aug 9" or "T ue, Aug 5")
    ///   - timePart: Time string (e.g., "12:24 AM")
    ///   - year: Year to use
    /// - Returns: Parsed date or nil
    private func parseCoordinateBasedDate(datePart: String, timePart: String, year: Int) -> Date? {
        // Parse date part: "Sat, Aug 9" or "T ue, Aug 5"
        let datePattern = #"^(?:Mon|Tue|Wed|Thu|Fri|Sat|Sun|T\s+ue),\s+([A-Za-z]+)\s+(\d+)$"#
        guard let dateRegex = try? NSRegularExpression(pattern: datePattern),
              let dateMatch = dateRegex.firstMatch(in: datePart, range: NSRange(datePart.startIndex..., in: datePart)),
              let monthRange = Range(dateMatch.range(at: 1), in: datePart),
              let dayRange = Range(dateMatch.range(at: 2), in: datePart) else {
            return nil
        }

        let monthStr = String(datePart[monthRange])
        guard let day = Int(datePart[dayRange]) else { return nil }

        // Parse time part: "12:24 AM"
        let timePattern = #"^(\d+):(\d+)\s+(AM|PM)$"#
        guard let timeRegex = try? NSRegularExpression(pattern: timePattern),
              let timeMatch = timeRegex.firstMatch(in: timePart, range: NSRange(timePart.startIndex..., in: timePart)),
              let hourRange = Range(timeMatch.range(at: 1), in: timePart),
              let minuteRange = Range(timeMatch.range(at: 2), in: timePart),
              let amPmRange = Range(timeMatch.range(at: 3), in: timePart) else {
            return nil
        }

        guard let hour12 = Int(timePart[hourRange]),
              let minute = Int(timePart[minuteRange]) else {
            return nil
        }
        let amPm = String(timePart[amPmRange])

        // Convert to 24-hour format
        var hour24 = hour12
        if amPm == "PM" && hour12 != 12 {
            hour24 += 12
        } else if amPm == "AM" && hour12 == 12 {
            hour24 = 0
        }

        // Create date
        let calendar = Calendar.current
        let month = monthNumber(from: monthStr)

        var dateComponents = DateComponents()
        dateComponents.year = year
        dateComponents.month = month
        dateComponents.day = day
        dateComponents.hour = hour24
        dateComponents.minute = minute
        dateComponents.second = 0

        return calendar.date(from: dateComponents)
    }

    /// Parse amounts based on event type and column layout
    /// - Parameters:
    ///   - amounts: All dollar amounts found in transaction
    ///   - eventType: Event type text
    ///   - layout: Column layout
    /// - Returns: Tuple of (amount, tollReimbursement)
    private func parseAmountsByEventType(_ amounts: [Double], eventType: String, layout: ColumnLayout) -> (Double, Double?) {
        guard !amounts.isEmpty else { return (0, nil) }

        // Special case: "Transferred To Bank Account" - amount is Payout (before Balance)
        if eventType.lowercased().contains("transferred to bank") {
            // Last amount is Balance, second-to-last is Payout
            if amounts.count >= 2 {
                return (amounts[amounts.count - 2], nil)
            }
            return (amounts.last ?? 0, nil)
        }

        // Special case: "Account validation deposit" or "Reverse account validation"
        if eventType.lowercased().contains("account validation") {
            // Amount is in Refunds & Expenses column (before Balance)
            if amounts.count >= 2 {
                return (amounts[amounts.count - 2], nil)
            }
            return (amounts.last ?? 0, nil)
        }

        // Normal transaction: parse based on column layout
        // Last amount is always Balance (ignore it)

        if layout == .sixColumn {
            // Columns: Processed | Event | Your earnings | Refunds & Expenses | Payouts | Balance
            // If we have 2+ amounts (excluding Balance), 2nd-to-last is Tolls, 3rd-to-last is Earnings
            if amounts.count >= 3 {
                let earnings = amounts[amounts.count - 3]
                let tolls = amounts[amounts.count - 2]

                // Check if earnings == tolls (likely a duplicate from PDF text merging)
                // In this case, there are no actual tolls
                if earnings == tolls {
                    return (earnings, nil)
                }

                return (earnings, tolls > 0 ? tolls : nil)
            } else if amounts.count == 2 {
                // Only earnings + balance
                return (amounts[0], nil)
            }
        } else {
            // Five column: Processed | Event | Your earnings | Payouts | Balance
            // Second-to-last is Earnings (if exists)
            if amounts.count >= 2 {
                return (amounts[amounts.count - 2], nil)
            }
        }

        // Fallback: use first amount (or 0 if no amounts found)
        return (amounts.first ?? 0, nil)
    }

    /// Convert month name to number
    /// - Parameter monthName: Month name ("Jan", "Feb", etc.)
    /// - Returns: Month number (1-12)
    private func monthNumber(from monthName: String) -> Int {
        let months = ["Jan": 1, "Feb": 2, "Mar": 3, "Apr": 4, "May": 5, "Jun": 6,
                      "Jul": 7, "Aug": 8, "Sep": 9, "Oct": 10, "Nov": 11, "Dec": 12]
        return months[monthName] ?? 1
    }
    // MARK: ⚠️ SYNC POINT END ⚠️

    private func extractAllAmounts(from text: String) -> [Double] {
        let pattern = #"[-+]?\$\d+\.\d+"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        var amounts: [Double] = []

        for match in matches {
            if let range = Range(match.range, in: text) {
                let amountStr = String(text[range])
                    .replacingOccurrences(of: "$", with: "")
                    .replacingOccurrences(of: ",", with: "")
                if let value = Double(amountStr) {
                    amounts.append(value)
                }
            }
        }

        return amounts
    }
}

// MARK: - CSV and Formatting Utilities

/// Quote a CSV value if it contains commas, quotes, or newlines
func quoteCSVValue(_ value: String) -> String {
    if value.contains(",") || value.contains("\"") || value.contains("\n") {
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
    return value
}

/// Format transactions as ASCII table for screen display
func formatAsASCIITable(_ transactions: [UberTransaction]) -> String {
    guard !transactions.isEmpty else { return "No transactions to display" }

    // Date formatters
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "EEE, MMM d"
    let timeFormatter = DateFormatter()
    timeFormatter.dateFormat = "h:mm a"
    let eventDateFormatter = DateFormatter()
    eventDateFormatter.dateFormat = "MMM d h:mm a"

    // Column headers
    let headers = ["Row", "Processed Date", "Time", "Event Date/Time", "Event Type", "Amount", "Refunds&Expense"]

    // Calculate max width for each column
    var colWidths = headers.map { $0.count }

    for tx in transactions {
        let row = [
            String(tx.sourceRow),
            dateFormatter.string(from: tx.transactionDate),
            timeFormatter.string(from: tx.transactionDate),
            tx.eventDate.map { eventDateFormatter.string(from: $0) } ?? "[NOT FOUND]",
            tx.eventType,
            tx.amount.map { String(format: "%.2f", $0) } ?? "",
            tx.tollsReimbursed.map { String(format: "%.2f", $0) } ?? ""
        ]

        for (i, value) in row.enumerated() {
            colWidths[i] = max(colWidths[i], value.count)
        }
    }

    // Build table
    var output = ""

    // Top border
    output += "┌"
    for (i, width) in colWidths.enumerated() {
        output += String(repeating: "─", count: width + 2)
        output += i < colWidths.count - 1 ? "┬" : "┐\n"
    }

    // Header row
    output += "│"
    for (i, header) in headers.enumerated() {
        output += " " + header.padding(toLength: colWidths[i], withPad: " ", startingAt: 0) + " │"
    }
    output += "\n"

    // Header separator
    output += "├"
    for (i, width) in colWidths.enumerated() {
        output += String(repeating: "─", count: width + 2)
        output += i < colWidths.count - 1 ? "┼" : "┤\n"
    }

    // Data rows
    for tx in transactions {
        let row = [
            String(tx.sourceRow),
            dateFormatter.string(from: tx.transactionDate),
            timeFormatter.string(from: tx.transactionDate),
            tx.eventDate.map { eventDateFormatter.string(from: $0) } ?? "[NOT FOUND]",
            tx.eventType,
            tx.amount.map { String(format: "%.2f", $0) } ?? "",
            tx.tollsReimbursed.map { String(format: "%.2f", $0) } ?? ""
        ]

        output += "│"
        for (i, value) in row.enumerated() {
            output += " " + value.padding(toLength: colWidths[i], withPad: " ", startingAt: 0) + " │"
        }
        output += "\n"
    }

    // Bottom border
    output += "└"
    for (i, width) in colWidths.enumerated() {
        output += String(repeating: "─", count: width + 2)
        output += i < colWidths.count - 1 ? "┴" : "┘\n"
    }

    return output
}

/// Format transactions as CSV with proper quoting
func formatAsCSV(_ transactions: [UberTransaction]) -> String {
    var output = ""

    // Date formatters
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "EEE, MMM d"
    let timeFormatter = DateFormatter()
    timeFormatter.dateFormat = "h:mm a"
    let eventDateFormatter = DateFormatter()
    eventDateFormatter.dateFormat = "MMM d h:mm a"

    // Header
    output += "Row,Processed Date,Processed Time,Event Date/Time,Event Type,Amount,Refunds&Expense\n"

    // Data rows
    for tx in transactions {
        let processedDateStr = dateFormatter.string(from: tx.transactionDate)
        let processedTimeStr = timeFormatter.string(from: tx.transactionDate)
        let eventDateStr = tx.eventDate.map { eventDateFormatter.string(from: $0) } ?? "[NOT FOUND]"
        let amountStr = tx.amount.map { String(format: "%.2f", $0) } ?? ""
        let tollStr = tx.tollsReimbursed.map { String(format: "%.2f", $0) } ?? ""

        let row = [
            String(tx.sourceRow),
            quoteCSVValue(processedDateStr),
            quoteCSVValue(processedTimeStr),
            quoteCSVValue(eventDateStr),
            quoteCSVValue(tx.eventType),
            amountStr,
            tollStr
        ]

        output += row.joined(separator: ",") + "\n"
    }

    return output
}

/// Determine CSV output path based on -o flag and PDF filename
func resolveCSVOutputPath(pdfURL: URL, csvOutputPath: String?, pdfDirectory: String) -> URL? {
    guard let outputArg = csvOutputPath else { return nil }

    if outputArg.isEmpty {
        // -o with no argument: use PDF directory, replace .pdf with .csv
        let csvFilename = pdfURL.deletingPathExtension().lastPathComponent + ".csv"
        return URL(fileURLWithPath: pdfDirectory).appendingPathComponent(csvFilename)
    } else if outputArg.contains("/") {
        // Full or relative path provided
        return URL(fileURLWithPath: outputArg)
    } else {
        // Just a filename: use PDF directory
        return URL(fileURLWithPath: pdfDirectory).appendingPathComponent(outputArg)
    }
}

// MARK: - Validation Logic

func validateStatement(at url: URL) -> ValidationResult {
    let filename = url.lastPathComponent
    let parser = SimplifiedUberParser()

    let (transactions, errors, warnings) = parser.parsePDF(at: url)

    var allErrors = errors
    var allWarnings = warnings

    // Additional validations
    if transactions.isEmpty {
        allErrors.append("No transactions found in PDF")
    }

    // Check for suspicious patterns
    for (idx, transaction) in transactions.enumerated() {
        if transaction.eventDate == nil {
            allErrors.append("Transaction \(idx + 1): Missing event date")
        }
        if transaction.eventType.isEmpty {
            allWarnings.append("Transaction \(idx + 1): Empty event type")
        }
        if transaction.eventType.contains("Reimbursement") && transaction.tollsReimbursed == nil {
            allWarnings.append("Transaction \(idx + 1): 'Reimbursement' in event type but no toll parsed")
        }
        if transaction.eventType.contains("Quest") && transaction.eventType.contains("$") {
            // Quest with embedded amount - verify amount was extracted
            if transaction.amount == nil {
                allWarnings.append("Transaction \(idx + 1): Quest with embedded $ but no amount extracted")
            }
        }
    }

    let success = allErrors.isEmpty

    return ValidationResult(
        filename: filename,
        success: success,
        transactionCount: transactions.count,
        errors: allErrors,
        warnings: allWarnings,
        transactions: transactions
    )
}

// MARK: - Main Execution

let fileManager = FileManager.default

guard fileManager.fileExists(atPath: pdfDirectory) else {
    print("❌ Directory not found: \(pdfDirectory)")
    print("\nUsage: swift parse_uber_statements.swift [pdf_directory]")
    exit(1)
}

// Find all PDF files
guard let enumerator = fileManager.enumerator(atPath: pdfDirectory) else {
    print("❌ Could not enumerate directory")
    exit(1)
}

var pdfFiles: [URL] = []
for case let filename as String in enumerator {
    if filename.lowercased().hasSuffix(".pdf") {
        let url = URL(fileURLWithPath: pdfDirectory).appendingPathComponent(filename)
        pdfFiles.append(url)
    }
}

if pdfFiles.isEmpty {
    print("⚠️  No PDF files found in directory")
    exit(0)
}

pdfFiles.sort { $0.lastPathComponent < $1.lastPathComponent }

// Filter to target file if specified
if let targetFilename = targetFile {
    pdfFiles = pdfFiles.filter { $0.lastPathComponent.contains(targetFilename) }
    if pdfFiles.isEmpty {
        print("❌ No PDFs found matching: \(targetFilename)\n")
        exit(1)
    }
}

print("Found \(pdfFiles.count) PDF file(s)\n")
print(String(repeating: "=", count: 80))

// Validate each PDF
var results: [ValidationResult] = []
var totalTransactions = 0

for (idx, pdfURL) in pdfFiles.enumerated() {
    print("\n[\(idx + 1)/\(pdfFiles.count)] \(pdfURL.lastPathComponent)")
    print(String(repeating: "-", count: 80))

    let result = validateStatement(at: pdfURL)
    results.append(result)
    totalTransactions += result.transactionCount

    if result.success {
        print("✅ SUCCESS - \(result.transactionCount) transactions")
    } else {
        print("❌ FAILED - \(result.transactionCount) transactions")
    }

    // Verbose mode: Output ASCII table to screen
    if verboseMode && !result.transactions.isEmpty {
        print("\n   TRANSACTION DETAILS:")
        let tableOutput = formatAsASCIITable(result.transactions)
        // Indent each line of the table
        for line in tableOutput.split(separator: "\n") {
            print("   \(line)")
        }
        print()
    }

    // CSV file output if -o flag was provided
    if let outputPath = resolveCSVOutputPath(pdfURL: pdfURL, csvOutputPath: csvOutputPath, pdfDirectory: pdfDirectory) {
        if !result.transactions.isEmpty {
            let csvContent = formatAsCSV(result.transactions)
            do {
                try csvContent.write(to: outputPath, atomically: true, encoding: .utf8)
                print("   💾 CSV saved to: \(outputPath.path)")
            } catch {
                print("   ❌ Failed to write CSV: \(error.localizedDescription)")
            }
        }
    }

    if !result.errors.isEmpty {
        print("\n   ERRORS:")
        for error in result.errors {
            print("   • \(error)")
        }
    }

    if !result.warnings.isEmpty {
        print("\n   WARNINGS:")
        for warning in result.warnings {
            print("   • \(warning)")
        }
    }
}

// Summary
print("\n" + String(repeating: "=", count: 80))
print("\n📊 SUMMARY")
print(String(repeating: "-", count: 80))

let successCount = results.filter { $0.success }.count
let failureCount = results.count - successCount
let totalErrors = results.reduce(0) { $0 + $1.errors.count }
let totalWarnings = results.reduce(0) { $0 + $1.warnings.count }

print("Total PDFs:          \(results.count)")
print("✅ Successful:       \(successCount)")
print("❌ Failed:           \(failureCount)")
print("Total Transactions:  \(totalTransactions)")
print("Total Errors:        \(totalErrors)")
print("Total Warnings:      \(totalWarnings)")

if failureCount > 0 {
    print("\n⚠️  FAILED FILES:")
    for result in results where !result.success {
        print("   • \(result.filename)")
    }
}

print("\n" + String(repeating: "=", count: 80))

if failureCount == 0 && totalErrors == 0 {
    print("\n🎉 All PDFs validated successfully!")
    exit(0)
} else {
    print("\n⚠️  Validation completed with issues - review errors above")
    exit(1)
}
