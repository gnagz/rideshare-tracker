//
//  CSVImportManager.swift
//  Rideshare Tracker
//
//  Created by Claude AI on 9/28/25.
//

import Foundation
import SwiftUI

// Import the debugMessage function from DebugUtilities
// Note: Since DebugUtilities contains global functions, they should be available automatically
// But let's make sure by referencing the file structure where it's defined

// MARK: - Import Result Types

struct CSVImportResult {
    let shifts: [RideshareShift]
}

struct TollImportResult {
    let transactions: [TollTransaction]
    let updatedShifts: [RideshareShift]
    let imagesGenerated: Int
}

struct ExpenseImportResult {
    let expenses: [ExpenseItem]
}

enum CSVImportError: LocalizedError {
    case invalidFormat
    case fileReadError
    case missingRequiredColumns([String])
    case noDataRows

    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "Invalid CSV file format"
        case .fileReadError:
            return "Unable to read CSV file"
        case .missingRequiredColumns(let columns):
            return "Missing required columns: \(columns.joined(separator: ", "))"
        case .noDataRows:
            return "CSV file contains no data rows"
        }
    }
}

// MARK: - CSV Import Manager

@MainActor
class CSVImportManager {

    // MARK: - Secure File Access Utility

    /// Safely access file contents with security-scoped URL handling
    /// This handles both local files and document picker files automatically
    private static func secureFileAccess<T>(
        url: URL,
        operation: (URL) throws -> T
    ) -> Result<T, CSVImportError> {

        debugMessage("Starting secure file access: \(url.lastPathComponent)")

        // Handle security-scoped URLs from document picker
        let hasAccess = url.startAccessingSecurityScopedResource()
        debugMessage("Security-scoped URL access: \(hasAccess)")

        defer {
            if hasAccess {
                url.stopAccessingSecurityScopedResource()
                debugMessage("Released security-scoped URL access")
            }
        }

        do {
            let result = try operation(url)
            debugMessage("Secure file access completed successfully")
            return .success(result)
        } catch {
            debugMessage("ERROR: Secure file access failed: \(error.localizedDescription)")
            return .failure(.fileReadError)
        }
    }

    // MARK: - Public Import Methods

    /// Import shifts from CSV file
    static func importShifts(from url: URL) -> Result<CSVImportResult, CSVImportError> {
        debugMessage("Starting shift CSV import from: \(url.lastPathComponent)")

        return secureFileAccess(url: url) { url in
            let csvContent = try String(contentsOf: url, encoding: .utf8)
            let lines = csvContent.components(separatedBy: .newlines).filter { !$0.isEmpty }
            debugMessage("CSV file loaded: \(lines.count) non-empty lines found")

            guard lines.count > 1 else {
                debugMessage("ERROR: CSV file has insufficient data (\(lines.count) lines)")
                throw CSVImportError.noDataRows
            }

            let headers = parseCSVLine(lines[0])
            debugMessage("CSV headers parsed: \(headers.count) columns - [\(headers.joined(separator: ", "))]")

            var shifts: [RideshareShift] = []
            debugMessage("Processing \(lines.count - 1) data rows...")

            // Create formatters for parsing
            let dateFormatter = DateFormatter()
            let timeFormatter = DateFormatter()

            for i in 1..<lines.count {
                let values = parseCSVLine(lines[i])
                debugMessage("Row \(i): Parsed \(values.count) values")

                guard values.count >= headers.count else {
                    debugMessage("SKIP Row \(i): Insufficient columns (\(values.count) < \(headers.count))")
                    continue
                }

                if let shift = parseShiftFromCSVRow(headers: headers, values: values, rowIndex: i, dateFormatter: dateFormatter, timeFormatter: timeFormatter) {
                    shifts.append(shift)
                }
            }

            debugMessage("CSV import completed: \(shifts.count) shifts created successfully")
            return CSVImportResult(shifts: shifts)
        }
    }

    /// Import tolls from CSV file and update shifts
    @MainActor
    static func importTolls(from url: URL, dataManager: ShiftDataManager) -> Result<TollImportResult, CSVImportError> {
        debugMessage("Starting toll CSV import from: \(url.lastPathComponent)")

        return secureFileAccess(url: url) { url in
            let content = try String(contentsOf: url, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }

            guard lines.count > 1 else {
                throw CSVImportError.noDataRows
            }

            let headerLine = lines[0]
            let headers = parseCSVLine(headerLine)

            // Find required column indices
            var transactionDateIndex = -1
            var transactionAmountIndex = -1
            var locationIndex = -1
            var plateIndex = -1

            for (index, header) in headers.enumerated() {
                let lowercased = header.lowercased()
                if lowercased.contains("transaction entry date") || lowercased.contains("entry date") {
                    transactionDateIndex = index
                } else if lowercased.contains("transaction amount") || lowercased.contains("amount") {
                    transactionAmountIndex = index
                } else if lowercased.contains("location") {
                    locationIndex = index
                } else if lowercased.contains("plate") {
                    plateIndex = index
                }
            }

            guard transactionDateIndex >= 0, transactionAmountIndex >= 0 else {
                let missingColumns = [
                    transactionDateIndex < 0 ? "Transaction Entry Date/Time" : nil,
                    transactionAmountIndex < 0 ? "Transaction Amount" : nil
                ].compactMap { $0 }
                throw CSVImportError.missingRequiredColumns(missingColumns)
            }

            var transactions: [TollTransaction] = []
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MM/dd/yyyy HH:mm:ss"

            // Process each toll transaction
            for line in lines.dropFirst() {
                let values = parseCSVLine(line)
                guard transactionDateIndex < values.count, transactionAmountIndex < values.count else { continue }

                // Parse transaction date (Excel formulas already processed by parseCSVLine)
                let dateString = values[transactionDateIndex].trimmingCharacters(in: .whitespaces)
                guard let transactionDate = dateFormatter.date(from: dateString) else { continue }

                // Parse transaction amount (remove $ and negative sign, convert to positive)
                let amountString = values[transactionAmountIndex]
                    .replacingOccurrences(of: "-$", with: "")
                    .replacingOccurrences(of: "$", with: "")
                    .trimmingCharacters(in: .whitespaces)

                guard let tollAmount = Double(amountString) else { continue }

                // Parse location and plate (optional)
                let location = locationIndex >= 0 && locationIndex < values.count ?
                    values[locationIndex].trimmingCharacters(in: .whitespaces) : "Unknown Location"
                let plate = plateIndex >= 0 && plateIndex < values.count ?
                    values[plateIndex].trimmingCharacters(in: .whitespaces) : "Unknown Plate"

                // Create toll transaction record
                let tollTransaction = TollTransaction(
                    date: transactionDate,
                    location: location,
                    plate: plate,
                    amount: tollAmount
                )

                transactions.append(tollTransaction)
            }

            debugMessage("Toll CSV import completed: \(transactions.count) transactions parsed")

            // Match transactions to shifts and update toll amounts
            var shiftTollTransactions: [UUID: [TollTransaction]] = [:]

            // First pass: Collect all toll transactions per shift
            for tollTransaction in transactions {
                // Find matching shift(s) - transaction time should be between shift start and end
                let matchingShifts = dataManager.shifts.filter { shift in
                    guard let endDate = shift.endDate else { return false }
                    return tollTransaction.date >= shift.startDate && tollTransaction.date <= endDate
                }

                // Collect transactions for each matching shift
                for matchingShift in matchingShifts {
                    if shiftTollTransactions[matchingShift.id] == nil {
                        shiftTollTransactions[matchingShift.id] = []
                    }
                    shiftTollTransactions[matchingShift.id]?.append(tollTransaction)
                }
            }

            // Second pass: REPLACE each shift's toll amount and generate images
            var updatedShifts: [RideshareShift] = []
            var imagesGenerated = 0

            for (shiftId, tollTransactions) in shiftTollTransactions {
                guard let shiftIndex = dataManager.shifts.firstIndex(where: { $0.id == shiftId }) else { continue }

                // Calculate total tolls for this shift from imported transactions
                let totalTollsForShift = tollTransactions.reduce(0) { $0 + $1.amount }

                // REPLACE (not add to) the existing toll amount
                dataManager.shifts[shiftIndex].tolls = totalTollsForShift

                // Generate and attach toll summary image
                if let summaryImage = TollSummaryImageGenerator.generateTollSummaryImage(
                    shiftDate: dataManager.shifts[shiftIndex].startDate,
                    transactions: tollTransactions,
                    totalAmount: totalTollsForShift
                ) {
                    debugMessage("Generated toll summary image for \(tollTransactions.count) transactions")
                    do {
                        let attachment = try ImageManager.shared.saveImage(
                            summaryImage,
                            for: dataManager.shifts[shiftIndex].id,
                            parentType: .shift,
                            type: .receipt,
                            description: "Toll Summary - \(tollTransactions.count) transactions"
                        )
                        dataManager.shifts[shiftIndex].imageAttachments.append(attachment)
                        imagesGenerated += 1
                        debugMessage("Attached toll summary image to shift, total attachments: \(dataManager.shifts[shiftIndex].imageAttachments.count)")
                    } catch {
                        debugMessage("Failed to save toll summary image for shift: \(error)")
                    }
                } else {
                    debugMessage("Failed to generate toll summary image")
                }

                // Add the updated shift to results AFTER all modifications are complete
                let shift = dataManager.shifts[shiftIndex]
                updatedShifts.append(shift)
            }

            // Trigger data manager update
            dataManager.objectWillChange.send()

            debugMessage("Toll import completed: Updated \(updatedShifts.count) shifts, generated \(imagesGenerated) images")
            return TollImportResult(
                transactions: transactions,
                updatedShifts: updatedShifts,
                imagesGenerated: imagesGenerated
            )
        }
    }

    /// Import expenses from CSV file
    static func importExpenses(from url: URL) -> Result<ExpenseImportResult, CSVImportError> {
        debugMessage("Starting expense CSV import from: \(url.lastPathComponent)")

        return secureFileAccess(url: url) { url in
            let csvContent = try String(contentsOf: url, encoding: .utf8)
            let lines = csvContent.components(separatedBy: .newlines).filter { !$0.isEmpty }

            guard lines.count > 1 else {
                throw CSVImportError.noDataRows
            }

            let headers = parseCSVLine(lines[0])
            var expenses: [ExpenseItem] = []
            let dateFormatter = DateFormatter()

            for i in 1..<lines.count {
                let values = parseCSVLine(lines[i])
                guard values.count >= headers.count else { continue }

                var date: Date?
                var category: ExpenseCategory?
                var description: String = ""
                var amount: Double = 0

                for (index, header) in headers.enumerated() {
                    guard index < values.count else { continue }
                    let value = values[index].trimmingCharacters(in: .whitespaces)

                    switch header.lowercased() {
                    case "date":
                        date = parseDateFromCSV(value, formatter: dateFormatter)
                    case "category":
                        category = ExpenseCategory(rawValue: value)
                    case "description":
                        description = value
                    case "amount":
                        amount = Double(value.replacingOccurrences(of: "$", with: "")) ?? 0
                    default:
                        break
                    }
                }

                if let date = date, let category = category, !description.isEmpty {
                    let expense = ExpenseItem(date: date, category: category, description: description, amount: amount)
                    expenses.append(expense)
                }
            }

            debugMessage("Expense CSV import completed: \(expenses.count) expenses created")
            return ExpenseImportResult(expenses: expenses)
        }
    }

    // MARK: - CSV Parsing Utilities

    /// Parse a CSV line into individual field values, handling Excel formulas and complex quoting
    static func parseCSVLine(_ line: String) -> [String] {
        // Handle toll authority CSV exports with Excel formulas
        // Use a regex-based approach tailored to this specific format

        // First, handle the special Excel formula pattern by temporarily replacing it
        var processedLine = line

        // Pattern: "=Text(""DATE"","""FORMAT")"
        let excelFormulaPattern = #""=Text\(""([^"]+)"","""[^"]+"\)"#

        if let regex = try? NSRegularExpression(pattern: excelFormulaPattern, options: []) {
            let range = NSRange(location: 0, length: processedLine.utf16.count)
            let matches = regex.matches(in: processedLine, options: [], range: range)

            // Replace Excel formulas with just the date value
            for match in matches.reversed() { // Process in reverse to maintain indices
                if let matchRange = Range(match.range, in: processedLine),
                   let captureRange = Range(match.range(at: 1), in: processedLine) {
                    let dateValue = String(processedLine[captureRange])
                    processedLine.replaceSubrange(matchRange, with: "\"\(dateValue)\"")
                }
            }
        }

        // Now parse the simplified CSV line
        var result: [String] = []
        var currentField = ""
        var inQuotes = false
        var i = processedLine.startIndex

        while i < processedLine.endIndex {
            let char = processedLine[i]

            if char == "\"" {
                if inQuotes && i < processedLine.index(before: processedLine.endIndex) && processedLine[processedLine.index(after: i)] == "\"" {
                    // Escaped quote
                    currentField += "\""
                    i = processedLine.index(after: i)
                } else {
                    inQuotes.toggle()
                }
            } else if char == "," && !inQuotes {
                result.append(currentField)
                currentField = ""
            } else {
                currentField += String(char)
            }

            i = processedLine.index(after: i)
        }

        result.append(currentField)
        return result
    }

    /// Parse date from CSV value with multiple format support
    static func parseDateFromCSV(_ dateString: String, formatter: DateFormatter) -> Date? {
        debugMessage("Attempting to parse date: '\(dateString)'")

        // Try common date formats, including two-digit years
        let formats = [
            "M/d/yy", "MM/dd/yy", "d/M/yy", "dd/MM/yy",  // Two-digit year formats (most common)
            "M/d/yyyy", "MM/dd/yyyy", "d/M/yyyy", "dd/MM/yyyy",  // Four-digit year formats
            "yyyy-MM-dd", "MMM d, yyyy", "dd-MM-yyyy", "yyyy/MM/dd"  // Other common formats
        ]

        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: dateString) {
                debugMessage("Date '\(dateString)' parsed successfully with format '\(format)' -> \(date)")
                return date
            }
        }
        debugMessage("Failed to parse date '\(dateString)' with any known format")
        return nil
    }

    /// Parse time from CSV value with multiple format support
    static func parseTimeFromCSV(_ timeString: String, formatter: DateFormatter) -> Date? {
        debugMessage("Attempting to parse time: '\(timeString)'")

        // Try common time formats
        let formats = ["h:mm a", "HH:mm", "h:mm:ss a", "HH:mm:ss"]

        for format in formats {
            formatter.dateFormat = format
            if let time = formatter.date(from: timeString) {
                debugMessage("Time '\(timeString)' parsed successfully with format '\(format)' -> \(time)")
                return time
            }
        }
        debugMessage("Failed to parse time '\(timeString)' with any known format")
        return nil
    }

    // MARK: - Private Helper Methods

    /// Parse a shift from CSV row data
    private static func parseShiftFromCSVRow(headers: [String], values: [String], rowIndex: Int, dateFormatter: DateFormatter, timeFormatter: DateFormatter) -> RideshareShift? {
        let defaultGasPrice = AppPreferences.shared.gasPrice
        let defaultMileageRate = AppPreferences.shared.standardMileageRate

        var shift = RideshareShift(
            startDate: Date(),
            startMileage: 0,
            startTankReading: 0,
            hasFullTankAtStart: false,
            gasPrice: defaultGasPrice,
            standardMileageRate: defaultMileageRate
        )

        // Define which columns to import (data entry fields only, preferences are optional)
        let dataFieldsToImport: Set<String> = [
            "StartDate", "StartTime", "EndDate", "EndTime",
            "StartMileage", "EndMileage",
            "StartTankReading", "EndTankReading", "HasFullTankAtStart", "DidRefuelAtEnd",
            "RefuelGallons", "RefuelCost",
            "TotalTrips", "Trips", "NetFare", "Tips", "Promotions", "RiderFees",
            "TotalTolls", "Tolls", "TollsReimbursed", "ParkingFees", "MiscFees",
            "GasPrice", "StandardMileageRate"
        ]

        // Map CSV values to shift properties (only import known data fields)
        var processedFields = 0
        for (index, header) in headers.enumerated() {
            guard index < values.count else { continue }
            let value = values[index].trimmingCharacters(in: .whitespaces)

            // Only process known data fields
            if dataFieldsToImport.contains(header) {
                processedFields += 1
                parseShiftField(shift: &shift, header: header, value: value, rowIndex: rowIndex, dateFormatter: dateFormatter, timeFormatter: timeFormatter)
            } else {
                debugMessage("Row \(rowIndex): Skipping unknown field '\(header)' = '\(value)'")
            }
        }

        debugMessage("Row \(rowIndex): Processed \(processedFields) known fields, creating shift")
        return shift
    }

    /// Parse individual shift field
    private static func parseShiftField(shift: inout RideshareShift, header: String, value: String, rowIndex: Int, dateFormatter: DateFormatter, timeFormatter: DateFormatter) {
        switch header {
        case "StartDate":
            if let date = parseDateFromCSV(value, formatter: dateFormatter) {
                debugMessage("Row \(rowIndex): StartDate parsed '\(value)' -> \(date)")
                // We'll combine with start time later
                let calendar = Calendar.current
                let components = calendar.dateComponents([.year, .month, .day], from: date)
                if let baseDate = calendar.date(from: components) {
                    shift.startDate = baseDate
                }
            } else {
                debugMessage("WARNING Row \(rowIndex): Failed to parse StartDate '\(value)'")
            }
        case "StartTime":
            if let time = parseTimeFromCSV(value, formatter: timeFormatter) {
                debugMessage("Row \(rowIndex): StartTime parsed '\(value)' -> \(time)")
                let calendar = Calendar.current
                let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
                let dateComponents = calendar.dateComponents([.year, .month, .day], from: shift.startDate)
                var fullComponents = DateComponents()
                fullComponents.year = dateComponents.year
                fullComponents.month = dateComponents.month
                fullComponents.day = dateComponents.day
                fullComponents.hour = timeComponents.hour
                fullComponents.minute = timeComponents.minute
                if let fullDate = calendar.date(from: fullComponents) {
                    shift.startDate = fullDate
                    debugMessage("Row \(rowIndex): Combined StartDate+Time -> \(fullDate)")
                }
            } else {
                debugMessage("WARNING Row \(rowIndex): Failed to parse StartTime '\(value)'")
            }
        case "EndDate":
            if !value.isEmpty, let date = parseDateFromCSV(value, formatter: dateFormatter) {
                let calendar = Calendar.current
                let components = calendar.dateComponents([.year, .month, .day], from: date)
                if let baseDate = calendar.date(from: components) {
                    shift.endDate = baseDate
                }
            }
        case "EndTime":
            if !value.isEmpty, let time = parseTimeFromCSV(value, formatter: timeFormatter), let endDate = shift.endDate {
                let calendar = Calendar.current
                let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
                let dateComponents = calendar.dateComponents([.year, .month, .day], from: endDate)
                var fullComponents = DateComponents()
                fullComponents.year = dateComponents.year
                fullComponents.month = dateComponents.month
                fullComponents.day = dateComponents.day
                fullComponents.hour = timeComponents.hour
                fullComponents.minute = timeComponents.minute
                if let fullDate = calendar.date(from: fullComponents) {
                    shift.endDate = fullDate
                }
            }
        case "StartMileage":
            shift.startMileage = Double(value) ?? 0
        case "EndMileage":
            if !value.isEmpty {
                shift.endMileage = Double(value)
            }
        case "StartTankReading":
            let tankLevel = AppPreferences.shared.tankLevelFromString(value)
            shift.startTankReading = tankLevel
            debugMessage("Row \(rowIndex): StartTankReading '\(value)' -> \(tankLevel)/8")
        case "EndTankReading":
            if !value.isEmpty {
                let tankLevel = AppPreferences.shared.tankLevelFromString(value)
                shift.endTankReading = tankLevel
                debugMessage("Row \(rowIndex): EndTankReading '\(value)' -> \(tankLevel)/8")
            }
        case "HasFullTankAtStart":
            shift.hasFullTankAtStart = value.uppercased() == "YES" || value == "1" || value.uppercased() == "TRUE"
        case "DidRefuelAtEnd":
            if !value.isEmpty {
                shift.didRefuelAtEnd = value.uppercased() == "YES" || value == "1" || value.uppercased() == "TRUE"
            }
        case "RefuelGallons":
            if !value.isEmpty {
                shift.refuelGallons = Double(value)
            }
        case "RefuelCost":
            if !value.isEmpty {
                shift.refuelCost = Double(value)
            }
        case "TotalTrips", "Trips":
            if !value.isEmpty {
                shift.trips = Int(value)
            }
        case "NetFare":
            if !value.isEmpty {
                shift.netFare = Double(value)
            }
        case "Tips":
            if !value.isEmpty {
                shift.tips = Double(value)
            }
        case "Promotions":
            if !value.isEmpty {
                shift.promotions = Double(value)
            }
        case "TotalTolls", "Tolls":
            if !value.isEmpty {
                shift.tolls = Double(value)
            }
        case "TollsReimbursed":
            if !value.isEmpty {
                shift.tollsReimbursed = Double(value)
            }
        case "ParkingFees":
            if !value.isEmpty {
                shift.parkingFees = Double(value)
            }
        case "MiscFees":
            if !value.isEmpty {
                shift.miscFees = Double(value)
            }
        case "GasPrice":
            if !value.isEmpty {
                let defaultGasPrice = AppPreferences.shared.gasPrice
                shift.gasPrice = Double(value) ?? defaultGasPrice
            }
        case "StandardMileageRate":
            if !value.isEmpty {
                let defaultRate = AppPreferences.shared.standardMileageRate
                shift.standardMileageRate = Double(value) ?? defaultRate
            }
        default:
            break
        }
    }
}