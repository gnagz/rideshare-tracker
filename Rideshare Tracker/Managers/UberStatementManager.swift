//
//  UberStatementManager.swift
//  Rideshare Tracker
//
//  Created by Claude AI on 11/8/25.
//  Renamed from UberPDFParser.swift on 11/11/25.
//

import Foundation
import PDFKit

/// Manager for parsing Uber weekly statement PDFs
/// Extracts transactions using coordinate-based parsing with selectionsByLine()
/// NOTE: PDFKit requires main thread access - parseStatement() must be called on main thread
final class UberStatementManager {
    nonisolated(unsafe) static let shared = UberStatementManager()

    private init() {}

    // MARK: - Public API

    /// Parse Uber statement PDF into transactions
    /// - Parameter url: URL to PDF file
    /// - Returns: Array of parsed transactions
    /// - Throws: Error if PDF cannot be loaded or parsed
    @MainActor
    func parseStatement(from url: URL) throws -> [UberTransaction] {
        // Load PDF
        guard let pdfDocument = PDFDocument(url: url) else {
            throw NSError(domain: "UberStatementManager", code: 1,
                         userInfo: [NSLocalizedDescriptionKey: "Could not load PDF from: \(url.path)"])
        }

        var allTransactions: [UberTransaction] = []

        // Process each page
        for pageNum in 0..<pdfDocument.pageCount {
            guard let page = pdfDocument.page(at: pageNum) else { continue }

            // Extract selections with coordinates
            guard let fullSelection = page.selection(for: page.bounds(for: .mediaBox)) else {
                continue
            }

            let selections = fullSelection.selectionsByLine()
            if selections.isEmpty { continue }

            // Group selections by Y-coordinate (rows)
            let rows = groupByRows(selections, page: page)

            // Parse transactions from rows
            let pageTransactions = parseTransactionsFromRows(rows, pageNum: pageNum)
            allTransactions.append(contentsOf: pageTransactions)
        }

        return allTransactions
    }

    // MARK: - PDF Loading

    /// Load a PDF document from file URL
    /// - Parameter url: URL to PDF file
    /// - Returns: Loaded PDFDocument or nil if loading fails
    func loadPDF(from url: URL) -> PDFDocument? {
        return PDFDocument(url: url)
    }

    /// Extract all text from PDF document
    /// - Parameter document: PDF document to extract from
    /// - Returns: Full text content
    func extractAllText(from document: PDFDocument) -> String {
        var fullText = ""
        for pageNum in 0..<document.pageCount {
            if let page = document.page(at: pageNum),
               let pageText = page.string {
                fullText += pageText + "\n"
            }
        }
        return fullText
    }

    /// Debug PDF document attributes
    /// - Parameter document: PDF document to inspect
    /// - Returns: Dictionary of document attributes
    func debugPDFAttributes(document: PDFDocument) -> [String: Any] {
        var attributes: [String: Any] = [:]

        attributes["pageCount"] = document.pageCount
        attributes["isLocked"] = document.isLocked
        attributes["isEncrypted"] = document.isEncrypted
        attributes["allowsCopying"] = document.allowsCopying
        attributes["allowsPrinting"] = document.allowsPrinting

        // Document metadata
        if let documentAttributes = document.documentAttributes {
            attributes["metadata"] = documentAttributes
        }

        // First page details
        if let firstPage = document.page(at: 0) {
            var pageInfo: [String: Any] = [:]
            let bounds = firstPage.bounds(for: .mediaBox)
            pageInfo["bounds"] = "(\(bounds.origin.x), \(bounds.origin.y), \(bounds.size.width), \(bounds.size.height))"
            pageInfo["rotation"] = firstPage.rotation
            pageInfo["label"] = firstPage.label

            // Try to get page annotations
            let annotationCount = firstPage.annotations.count
            pageInfo["annotationCount"] = annotationCount

            attributes["firstPage"] = pageInfo
        }

        return attributes
    }

    /// Debug PDF page text extraction with details
    /// - Parameters:
    ///   - page: PDF page to inspect
    ///   - pageNumber: Page number for logging
    func debugPageText(page: PDFPage, pageNumber: Int) {
        print("\n=== PAGE \(pageNumber) DEBUG ===")
        print("Bounds: \(page.bounds(for: .mediaBox))")
        print("Rotation: \(page.rotation)")

        // Extract text
        if let text = page.string {
            let lines = text.components(separatedBy: .newlines)
            print("Total lines: \(lines.count)")
            print("Total characters: \(text.count)")

            // Show first 20 lines
            print("\nFirst 20 lines:")
            for (i, line) in lines.prefix(20).enumerated() {
                print(String(format: "%3d: %@", i+1, line))
            }
        }

        // Check for selections (can give us text with bounds)
        if let selection = page.selection(for: page.bounds(for: .mediaBox)) {
            print("\nSelection available: \(selection.string?.count ?? 0) characters")
        }
    }

    // MARK: - Public Methods

    /// Parse statement period from PDF text
    /// - Parameter text: Text from PDF page 1
    /// - Returns: Tuple with start date, end date, and formatted period string
    func parseStatementPeriod(from text: String) throws -> (startDate: Date, endDate: Date, period: String)? {
        // Real PDFs have format: "Weekly Statement\nAug 4, 2025 4 AM - Aug 11, 2025 4 AM"
        // Pattern allows for optional newlines and "Weekly Statement" prefix
        let pattern = #"([A-Za-z]+)\s+(\d+),\s+(\d{4})\s+4\s+AM\s+-\s+([A-Za-z]+)\s+(\d+),\s+(\d{4})\s+4\s+AM"#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]),
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
        var tollsReimbursed: Double? = nil
        if layout == .sixColumn && components.count >= 6 {
            let tollStr = components[3].replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "")
            tollsReimbursed = Double(tollStr)
        }

        return UberTransaction(
            transactionDate: transactionDate,
            eventDate: nil,
            eventType: eventType,
            amount: amount,
            tollsReimbursed: tollsReimbursed,
            statementPeriod: "",  // Will be filled in by caller
            shiftID: nil,
            importDate: Date()
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

        // Pattern to identify transaction start: "Day, Mon DD" (e.g., "Sun, Aug 24")
        let transactionStartPattern = #"^(Mon|Tue|Wed|Thu|Fri|Sat|Sun),\s+([A-Za-z]+)\s+(\d+)$"#
        guard let startRegex = try? NSRegularExpression(pattern: transactionStartPattern) else {
            return []
        }

        var currentTransactionLines: [String] = []
        var inTransactionTable = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip empty lines
            if trimmed.isEmpty {
                continue
            }

            // Detect start of transaction table
            if trimmed.contains("Processed") && trimmed.contains("Event") && trimmed.contains("Your earnings") {
                inTransactionTable = true
                continue
            }

            // Stop at page footer
            if trimmed.contains("GEORGE KNAGGS") && trimmed.contains("of") {
                inTransactionTable = false
                // Process any pending transaction
                if !currentTransactionLines.isEmpty {
                    if let transaction = parseMultiLineTransaction(currentTransactionLines, layout: layout, statementEndDate: statementEndDate) {
                        transactions.append(transaction)
                    }
                    currentTransactionLines.removeAll()
                }
                continue
            }

            if !inTransactionTable {
                continue
            }

            // Check if this line starts a new transaction
            let range = NSRange(trimmed.startIndex..., in: trimmed)
            if startRegex.firstMatch(in: trimmed, range: range) != nil {
                // Process previous transaction if exists
                if !currentTransactionLines.isEmpty {
                    if let transaction = parseMultiLineTransaction(currentTransactionLines, layout: layout, statementEndDate: statementEndDate) {
                        transactions.append(transaction)
                    }
                    currentTransactionLines.removeAll()
                }
                // Start new transaction
                currentTransactionLines.append(trimmed)
            } else if !currentTransactionLines.isEmpty {
                // Add to current transaction
                currentTransactionLines.append(trimmed)
            }
        }

        // Process final transaction
        if !currentTransactionLines.isEmpty {
            if let transaction = parseMultiLineTransaction(currentTransactionLines, layout: layout, statementEndDate: statementEndDate) {
                transactions.append(transaction)
            }
        }

        // Post-process: Handle orphaned amounts (PDF extraction issue where amounts are separated from their transactions)
        return matchOrphanedAmounts(transactions, layout: layout)
    }

    /// Match orphaned amounts to transactions that are missing amounts
    /// This handles PDF extraction issues where amounts are grouped together separately from their transactions
    /// - Parameters:
    ///   - transactions: Array of parsed transactions
    ///   - layout: Column layout
    /// - Returns: Transactions with orphaned amounts matched
    private func matchOrphanedAmounts(_ transactions: [UberTransaction], layout: ColumnLayout) -> [UberTransaction] {
        var result: [UberTransaction] = []
        var orphanedTransactions: [UberTransaction] = []

        for transaction in transactions {
            if transaction.amount == 0 {
                // Transaction has no amount - save for later matching
                orphanedTransactions.append(transaction)
            } else if !orphanedTransactions.isEmpty {
                // We have a transaction with an amount and pending orphaned transactions
                // Match the first orphaned transaction with this amount
                var matchedTransaction = orphanedTransactions.removeFirst()
                matchedTransaction.amount = transaction.amount
                matchedTransaction.tollsReimbursed = transaction.tollsReimbursed
                matchedTransaction.needsManualVerification = true
                result.append(matchedTransaction)
            } else {
                // Normal transaction with amount
                result.append(transaction)
            }
        }

        // If we still have orphaned transactions at the end, they're likely incomplete
        // Skip them rather than including incomplete data

        return result
    }

    /// Parse a multi-line transaction block
    /// - Parameters:
    ///   - lines: Lines belonging to one transaction
    ///   - layout: Column layout
    ///   - statementEndDate: Statement end date for year inference
    /// - Returns: Parsed transaction or nil
    private func parseMultiLineTransaction(_ lines: [String], layout: ColumnLayout, statementEndDate: Date) -> UberTransaction? {
        guard lines.count >= 4 else { return nil }

        // Line 0: "Day, Mon DD" (e.g., "Sun, Aug 24")
        // Line 1: Time (e.g., "6:27 PM")
        // Next lines: Event type, event date, amounts, balance

        // Parse processed date/time
        guard let processedDate = parseMultiLineDate(dateLine: lines[0], timeLine: lines[1], statementEndDate: statementEndDate) else {
            return nil
        }

        // Find event type (first line that's not a date/time or amount)
        var eventType = ""
        var amountLines: [String] = []

        for i in 2..<lines.count {
            let line = lines[i]

            // Skip event date lines (format: "Aug 24 4:45 PM")
            if line.range(of: #"^[A-Za-z]+\s+\d+\s+\d+:\d+\s+(AM|PM)$"#, options: .regularExpression) != nil {
                continue
            }

            // Collect amount lines (start with $)
            if line.hasPrefix("$") {
                amountLines.append(line)
                continue
            }

            // First non-date, non-amount line is the event type
            if eventType.isEmpty && !line.contains(":") {
                eventType = line
                continue
            }

            // Multi-line event types (e.g., "Promotion - $15.00 extra for\ncompleting 3 Shop & Deliver orders")
            if !eventType.isEmpty && !line.hasPrefix("$") && !line.contains(":") {
                eventType += " " + line
            }
        }

        // Parse amounts (if present)
        let (amount, tollsReimbursed) = if !amountLines.isEmpty {
            parseAmounts(amountLines, layout: layout)
        } else {
            (0.0, nil)  // No amounts found - will be matched later with orphaned amounts
        }

        return UberTransaction(
            transactionDate: processedDate,
            eventDate: nil,
            eventType: eventType.trimmingCharacters(in: .whitespaces),
            amount: amount,
            tollsReimbursed: tollsReimbursed,
            statementPeriod: "",  // Will be filled in by caller
            shiftID: nil,
            importDate: Date()
        )
    }

    /// Parse date from two lines: date line and time line
    /// - Parameters:
    ///   - dateLine: Date line (e.g., "Sun, Aug 24")
    ///   - timeLine: Time line (e.g., "6:27 PM")
    ///   - statementEndDate: Statement end date for year inference
    /// - Returns: Parsed date or nil
    private func parseMultiLineDate(dateLine: String, timeLine: String, statementEndDate: Date) -> Date? {
        // Parse date line: "Sun, Aug 24"
        let datePattern = #"^(?:Mon|Tue|Wed|Thu|Fri|Sat|Sun),\s+([A-Za-z]+)\s+(\d+)$"#
        guard let dateRegex = try? NSRegularExpression(pattern: datePattern),
              let dateMatch = dateRegex.firstMatch(in: dateLine, range: NSRange(dateLine.startIndex..., in: dateLine)),
              let monthRange = Range(dateMatch.range(at: 1), in: dateLine),
              let dayRange = Range(dateMatch.range(at: 2), in: dateLine) else {
            return nil
        }

        let monthStr = String(dateLine[monthRange])
        guard let day = Int(dateLine[dayRange]) else { return nil }

        // Parse time line: "6:27 PM"
        let timePattern = #"^(\d+):(\d+)\s+(AM|PM)$"#
        guard let timeRegex = try? NSRegularExpression(pattern: timePattern),
              let timeMatch = timeRegex.firstMatch(in: timeLine, range: NSRange(timeLine.startIndex..., in: timeLine)),
              let hourRange = Range(timeMatch.range(at: 1), in: timeLine),
              let minuteRange = Range(timeMatch.range(at: 2), in: timeLine),
              let amPmRange = Range(timeMatch.range(at: 3), in: timeLine) else {
            return nil
        }

        guard let hour12 = Int(timeLine[hourRange]),
              let minute = Int(timeLine[minuteRange]) else {
            return nil
        }
        let amPm = String(timeLine[amPmRange])

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

    /// Parse amounts from amount lines
    /// - Parameters:
    ///   - lines: Lines containing amounts
    ///   - layout: Column layout
    /// - Returns: Tuple of (amount, tollReimbursement)
    private func parseAmounts(_ lines: [String], layout: ColumnLayout) -> (Double, Double?) {
        guard !lines.isEmpty else { return (0, nil) }

        // First amount line contains "Your earnings" and optionally "Refunds & Expenses"
        // Format: "$21.55 $2.71" or "$21.55" (with balance on same or next line)
        let firstLine = lines[0]
        let amounts = firstLine.components(separatedBy: " ")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.hasPrefix("$") }
            .compactMap { Double($0.replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "")) }

        guard let yourEarnings = amounts.first else { return (0, nil) }

        // Check for toll reimbursement (6-column layout)
        if layout == .sixColumn && amounts.count >= 2 {
            let tollAmount = amounts[1]
            return (yourEarnings, tollAmount > 0 ? tollAmount : nil)
        }

        return (yourEarnings, nil)
    }

    // MARK: - Coordinate-Based Parsing Helpers

    /// Group PDFSelections by Y-coordinate (rows)
    /// - Parameters:
    ///   - selections: Array of PDFSelection objects from selectionsByLine()
    ///   - page: PDFPage for getting bounds
    /// - Returns: Array of rows, where each row is an array of selections sorted by X-coordinate
    private func groupByRows(_ selections: [PDFSelection], page: PDFPage) -> [[PDFSelection]] {
        // Group by Y-coordinate with tolerance
        let yTolerance = 5.0
        var rows: [[PDFSelection]] = []

        for selection in selections {
            let bounds = selection.bounds(for: page)
            let y = bounds.origin.y

            // Find existing row with similar Y-coordinate
            if let rowIndex = rows.firstIndex(where: { row in
                guard let firstBounds = row.first?.bounds(for: page) else { return false }
                return abs(firstBounds.origin.y - y) < yTolerance
            }) {
                // Add to existing row
                rows[rowIndex].append(selection)
            } else {
                // Create new row
                rows.append([selection])
            }
        }

        // Sort rows by Y-coordinate (descending - top to bottom)
        rows.sort { row1, row2 in
            guard let y1 = row1.first?.bounds(for: page).origin.y,
                  let y2 = row2.first?.bounds(for: page).origin.y else {
                return false
            }
            return y1 > y2
        }

        // Within each row, sort selections by X-coordinate (left to right)
        for i in 0..<rows.count {
            rows[i].sort { sel1, sel2 in
                let x1 = sel1.bounds(for: page).origin.x
                let x2 = sel2.bounds(for: page).origin.x
                return x1 < x2
            }
        }

        return rows
    }

    /// Parse transactions from grouped rows
    /// - Parameters:
    ///   - rows: Rows of PDFSelection objects grouped by Y-coordinate
    ///   - pageNum: Page number for debugging
    /// - Returns: Array of parsed transactions
    private func parseTransactionsFromRows(_ rows: [[PDFSelection]], pageNum: Int) -> [UberTransaction] {
        guard !rows.isEmpty else { return [] }

        var transactions: [UberTransaction] = []

        // Find header row to detect column layout
        var columnLayout: ColumnLayout = .fiveColumn
        for row in rows {
            let rowText = row.map { $0.string ?? "" }.joined(separator: " ")
            if rowText.contains("Processed") && rowText.contains("Event") && rowText.contains("Your earnings") {
                columnLayout = detectColumnLayout(from: rowText)
                break
            }
        }

        // Pattern to identify transaction start: "Day, Mon DD" (e.g., "Sat, Aug 9" or "T ue, Aug 5")
        let transactionPattern = #"^(?:Mon|Tue|Wed|Thu|Fri|Sat|Sun|T\s+ue),\s+([A-Za-z]+)\s+(\d+)$"#
        guard let transactionRegex = try? NSRegularExpression(pattern: transactionPattern) else {
            return []
        }

        // Scan rows for transactions
        var currentTransactionRows: [[PDFSelection]] = []
        var inTransactionTable = false

        for row in rows {
            let rowText = row.map { $0.string ?? "" }.joined(separator: " ")

            // Skip empty rows
            if rowText.trimmingCharacters(in: .whitespaces).isEmpty {
                continue
            }

            // Detect start of transaction table
            if rowText.contains("Processed") && rowText.contains("Event") {
                inTransactionTable = true
                continue
            }

            // Stop at page footer
            if rowText.contains("GEORGE KNAGGS") || (rowText.contains("Page") && rowText.contains("of")) {
                inTransactionTable = false
                // Process any pending transaction
                if !currentTransactionRows.isEmpty {
                    if let transaction = parseCoordinateBasedTransaction(currentTransactionRows, layout: columnLayout) {
                        transactions.append(transaction)
                    }
                    currentTransactionRows.removeAll()
                }
                break
            }

            if !inTransactionTable {
                continue
            }

            // Check if first element in row matches transaction date pattern
            let firstText = row.first?.string ?? ""
            let range = NSRange(firstText.startIndex..., in: firstText)

            if transactionRegex.firstMatch(in: firstText, range: range) != nil {
                // This is a new transaction - process previous one
                if !currentTransactionRows.isEmpty {
                    if let transaction = parseCoordinateBasedTransaction(currentTransactionRows, layout: columnLayout) {
                        transactions.append(transaction)
                    }
                    currentTransactionRows.removeAll()
                }
                // Start new transaction
                currentTransactionRows.append(row)
            } else if !currentTransactionRows.isEmpty {
                // Add row to current transaction
                currentTransactionRows.append(row)
            }
        }

        // Process final transaction
        if !currentTransactionRows.isEmpty {
            if let transaction = parseCoordinateBasedTransaction(currentTransactionRows, layout: columnLayout) {
                transactions.append(transaction)
            }
        }

        return transactions
    }

    /// Parse a single transaction from its row group
    /// - Parameters:
    ///   - rows: Rows belonging to this transaction
    ///   - layout: Column layout
    /// - Returns: Parsed transaction or nil
    private func parseCoordinateBasedTransaction(_ rows: [[PDFSelection]], layout: ColumnLayout) -> UberTransaction? {
        guard !rows.isEmpty else { return nil }

        // Combine all text elements from all rows
        var allElements: [(text: String, x: Double, y: Double)] = []

        for row in rows {
            for selection in row {
                guard let page = selection.pages.first else { continue }
                let bounds = selection.bounds(for: page)
                let text = (selection.string ?? "").trimmingCharacters(in: .whitespaces)
                if !text.isEmpty {
                    allElements.append((text, bounds.origin.x, bounds.origin.y))
                }
            }
        }

        guard !allElements.isEmpty else { return nil }

        // Sort elements by position (top-to-bottom via descending Y, then left-to-right via ascending X)
        // This ensures we process elements in reading order
        allElements.sort { first, second in
            if abs(first.y - second.y) < 5.0 {
                // Same row - sort left to right
                return first.x < second.x
            }
            // Different rows - sort top to bottom (higher Y = lower on page in PDF coordinates)
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
        let trailingAmountsPattern = #"([-+]?\$\d+\.\d+)+$"#  // Pattern for amounts at end of text

        var datePart: String?
        var timePart: String?
        var foundEventDate = false  // Track if we've found the event date/time
        var firstLineY: Double?  // Y-coordinate of first line (processed date line)
        var secondLineY: Double?  // Y-coordinate of second line

        // Parse elements in order:
        // 1. Processed date (e.g., "Sat, Aug 9")
        // 2. Processed time (e.g., "12:24 AM")
        // 3. Event type (may be multi-line, e.g., "UberX" + "Priority")
        // 4. Event date/time (e.g., "Aug 8 10:45 PM") - may appear on different row than amounts
        // 5. Amounts (e.g., "$2.92", "$2.92", "$208.23") - collected regardless of order
        // NOTE: Stop collecting amounts once event date/time is found (marks end of transaction data)

        for element in allElements {
            // Track which line we're on by Y-coordinate
            if firstLineY == nil {
                firstLineY = element.y
            } else if secondLineY == nil && abs(element.y - (firstLineY ?? 0)) >= 5.0 {
                secondLineY = element.y
            }

            let isFirstLine = firstLineY != nil && abs(element.y - firstLineY!) < 5.0
            let isSecondLine = secondLineY != nil && abs(element.y - secondLineY!) < 5.0

            // Check for processed date (format: "Sat, Aug 9" or "T ue, Aug 5")
            if element.text.range(of: datePattern, options: .regularExpression) != nil {
                datePart = element.text
            }
            // Check for processed time (format: "12:24 AM")
            else if element.text.range(of: timePattern, options: .regularExpression) != nil {
                timePart = element.text
            }
            // Check for event date/time (format: "Aug 24 4:45 PM")
            else if element.text.range(of: eventDatePattern, options: .regularExpression) != nil {
                // Parse event date (when the ride/trip actually occurred)
                let calendar = Calendar.current
                let currentYear = calendar.component(.year, from: Date())
                eventDate = parseEventDateTime(text: element.text, year: currentYear)
                foundEventDate = true
                // Don't collect any more amounts after event date - they belong to other columns or next transaction
            }
            // Check for amounts - Parse amounts from line 1 only
            // Line 2 amounts are from balance column, line 3+ amounts stay in event type
            else if !foundEventDate && isFirstLine && element.text.range(of: #"[-+]?\$\d+\.\d+"#, options: .regularExpression) != nil {
                // Use regex to extract all amounts (handles "-$600.15-$600.15" without spaces)
                let amountPattern = #"[-+]?\$\d+\.\d+"#
                let amountRegex = try! NSRegularExpression(pattern: amountPattern)
                let amountMatches = amountRegex.matches(in: element.text, range: NSRange(element.text.startIndex..., in: element.text))

                for amountMatch in amountMatches {
                    if let amountRange = Range(amountMatch.range, in: element.text) {
                        let amountStr = String(element.text[amountRange])
                        // Remove $ and commas, then parse
                        let numStr = amountStr.replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "")
                        if let amount = Double(numStr) {
                            amounts.append(amount)
                        }
                    }
                }
            }
            // Check for embedded amounts at end of text (promotions, account transfers)
            else if element.text.range(of: trailingAmountsPattern, options: .regularExpression) != nil {
                // Line 1: Extract amounts and add to amounts array, keep rest as event type
                if isFirstLine && !foundEventDate {
                    var textToProcess = element.text

                    // Extract all trailing amounts using regex
                    let regex = try! NSRegularExpression(pattern: trailingAmountsPattern)
                    if let match = regex.firstMatch(in: textToProcess, range: NSRange(textToProcess.startIndex..., in: textToProcess)) {
                        let matchRange = match.range
                        if let range = Range(matchRange, in: textToProcess) {
                            let amountsString = String(textToProcess[range])

                            // Parse individual amounts from the matched string
                            let amountPattern = #"[-+]?\$\d+\.\d+"#
                            let amountRegex = try! NSRegularExpression(pattern: amountPattern)
                            let amountMatches = amountRegex.matches(in: amountsString, range: NSRange(amountsString.startIndex..., in: amountsString))

                            for amountMatch in amountMatches {
                                if let amountRange = Range(amountMatch.range, in: amountsString) {
                                    let amountStr = String(amountsString[amountRange])
                                    // Remove $ and parse
                                    let numStr = amountStr.replacingOccurrences(of: "$", with: "")
                                    if let amount = Double(numStr) {
                                        amounts.append(amount)
                                    }
                                }
                            }

                            // Remove amounts from text, keep rest as event type
                            textToProcess.removeSubrange(range)
                            textToProcess = textToProcess.trimmingCharacters(in: .whitespaces)
                        }
                    }

                    // Add remaining text to event type if not empty
                    if !textToProcess.isEmpty {
                        if !eventType.isEmpty {
                            eventType += " "
                        }
                        eventType += textToProcess
                    }
                }
                // Line 2: Ignore trailing amounts (balance column)
                else if isSecondLine {
                    var textToProcess = element.text

                    // Remove trailing amounts
                    let regex = try! NSRegularExpression(pattern: trailingAmountsPattern)
                    if let match = regex.firstMatch(in: textToProcess, range: NSRange(textToProcess.startIndex..., in: textToProcess)) {
                        if let range = Range(match.range, in: textToProcess) {
                            textToProcess.removeSubrange(range)
                            textToProcess = textToProcess.trimmingCharacters(in: .whitespaces)
                        }
                    }

                    // Add remaining text to event type if not empty
                    if !textToProcess.isEmpty {
                        if !eventType.isEmpty {
                            eventType += " "
                        }
                        eventType += textToProcess
                    }
                }
                // Line 3+: Keep everything as-is (amounts embedded in event type text)
                else {
                    if !eventType.isEmpty {
                        eventType += " "
                    }
                    eventType += element.text
                }
            }
            // Event type is everything else (may be multi-line like "UberX Priority")
            // Exclude dollar amounts and dates/times from event type
            else if !element.text.hasPrefix("$") &&
                    element.text.range(of: datePattern, options: .regularExpression) == nil &&
                    element.text.range(of: timePattern, options: .regularExpression) == nil &&
                    element.text.range(of: eventDatePattern, options: .regularExpression) == nil {
                if !eventType.isEmpty {
                    eventType += " "
                }
                eventType += element.text
            }
        }

        // Parse date from date + time parts
        if let datePart = datePart, let timePart = timePart {
            // Use current year for now (should infer from statement period)
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
            statementPeriod: "",  // Will be filled in by caller
            shiftID: nil,
            importDate: Date()
        )
    }

    // MARK: - Test-Friendly Coordinate Parsing

    /// Parse transaction from coordinate elements (test-friendly version)
    /// - Parameters:
    ///   - elements: Array of (text, x, y) tuples representing PDF elements
    ///   - layout: Column layout (5 or 6 column)
    /// - Returns: Parsed transaction or nil
    // MARK: ⚠️ SYNC POINT START ⚠️
    // This method contains core parsing logic that is DUPLICATED in test_all_uber_statements.swift
    // If you modify the parsing logic below, you MUST update the standalone script as well!
    // See: test_all_uber_statements.swift -> parseTransaction() method
    // Critical sections:
    //   - Line detection logic (firstLine, secondLine tracking)
    //   - Standalone amount pattern: ^([-+]?\$\d+\.\d+\s*)+$
    //   - Line-based amount handling (different rules for line 1, 2, 3+)
    internal func parseTransactionFromElements(_ elements: [(text: String, x: CGFloat, y: CGFloat)], layout: ColumnLayout) -> UberTransaction? {
        guard !elements.isEmpty else { return nil }

        // Convert to format used by parsing logic
        var allElements: [(text: String, x: Double, y: Double)] = elements.map {
            ($0.text, Double($0.x), Double($0.y))
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
            statementPeriod: "",  // Will be filled in by caller
            shiftID: nil,
            importDate: Date()
        )
    }
    // MARK: ⚠️ SYNC POINT END ⚠️

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

        // Map month name to number
        let monthMap = [
            "Jan": 1, "Feb": 2, "Mar": 3, "Apr": 4, "May": 5, "Jun": 6,
            "Jul": 7, "Aug": 8, "Sep": 9, "Oct": 10, "Nov": 11, "Dec": 12
        ]

        guard let month = monthMap[monthStr] else { return nil }

        // Create date
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
