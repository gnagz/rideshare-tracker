//
//  UberTransactionImageGenerator.swift
//  Rideshare Tracker
//
//  Created by Claude AI on 11/14/25.
//

import UIKit
import PDFKit

/// Generates detailed transaction list images and PDFs for shifts
class UberTransactionImageGenerator {

    // MARK: - PDF Generation

    /// Generate comprehensive import report PDF
    /// Groups by statement, then by matched shifts, then orphaned transactions by 4am-4am day
    static func generateImportReport(
        statementResults: [SingleStatementResult],
        updatedShifts: [RideshareShift],
        title: String = "Uber Import Summary"
    ) -> Data? {
        let successfulStatements = statementResults.filter { $0.success }
        guard !successfulStatements.isEmpty else { return nil }

        let transactionManager = UberTransactionManager.shared

        // PDF page settings
        let pageWidth: CGFloat = 612  // US Letter width in points
        let pageHeight: CGFloat = 792 // US Letter height in points
        let margin: CGFloat = 50

        let pdfRenderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))

        let data = pdfRenderer.pdfData { context in
            // Fonts and attributes
            let titleFont = UIFont.boldSystemFont(ofSize: 18)
            let headerFont = UIFont.boldSystemFont(ofSize: 14)
            let subheaderFont = UIFont.boldSystemFont(ofSize: 12)
            let bodyFont = UIFont.systemFont(ofSize: 11)
            let smallFont = UIFont.systemFont(ofSize: 10)

            let titleAttr: [NSAttributedString.Key: Any] = [.font: titleFont, .foregroundColor: UIColor.black]
            let headerAttr: [NSAttributedString.Key: Any] = [.font: headerFont, .foregroundColor: UIColor.black]
            let subheaderAttr: [NSAttributedString.Key: Any] = [.font: subheaderFont, .foregroundColor: UIColor.black]
            let bodyAttr: [NSAttributedString.Key: Any] = [.font: bodyFont, .foregroundColor: UIColor.black]
            let smallAttr: [NSAttributedString.Key: Any] = [.font: smallFont, .foregroundColor: UIColor.darkGray]
            let boldBodyAttr: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 11), .foregroundColor: UIColor.black]

            let lineHeight: CGFloat = 16
            let sectionSpacing: CGFloat = 20
            let maxY = pageHeight - margin - 60

            var y: CGFloat = 0

            func startNewPage() {
                context.beginPage()
                y = margin
            }

            func checkPageBreak(needed: CGFloat) {
                if y + needed > maxY {
                    drawPageFooter()
                    startNewPage()
                }
            }

            func drawPageFooter() {
                let footerY = pageHeight - margin + 10
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "MMM d, yyyy h:mm a"
                let footerText = "Generated \(dateFormatter.string(from: Date()))"
                let footerAttr: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 9), .foregroundColor: UIColor.gray]
                footerText.draw(at: CGPoint(x: margin, y: footerY), withAttributes: footerAttr)
            }

            func drawSeparator() {
                let sepPath = UIBezierPath()
                sepPath.move(to: CGPoint(x: margin, y: y))
                sepPath.addLine(to: CGPoint(x: pageWidth - margin, y: y))
                UIColor.lightGray.setStroke()
                sepPath.lineWidth = 0.5
                sepPath.stroke()
                y += 15
            }

            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "MMM d h:mm a"
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMM d, yyyy"
            let timeOnlyFormatter = DateFormatter()
            timeOnlyFormatter.dateFormat = "h:mm a"

            let col2X = margin + 120
            let col3X = pageWidth - margin - 60

            // Collect all orphaned transactions across all statements
            var allOrphanedTransactions: [UberTransaction] = []

            // Start first page
            startNewPage()

            // Title
            title.draw(at: CGPoint(x: margin, y: y), withAttributes: titleAttr)
            y += 30

            // Summary line
            let totalMatched = successfulStatements.reduce(0) { $0 + $1.matchedCount }
            let totalUnmatched = successfulStatements.reduce(0) { $0 + $1.unmatchedCount }
            let summaryText = "\(successfulStatements.count) file\(successfulStatements.count == 1 ? "" : "s"), \(totalMatched) matched, \(totalUnmatched) unmatched"
            summaryText.draw(at: CGPoint(x: margin, y: y), withAttributes: smallAttr)
            y += sectionSpacing

            drawSeparator()

            // Process each statement
            for statement in successfulStatements.sorted(by: { parseStartDate($0.statementPeriod) < parseStartDate($1.statementPeriod) }) {
                checkPageBreak(needed: 100)

                // Statement header
                "Statement: \(statement.statementPeriod)".draw(at: CGPoint(x: margin, y: y), withAttributes: headerAttr)
                y += 18
                statement.filename.draw(at: CGPoint(x: margin, y: y), withAttributes: smallAttr)
                y += 14
                "\(statement.matchedCount) matched, \(statement.unmatchedCount) unmatched".draw(at: CGPoint(x: margin, y: y), withAttributes: smallAttr)
                y += sectionSpacing

                // Get transactions for this statement period
                let periodTransactions = transactionManager.getTransactions(forStatementPeriod: statement.statementPeriod)
                let matchedTransactions = periodTransactions.filter { $0.shiftID != nil }
                let orphanedTransactions = periodTransactions.filter { $0.shiftID == nil }

                // Add orphans to overall collection
                allOrphanedTransactions.append(contentsOf: orphanedTransactions)

                // Group matched transactions by shift
                let matchedByShift = Dictionary(grouping: matchedTransactions) { $0.shiftID! }

                // Get shifts in chronological order
                let shiftsForStatement = updatedShifts.filter { shift in
                    matchedByShift.keys.contains(shift.id)
                }.sorted { $0.startDate < $1.startDate }

                // Draw matched transactions grouped by shift
                for shift in shiftsForStatement {
                    guard let shiftTransactions = matchedByShift[shift.id] else { continue }
                    let sortedTxs = shiftTransactions.sorted { ($0.eventDate ?? $0.transactionDate) < ($1.eventDate ?? $1.transactionDate) }
                    let shiftTotals = shiftTransactions.totals()

                    checkPageBreak(needed: 60 + CGFloat(sortedTxs.count) * lineHeight)

                    // Shift header
                    let shiftDateStr = dateFormatter.string(from: shift.startDate)
                    let startTimeStr = timeOnlyFormatter.string(from: shift.startDate)
                    let endTimeStr = shift.endDate.map { timeOnlyFormatter.string(from: $0) } ?? "In Progress"
                    "\(shiftDateStr) \(startTimeStr) - \(endTimeStr)".draw(at: CGPoint(x: margin + 10, y: y), withAttributes: subheaderAttr)

                    // Shift totals on same line
                    var totalsStr = ""
                    if shiftTotals.tips > 0 {
                        totalsStr += "Tips: $\(String(format: "%.2f", shiftTotals.tips))"
                    }
                    if shiftTotals.tollsReimbursed > 0 {
                        if !totalsStr.isEmpty { totalsStr += "  " }
                        totalsStr += "Tolls: $\(String(format: "%.2f", shiftTotals.tollsReimbursed))"
                    }
                    if !totalsStr.isEmpty {
                        let totalsWidth = (totalsStr as NSString).size(withAttributes: smallAttr).width
                        totalsStr.draw(at: CGPoint(x: pageWidth - margin - totalsWidth, y: y + 2), withAttributes: smallAttr)
                    }
                    y += 20

                    // Transactions for this shift
                    for tx in sortedTxs {
                        checkPageBreak(needed: lineHeight * 2)

                        let timeStr = timeFormatter.string(from: tx.eventDate ?? tx.transactionDate)
                        let amountStr = String(format: "$%.2f", tx.amount)

                        timeStr.draw(at: CGPoint(x: margin + 20, y: y), withAttributes: bodyAttr)
                        tx.eventType.draw(at: CGPoint(x: col2X, y: y), withAttributes: bodyAttr)
                        amountStr.draw(at: CGPoint(x: col3X, y: y), withAttributes: bodyAttr)
                        y += lineHeight

                        if let toll = tx.tollsReimbursed, toll > 0 {
                            checkPageBreak(needed: lineHeight)
                            "  ↳ Toll Reimb".draw(at: CGPoint(x: col2X, y: y), withAttributes: smallAttr)
                            String(format: "$%.2f", toll).draw(at: CGPoint(x: col3X, y: y), withAttributes: smallAttr)
                            y += lineHeight
                        }
                    }
                    y += 8
                }

                // Statement totals
                let statementTotals = periodTransactions.totals()
                checkPageBreak(needed: 50)
                y += 8
                "\(periodTransactions.count) transactions: \(statement.matchedCount) matched, \(statement.unmatchedCount) unmatched".draw(at: CGPoint(x: margin, y: y), withAttributes: boldBodyAttr)
                y += lineHeight
                "Tips: \(String(format: "$%.2f", statementTotals.tips))  |  Tolls: \(String(format: "$%.2f", statementTotals.tollsReimbursed))".draw(at: CGPoint(x: margin, y: y), withAttributes: smallAttr)
                y += sectionSpacing

                drawSeparator()
            }

            // Overall totals for matched transactions
            let allPeriods = successfulStatements.map { $0.statementPeriod }
            let allTransactions = allPeriods.flatMap { transactionManager.getTransactions(forStatementPeriod: $0) }
            let overallTotals = allTransactions.totals()

            checkPageBreak(needed: 100)
            "OVERALL TOTALS".draw(at: CGPoint(x: margin, y: y), withAttributes: headerAttr)
            y += 22
            "Tips: \(String(format: "$%.2f", overallTotals.tips))".draw(at: CGPoint(x: margin + 10, y: y), withAttributes: bodyAttr)
            y += lineHeight
            "Tolls Reimbursed: \(String(format: "$%.2f", overallTotals.tollsReimbursed))".draw(at: CGPoint(x: margin + 10, y: y), withAttributes: bodyAttr)
            y += lineHeight
            "Total Transactions: \(overallTotals.count)".draw(at: CGPoint(x: margin + 10, y: y), withAttributes: bodyAttr)
            y += sectionSpacing

            drawSeparator()

            // Missing Shifts section - grouped by 4am-4am day
            if !allOrphanedTransactions.isEmpty {
                checkPageBreak(needed: 60)
                "MISSING SHIFTS".draw(at: CGPoint(x: margin, y: y), withAttributes: headerAttr)
                y += 18
                "\(allOrphanedTransactions.count) transaction\(allOrphanedTransactions.count == 1 ? "" : "s") without matching shifts".draw(at: CGPoint(x: margin, y: y), withAttributes: smallAttr)
                y += sectionSpacing

                // Group by 4am-4am day
                let calendar = Calendar.current
                let groupedByDay = Dictionary(grouping: allOrphanedTransactions) { tx -> Date in
                    let eventDate = tx.eventDate ?? tx.transactionDate
                    let components = calendar.dateComponents([.year, .month, .day, .hour], from: eventDate)
                    // If before 4am, count as previous day
                    if let hour = components.hour, hour < 4 {
                        return calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: eventDate))!
                    }
                    return calendar.startOfDay(for: eventDate)
                }

                let sortedDays = groupedByDay.keys.sorted()
                for day in sortedDays {
                    guard let dayTransactions = groupedByDay[day] else { continue }
                    let sortedTxs = dayTransactions.sorted { ($0.eventDate ?? $0.transactionDate) < ($1.eventDate ?? $1.transactionDate) }
                    let dayTotals = dayTransactions.totals()

                    checkPageBreak(needed: 40 + CGFloat(sortedTxs.count) * lineHeight)

                    // Day header
                    let dayStr = dateFormatter.string(from: day)
                    "\(dayStr) (4am-4am)".draw(at: CGPoint(x: margin + 10, y: y), withAttributes: subheaderAttr)

                    // Day totals on same line (like shift totals)
                    var totalsStr = ""
                    if dayTotals.tips > 0 {
                        totalsStr += "Tips: $\(String(format: "%.2f", dayTotals.tips))"
                    }
                    if dayTotals.tollsReimbursed > 0 {
                        if !totalsStr.isEmpty { totalsStr += "  " }
                        totalsStr += "Tolls: $\(String(format: "%.2f", dayTotals.tollsReimbursed))"
                    }
                    if !totalsStr.isEmpty {
                        let totalsWidth = (totalsStr as NSString).size(withAttributes: smallAttr).width
                        totalsStr.draw(at: CGPoint(x: pageWidth - margin - totalsWidth, y: y + 2), withAttributes: smallAttr)
                    }
                    y += 20

                    // Transactions for this day
                    for tx in sortedTxs {
                        checkPageBreak(needed: lineHeight * 2)

                        let timeStr = timeFormatter.string(from: tx.eventDate ?? tx.transactionDate)
                        let amountStr = String(format: "$%.2f", tx.amount)

                        timeStr.draw(at: CGPoint(x: margin + 20, y: y), withAttributes: bodyAttr)
                        tx.eventType.draw(at: CGPoint(x: col2X, y: y), withAttributes: bodyAttr)
                        amountStr.draw(at: CGPoint(x: col3X, y: y), withAttributes: bodyAttr)
                        y += lineHeight

                        if let toll = tx.tollsReimbursed, toll > 0 {
                            checkPageBreak(needed: lineHeight)
                            "  ↳ Toll Reimb".draw(at: CGPoint(x: col2X, y: y), withAttributes: smallAttr)
                            String(format: "$%.2f", toll).draw(at: CGPoint(x: col3X, y: y), withAttributes: smallAttr)
                            y += lineHeight
                        }
                    }
                    y += 8
                }
            }

            drawPageFooter()
        }

        return data
    }

    /// Parse start date from statement period string
    private static func parseStartDate(_ period: String) -> Date {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d, yyyy"
        let parts = period.components(separatedBy: " - ")
        return parts.first.flatMap { dateFormatter.date(from: $0.trimmingCharacters(in: .whitespaces)) } ?? Date.distantFuture
    }

    // MARK: - Image Generation

    /// Generate full transaction list image grouped by statement period
    static func generate(
        transactions: [UberTransaction],
        shift: RideshareShift
    ) -> UIImage? {

        guard !transactions.isEmpty else { return nil }

        // Group by statement period
        let grouped = Dictionary(grouping: transactions) { $0.statementPeriod }
            .sorted { $0.key < $1.key }

        // Calculate overall totals
        let overallTotals = transactions.totals()

        // Calculate required height based on content
        let lineHeight: CGFloat = 22
        let headerSpacing: CGFloat = 30
        let sectionSpacing: CGFloat = 25

        var contentHeight: CGFloat = 180 // Title, shift info, divider, and bottom padding

        for (_, periodTransactions) in grouped {
            contentHeight += headerSpacing // Period header
            contentHeight += CGFloat(periodTransactions.count) * lineHeight // Transaction lines
            contentHeight += 80 // Period totals section
            contentHeight += sectionSpacing // Separator
        }

        contentHeight += 150 // Overall totals section

        let imageHeight = max(contentHeight, 400)
        let imageWidth: CGFloat = 650

        // Render image
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: imageWidth, height: imageHeight))

        return renderer.image { _ in
            // White background
            UIColor.white.setFill()
            UIRectFill(CGRect(x: 0, y: 0, width: imageWidth, height: imageHeight))

            var y: CGFloat = 20

            // Title
            let titleAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 20),
                .foregroundColor: UIColor.black
            ]
            "Uber Transactions".draw(at: CGPoint(x: 20, y: y), withAttributes: titleAttr)
            y += 30

            // Shift date/time
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMM d, yyyy h:mm a"
            let startTime = dateFormatter.string(from: shift.startDate)
            let endTime = shift.endDate.map { dateFormatter.string(from: $0) } ?? "In Progress"
            let shiftTimeText = "Shift: \(startTime) - \(endTime)"

            let shiftAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14),
                .foregroundColor: UIColor.black
            ]
            shiftTimeText.draw(at: CGPoint(x: 20, y: y), withAttributes: shiftAttr)
            y += 30

            // Horizontal line
            let linePath = UIBezierPath()
            linePath.move(to: CGPoint(x: 20, y: y))
            linePath.addLine(to: CGPoint(x: imageWidth - 20, y: y))
            UIColor.black.setStroke()
            linePath.lineWidth = 1
            linePath.stroke()
            y += 20

            // Column positions
            let col1X: CGFloat = 30   // Date/Time
            let col2X: CGFloat = 200  // Type
            let col3X: CGFloat = 450  // Amount

            let rowFont = UIFont.systemFont(ofSize: 13)
            let rowAttr: [NSAttributedString.Key: Any] = [
                .font: rowFont,
                .foregroundColor: UIColor.black
            ]

            let boldRowAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 13),
                .foregroundColor: UIColor.black
            ]

            let smallAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11),
                .foregroundColor: UIColor.darkGray
            ]

            // For each statement period
            for (period, periodTransactions) in grouped {
                // Period header
                let periodHeaderAttr: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 16),
                    .foregroundColor: UIColor.black
                ]
                "Statement Period: \(period)".draw(at: CGPoint(x: 20, y: y), withAttributes: periodHeaderAttr)
                y += headerSpacing

                // List each transaction - one per line
                let sortedTxs = periodTransactions.sorted { $0.transactionDate < $1.transactionDate }

                for tx in sortedTxs {
                    let timeFormatter = DateFormatter()
                    timeFormatter.dateFormat = "MMM d h:mm a"
                    let timeStr = timeFormatter.string(from: tx.eventDate ?? tx.transactionDate)
                    let amountStr = String(format: "$%.2f", tx.amount)

                    // Draw each column on the SAME row
                    timeStr.draw(at: CGPoint(x: col1X, y: y), withAttributes: rowAttr)
                    tx.eventType.draw(at: CGPoint(x: col2X, y: y), withAttributes: rowAttr)
                    amountStr.draw(at: CGPoint(x: col3X, y: y), withAttributes: rowAttr)

                    y += lineHeight

                    // If has toll reimbursement, show on next line indented
                    if let tollReimbursed = tx.tollsReimbursed, tollReimbursed > 0 {
                        let tollAmountStr = String(format: "$%.2f", tollReimbursed)
                        "  ↳ Toll Reimb".draw(at: CGPoint(x: col2X, y: y), withAttributes: smallAttr)
                        tollAmountStr.draw(at: CGPoint(x: col3X, y: y), withAttributes: smallAttr)
                        y += lineHeight
                    }
                }

                // Period totals
                y += 10
                let periodTotals = periodTransactions.totals()

                "Period Total:".draw(at: CGPoint(x: col1X, y: y), withAttributes: boldRowAttr)
                y += 20

                "Tips: \(String(format: "$%.2f", periodTotals.tips))".draw(at: CGPoint(x: 50, y: y), withAttributes: smallAttr)
                y += 16
                "Tolls Reimbursed: \(String(format: "$%.2f", periodTotals.tollsReimbursed))".draw(at: CGPoint(x: 50, y: y), withAttributes: smallAttr)
                y += 16
                "Transactions: \(periodTotals.count)".draw(at: CGPoint(x: 50, y: y), withAttributes: smallAttr)
                y += sectionSpacing

                // Separator line
                let sepPath = UIBezierPath()
                sepPath.move(to: CGPoint(x: 20, y: y))
                sepPath.addLine(to: CGPoint(x: imageWidth - 20, y: y))
                UIColor.lightGray.setStroke()
                sepPath.lineWidth = 0.5
                sepPath.stroke()
                y += 20
            }

            // Overall totals
            let totalHeaderAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 16),
                .foregroundColor: UIColor.black
            ]
            "SHIFT TOTAL".draw(at: CGPoint(x: 20, y: y), withAttributes: totalHeaderAttr)
            y += 25

            let totalAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 13),
                .foregroundColor: UIColor.black
            ]

            "Tips: \(String(format: "$%.2f", overallTotals.tips))".draw(at: CGPoint(x: 30, y: y), withAttributes: totalAttr)
            y += 20
            "Tolls Reimbursed: \(String(format: "$%.2f", overallTotals.tollsReimbursed))".draw(at: CGPoint(x: 30, y: y), withAttributes: totalAttr)
            y += 20
            "Promotions: \(String(format: "$%.2f", overallTotals.promotions))".draw(at: CGPoint(x: 30, y: y), withAttributes: totalAttr)
            y += 20
            "Net Fare: \(String(format: "$%.2f", overallTotals.netFare))".draw(at: CGPoint(x: 30, y: y), withAttributes: totalAttr)
            y += 20
            "Total Transactions: \(overallTotals.count)".draw(at: CGPoint(x: 30, y: y), withAttributes: totalAttr)
        }
    }
}
