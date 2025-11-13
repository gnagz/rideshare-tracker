#!/usr/bin/env swift

import Foundation
import PDFKit

/// Extract coordinate data from Uber PDF transaction for creating unit tests
/// Usage: swift extract_transaction_coordinates.swift <pdf_path> <transaction_number>
/// Example: swift extract_transaction_coordinates.swift "Uber_Earnings_Statement_Oct_13.pdf" 19

guard CommandLine.arguments.count >= 3 else {
    print("❌ Usage: swift extract_transaction_coordinates.swift <pdf_path> <transaction_number>")
    print("   Example: swift extract_transaction_coordinates.swift \"Oct_13.pdf\" 19")
    exit(1)
}

let pdfPath = CommandLine.arguments[1]
guard let transactionNumber = Int(CommandLine.arguments[2]) else {
    print("❌ Transaction number must be an integer")
    exit(1)
}

let url = URL(fileURLWithPath: pdfPath)

guard let pdfDocument = PDFDocument(url: url) else {
    print("❌ Could not load PDF from: \(pdfPath)")
    exit(1)
}

print("=== EXTRACTING TRANSACTION COORDINATES ===")
print("PDF: \(pdfPath)")
print("Searching for transaction #\(transactionNumber)\n")

let datePattern = #"^(?:Mon|Tue|Wed|Thu|Fri|Sat|Sun|T\s+ue),\s+([A-Za-z]+)\s+(\d+)$"#
guard let regex = try? NSRegularExpression(pattern: datePattern) else {
    print("❌ Could not create regex")
    exit(1)
}

var transactionCount = 0

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

    // Count transactions and find the Nth one
    for (rowIdx, row) in rows.enumerated() {
        let sortedElements = row.elements.sorted { $0.x < $1.x }

        // Check if first element matches transaction date pattern
        if let firstElement = sortedElements.first,
           regex.firstMatch(in: firstElement.text, range: NSRange(firstElement.text.startIndex..., in: firstElement.text)) != nil {
            transactionCount += 1

            if transactionCount == transactionNumber {
                print("✅ Found transaction #\(transactionNumber) on page \(pageNum + 1), row \(rowIdx)")
                print("   Y-coordinate: \(row.y)\n")

                // DEBUG: Show surrounding rows to understand the structure
                print("   Context - showing rows \(rowIdx) to \(min(rowIdx + 10, rows.count - 1)):")
                for debugIdx in rowIdx..<min(rowIdx + 11, rows.count) {
                    let debugRow = rows[debugIdx]
                    let debugElems = debugRow.elements.sorted { $0.x < $1.x }
                    let debugDesc = debugElems.map { "[\"\($0.text)\" @ X:\(String(format: "%.1f", $0.x))]" }.joined(separator: ", ")
                    print("     [\(debugIdx)] Y=\(String(format: "%.1f", debugRow.y)): \(debugDesc)")
                }
                print("")

                // Collect all rows for this transaction until the next transaction starts
                var transactionElements: [(text: String, x: CGFloat, y: CGFloat)] = []

                var offset = 0
                var maxRows = 15  // Safety limit
                while rowIdx + offset < rows.count && offset < maxRows {
                    let targetRow = rows[rowIdx + offset]
                    let sortedElems = targetRow.elements.sorted { $0.x < $1.x }

                    // Debug: print what's on this row
                    let elementsDesc = sortedElems.map { "[\"\($0.text)\" @ X:\(String(format: "%.1f", $0.x))]" }.joined(separator: ", ")
                    print("   Row \(offset) (Y=\(String(format: "%.1f", targetRow.y))): \(elementsDesc)")

                    // Check if this row starts a new transaction (skip first row)
                    if offset > 0 {
                        if let firstElement = sortedElems.first,
                           firstElement.x < 40.0,  // Must be in leftmost column (transaction dates start ~36.8)
                           regex.firstMatch(in: firstElement.text, range: NSRange(firstElement.text.startIndex..., in: firstElement.text)) != nil {
                            // Found the next transaction, stop here
                            print("   -> STOP: Next transaction detected\n")
                            break
                        }
                    }

                    // Add all elements from this row
                    for elem in targetRow.elements.sorted(by: { $0.x < $1.x }) {
                        transactionElements.append((elem.text, elem.x, targetRow.y))
                    }

                    offset += 1
                }

                print("   Collected \(offset) rows total\n")

                // Output in test format
                print("=== SWIFT TEST CODE ===\n")
                print("let elements: [(text: String, x: CGFloat, y: CGFloat)] = [")

                for elem in transactionElements {
                    print("    (\"\(elem.text)\", \(elem.x), \(elem.y)),")
                }

                print("]")
                print("\n=== RAW COORDINATE DATA ===\n")
                print("Text                           | X        | Y")
                print(String(repeating: "-", count: 50))

                for elem in transactionElements {
                    let truncatedText = String(elem.text.prefix(30))
                    let paddedText = truncatedText.padding(toLength: 30, withPad: " ", startingAt: 0)
                    print("\(paddedText) | \(elem.x) | \(elem.y)")
                }

                print("\n✅ Done! Copy the test code above into your unit test.")
                exit(0)
            }
        }
    }
}

print("❌ Transaction #\(transactionNumber) not found")
print("   Total transactions found: \(transactionCount)")
exit(1)
