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
        let months = ["Jan": 1, "Feb": 2, "Mar": 3, "Apr": 4, "May": 5, "Jun": 6,
                      "Jul": 7, "Aug": 8, "Sep": 9, "Oct": 10, "Nov": 11, "Dec": 12]
        let startMonth = months[startMonthStr] ?? 1
        let endMonth = months[endMonthStr] ?? 1

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

    // MARK: - Coordinate-Based Parsing Helpers

    /// Group PDFSelections by Y-coordinate (rows)
    /// - Parameters:
    ///   - selections: Array of PDFSelection objects from selectionsByLine()
    ///   - page: PDFPage for getting bounds
    /// - Returns: Array of rows, where each row is an array of selections sorted by X-coordinate
    private func groupByRows(_ selections: [PDFSelection], page: PDFPage) -> [[PDFSelection]] {
        // Group by Y-coordinate with tolerance
        // Reduced from 5.0 to 2.0 to prevent mixing up values from different rows
        let yTolerance = 2.0
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

        // Convert PDFSelection elements to tuples for the parser
        var elements: [(text: String, x: CGFloat, y: CGFloat)] = []

        for row in rows {
            for selection in row {
                guard let page = selection.pages.first else { continue }
                let bounds = selection.bounds(for: page)
                let text = (selection.string ?? "").trimmingCharacters(in: .whitespaces)
                if !text.isEmpty {
                    elements.append((text, bounds.origin.x, bounds.origin.y))
                }
            }
        }

        guard !elements.isEmpty else { return nil }

        // Delegate to the parser utility
        return parseTransactionFromElements(elements, layout: layout, rowIndex: 0)
    }

    // MARK: - Private Helper Methods
    // Note: parseTransactionFromElements() is now a free function in UberStatementParser.swift
}
