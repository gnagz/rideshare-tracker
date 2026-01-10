//
//  UberStatementParser.swift
//  Rideshare Tracker
//
//  Created by George Knaggs in collaboration with Claude AI on 11/18/25.
//  Extracted from UberStatementManager.swift
//
//  ⚠️ ENTIRE FILE IS SYNC POINT ⚠️
//  Keep this file byte-for-byte identical with scripts/parse_uber_statements.swift
//  All parsing logic should be duplicated between this file and the validation script.

import Foundation

// MARK: - Column Layout

/// Column layout for Uber statement transaction table
enum ColumnLayout {
    case fiveColumn  // Without "Refunds & Expenses" (no tolls)
    case sixColumn   // With "Refunds & Expenses" (has tolls)
}

// MARK: - Column Layout Detection

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

// MARK: - Transaction Parsing

/// Parse transaction from coordinate elements (test-friendly version)
/// - Parameters:
///   - elements: Array of (text, x, y) tuples representing PDF elements
///   - layout: Column layout (5 or 6 column)
///   - rowIndex: Row index for debugging
///   - statementPeriod: Optional statement period dates for correct year inference
/// - Returns: Parsed transaction or nil
internal func parseTransactionFromElements(_ elements: [(text: String, x: CGFloat, y: CGFloat)], layout: ColumnLayout, rowIndex: Int, statementPeriod: (startDate: Date, endDate: Date)? = nil) -> UberTransaction? {
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
            eventDate = parseEventDateTime(text: element.text, statementPeriod: statementPeriod)
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
        processedDate = parseCoordinateBasedDate(datePart: datePart, timePart: timePart, statementPeriod: statementPeriod)
    }

    guard let processedDate = processedDate else { return nil }

    // Parse amounts based on event type and column layout
    let (amount, tollsReimbursed) = parseAmountsByEventType(amounts, eventType: eventType, layout: layout)

    // Mark for manual verification if eventDate is missing
    // This is critical for accurate shift matching - without eventDate, we fall back to
    // transactionDate which can be hours later (especially for tips)
    let needsVerification = (eventDate == nil)

    return UberTransaction(
        transactionDate: processedDate,
        eventDate: eventDate,
        eventType: eventType.trimmingCharacters(in: .whitespaces),
        amount: amount,
        tollsReimbursed: tollsReimbursed,
        needsManualVerification: needsVerification,
        statementPeriod: "",  // Will be filled in by caller
        shiftID: nil,
        importDate: Date(),
        sourceRow: rowIndex
    )
}

// MARK: - Date Parsing

/// Parse event date/time from combined string (e.g., "Aug 24 4:45 PM")
/// - Parameters:
///   - text: Event date/time string
///   - statementPeriod: Statement period for year inference (nil falls back to current year)
/// - Returns: Parsed date or nil
private func parseEventDateTime(text: String, statementPeriod: (startDate: Date, endDate: Date)?) -> Date? {
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

    // Create date - infer year from statement period
    let month = monthNumber(from: monthStr)
    let year = inferYear(forMonth: month, statementPeriod: statementPeriod)
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
///   - statementPeriod: Statement period for year inference (nil falls back to current year)
/// - Returns: Parsed date or nil
private func parseCoordinateBasedDate(datePart: String, timePart: String, statementPeriod: (startDate: Date, endDate: Date)?) -> Date? {
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

    // Create date - infer year from statement period
    let calendar = Calendar.current
    let month = monthNumber(from: monthStr)
    let year = inferYear(forMonth: month, statementPeriod: statementPeriod)

    var dateComponents = DateComponents()
    dateComponents.year = year
    dateComponents.month = month
    dateComponents.day = day
    dateComponents.hour = hour24
    dateComponents.minute = minute
    dateComponents.second = 0

    return calendar.date(from: dateComponents)
}

// MARK: - Amount Parsing

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

// MARK: - Helper Functions

/// Convert month name to number
/// - Parameter monthName: Month name ("Jan", "Feb", etc.)
/// - Returns: Month number (1-12)
private func monthNumber(from monthName: String) -> Int {
    let months = ["Jan": 1, "Feb": 2, "Mar": 3, "Apr": 4, "May": 5, "Jun": 6,
                  "Jul": 7, "Aug": 8, "Sep": 9, "Oct": 10, "Nov": 11, "Dec": 12]
    return months[monthName] ?? 1
}

/// Infer the correct year for a transaction date based on statement period
/// Handles year boundary cases (e.g., statement Dec 29, 2025 - Jan 5, 2026)
/// - Parameters:
///   - month: Month number (1-12) of the transaction
///   - statementPeriod: Optional statement period with start and end dates
/// - Returns: Year to use for the transaction date
private func inferYear(forMonth month: Int, statementPeriod: (startDate: Date, endDate: Date)?) -> Int {
    let calendar = Calendar.current

    guard let period = statementPeriod else {
        // Fallback to current year if no statement period provided
        return calendar.component(.year, from: Date())
    }

    let startYear = calendar.component(.year, from: period.startDate)
    let endYear = calendar.component(.year, from: period.endDate)
    let startMonth = calendar.component(.month, from: period.startDate)
    let endMonth = calendar.component(.month, from: period.endDate)

    // If statement period is within a single year, use that year
    if startYear == endYear {
        return startYear
    }

    // Statement crosses year boundary (e.g., Dec 2025 - Jan 2026)
    // Determine which year based on the transaction's month
    // - Months from startMonth to Dec belong to startYear
    // - Months from Jan to endMonth belong to endYear
    if month >= startMonth && month <= 12 {
        return startYear
    } else if month >= 1 && month <= endMonth {
        return endYear
    }

    // Edge case: month doesn't fit expected range, use start year as fallback
    return startYear
}
