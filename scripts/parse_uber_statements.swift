#!/usr/bin/env swift

import Foundation
import PDFKit

/// Comprehensive validation script for all Uber PDF statements
/// Validates parsing quality across all your local Uber earnings PDFs
///
/// ⚠️ IMPORTANT: This script duplicates parsing logic from UberStatementManager.swift
/// See PARSE_UBER_STATEMENTS.md for sync instructions

// MARK: - Configuration

let pdfDirectory: String
if CommandLine.arguments.count >= 2 {
    pdfDirectory = CommandLine.arguments[1]
} else {
    // Default to common iCloud location
    let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
    pdfDirectory = "\(homeDir)/Library/Mobile Documents/com~apple~CloudDocs/Uber_Statements"
}

print("=== UBER PDF STATEMENT VALIDATOR ===")
print("Scanning directory: \(pdfDirectory)\n")

// MARK: - Data Models

struct ParsedTransaction {
    let eventDate: String
    let eventType: String
    let amount: Double?
    let tollReimbursement: Double?
    let runningBalance: Double?
    let sourceRow: Int  // For debugging
}

struct ValidationResult {
    let filename: String
    let success: Bool
    let transactionCount: Int
    let errors: [String]
    let warnings: [String]
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

    func parsePDF(at url: URL) -> (transactions: [ParsedTransaction], errors: [String], warnings: [String]) {
        guard let pdfDocument = PDFDocument(url: url) else {
            return ([], ["Could not load PDF"], [])
        }

        var allTransactions: [ParsedTransaction] = []
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

                if let rowIndex = rows.firstIndex(where: { abs($0.y - y) < 5.0 }) {
                    rows[rowIndex].elements.append((x, text))
                } else {
                    rows.append((y, [(x, text)]))
                }
            }

            // Sort rows by Y coordinate (descending - higher Y = top of page)
            rows.sort { $0.y > $1.y }

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
                    if let transaction = parseTransaction(from: transactionElements, rowIndex: rowIdx) {
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
    // This method MUST stay in sync with UberStatementManager.swift
    // Source: Rideshare Tracker/Managers/UberStatementManager.swift
    // Method: parseTransactionFromElements() (lines 922-1084)
    //
    // Critical sections to sync:
    //   - Regex patterns (datePattern, standalone amount pattern, trailing amounts)
    //   - Line detection logic (firstLine, secondLine tracking)
    //   - Line-based amount handling rules
    private func parseTransaction(from elements: [(text: String, x: CGFloat, y: CGFloat)], rowIndex: Int) -> ParsedTransaction? {
        var eventDate = ""
        var eventType = ""
        var amount: Double?
        var tollReimbursement: Double?
        var runningBalance: Double?

        var currentLineNum = 0
        var currentY: CGFloat?
        var foundEventDate = false

        for element in elements {
            // Detect line breaks (new Y coordinate)
            if let lastY = currentY, abs(element.y - lastY) > 3.0 {
                currentLineNum += 1
            }
            currentY = element.y

            let isFirstLine = (currentLineNum == 0)
            let isSecondLine = (currentLineNum == 1)

            // Line 0: Date and event type
            if isFirstLine {
                if !foundEventDate {
                    if dateRegex.firstMatch(in: element.text, range: NSRange(element.text.startIndex..., in: element.text)) != nil {
                        eventDate = element.text
                        foundEventDate = true
                        continue
                    }
                }

                // Check for standalone amounts - Only if text is ONLY amounts (no other text)
                // This handles cases like "$15.00 $15.00" or "$2.00 $2.00"
                if !foundEventDate && element.text.range(of: #"^([-+]?\$\d+\.\d+\s*)+$"#, options: .regularExpression) != nil {
                    // Extract amounts
                    let extractedAmounts = extractAllAmounts(from: element.text)
                    if extractedAmounts.count >= 2 {
                        amount = extractedAmounts[0]
                        tollReimbursement = extractedAmounts[1]
                    } else if extractedAmounts.count == 1 {
                        amount = extractedAmounts[0]
                    }
                    continue
                }

                // Otherwise add to event type
                if foundEventDate {
                    if !eventType.isEmpty {
                        eventType += " "
                    }
                    eventType += element.text
                }
            }
            // Line 1: Time and balance (ignore amounts on this line)
            else if isSecondLine {
                // Strip trailing amounts from this line
                let textWithoutAmounts = element.text.replacingOccurrences(
                    of: #"([-+]?\$\d+\.\d+)+$"#,
                    with: "",
                    options: .regularExpression
                ).trimmingCharacters(in: .whitespaces)

                if !textWithoutAmounts.isEmpty {
                    if !eventType.isEmpty {
                        eventType += " "
                    }
                    eventType += textWithoutAmounts
                }

                // Extract running balance (rightmost amount)
                let amountsOnLine = extractAllAmounts(from: element.text)
                if let lastAmount = amountsOnLine.last {
                    runningBalance = lastAmount
                }
            }
            // Line 2+: Part of event type (keep all amounts embedded in text)
            else {
                if !eventType.isEmpty {
                    eventType += " "
                }
                eventType += element.text
            }
        }

        // Validate we got essential data
        guard !eventDate.isEmpty else { return nil }

        return ParsedTransaction(
            eventDate: eventDate,
            eventType: eventType,
            amount: amount,
            tollReimbursement: tollReimbursement,
            runningBalance: runningBalance,
            sourceRow: rowIndex
        )
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
        if transaction.eventDate.isEmpty {
            allErrors.append("Transaction \(idx + 1): Missing event date")
        }
        if transaction.eventType.isEmpty {
            allWarnings.append("Transaction \(idx + 1): Empty event type")
        }
        if transaction.eventType.contains("Reimbursement") && transaction.tollReimbursement == nil {
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
        warnings: allWarnings
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
