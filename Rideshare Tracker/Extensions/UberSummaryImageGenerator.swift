//
//  UberSummaryImageGenerator.swift
//  Rideshare Tracker
//
//  Created by Claude AI on 11/8/25.
//

import UIKit
import CoreGraphics

/// Generates summary images for Uber weekly statement imports
/// Creates professional table images for tip and toll breakdowns
struct UberSummaryImageGenerator {

    // MARK: - Tip Summary Image

    /// Generate tip breakdown summary image
    /// - Parameters:
    ///   - statementPeriod: Statement period string (e.g., "Oct 13, 2025 - Oct 20, 2025")
    ///   - tipTransactions: Array of tip transactions
    ///   - matchedShifts: Array of shifts that were matched
    ///   - totalAmount: Total tip amount
    /// - Returns: Generated summary image
    static func generateTipSummaryImage(
        statementPeriod: String,
        tipTransactions: [UberTipTransaction],
        matchedShifts: [RideshareShift],
        totalAmount: Double
    ) -> UIImage? {

        let width: CGFloat = 800
        let rowHeight: CGFloat = 40
        let headerHeight: CGFloat = 50
        let footerHeight: CGFloat = 80
        let padding: CGFloat = 20

        let height = headerHeight + CGFloat(tipTransactions.count) * rowHeight + footerHeight + (padding * 2) + 40

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))

        return renderer.image { context in
            let ctx = context.cgContext

            // Background
            ctx.setFillColor(UIColor.systemBackground.cgColor)
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))

            // Title
            let title = "Uber Tips Summary - \(statementPeriod)"

            drawText(
                title,
                in: CGRect(x: padding, y: padding, width: width - 2*padding, height: 30),
                font: .boldSystemFont(ofSize: 24),
                color: .label,
                alignment: .center,
                in: ctx
            )

            let tableY = padding + 40

            // Table header
            let headerRect = CGRect(x: padding, y: tableY, width: width - 2*padding, height: headerHeight)
            ctx.setFillColor(UIColor.systemGray5.cgColor)
            ctx.fill(headerRect)
            ctx.setStrokeColor(UIColor.systemGray3.cgColor)
            ctx.setLineWidth(1)
            ctx.stroke(headerRect)

            // Header columns
            let col1Width = (width - 2*padding) * 0.30  // Date/Time
            let col2Width = (width - 2*padding) * 0.40  // Shift Match Status
            let col3Width = (width - 2*padding) * 0.15  // Type
            let col4Width = (width - 2*padding) * 0.15  // Amount

            drawText("Date/Time", in: CGRect(x: padding, y: tableY + 10, width: col1Width, height: 30),
                    font: .boldSystemFont(ofSize: 14), color: .label, alignment: .center, in: ctx)

            drawText("Shift Match", in: CGRect(x: padding + col1Width, y: tableY + 10, width: col2Width, height: 30),
                    font: .boldSystemFont(ofSize: 14), color: .label, alignment: .center, in: ctx)

            drawText("Type", in: CGRect(x: padding + col1Width + col2Width, y: tableY + 10, width: col3Width, height: 30),
                    font: .boldSystemFont(ofSize: 14), color: .label, alignment: .center, in: ctx)

            drawText("Amount", in: CGRect(x: padding + col1Width + col2Width + col3Width, y: tableY + 10, width: col4Width, height: 30),
                    font: .boldSystemFont(ofSize: 14), color: .label, alignment: .center, in: ctx)

            // Draw vertical lines for header
            ctx.move(to: CGPoint(x: padding + col1Width, y: tableY))
            ctx.addLine(to: CGPoint(x: padding + col1Width, y: tableY + headerHeight))
            ctx.move(to: CGPoint(x: padding + col1Width + col2Width, y: tableY))
            ctx.addLine(to: CGPoint(x: padding + col1Width + col2Width, y: tableY + headerHeight))
            ctx.move(to: CGPoint(x: padding + col1Width + col2Width + col3Width, y: tableY))
            ctx.addLine(to: CGPoint(x: padding + col1Width + col2Width + col3Width, y: tableY + headerHeight))
            ctx.strokePath()

            // Table rows
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "MM/dd h:mm a"

            for (index, tip) in tipTransactions.enumerated() {
                let rowY = tableY + headerHeight + CGFloat(index) * rowHeight
                let rowRect = CGRect(x: padding, y: rowY, width: width - 2*padding, height: rowHeight)

                // Alternate row background
                if index % 2 == 1 {
                    ctx.setFillColor(UIColor.systemGray6.cgColor)
                    ctx.fill(rowRect)
                }

                // Row border
                ctx.setStrokeColor(UIColor.systemGray4.cgColor)
                ctx.setLineWidth(0.5)
                ctx.stroke(rowRect)

                // Row data
                let dateText = timeFormatter.string(from: tip.transactionDate)
                drawText(dateText, in: CGRect(x: padding + 5, y: rowY + 10, width: col1Width - 10, height: 20),
                        font: .systemFont(ofSize: 12), color: .label, alignment: .left, in: ctx)

                // Determine match status
                let matchStatus = tip.isDelayedTip ? "⚠ Delayed Tip" : "✓ Matched"
                let statusColor: UIColor = tip.isDelayedTip ? .systemOrange : .systemGreen
                drawText(matchStatus, in: CGRect(x: padding + col1Width + 5, y: rowY + 10, width: col2Width - 10, height: 20),
                        font: .systemFont(ofSize: 12), color: statusColor, alignment: .left, in: ctx)

                drawText("Tip", in: CGRect(x: padding + col1Width + col2Width + 5, y: rowY + 10, width: col3Width - 10, height: 20),
                        font: .systemFont(ofSize: 12), color: .label, alignment: .center, in: ctx)

                let amountText = String(format: "$%.2f", tip.amount)
                drawText(amountText, in: CGRect(x: padding + col1Width + col2Width + col3Width + 5, y: rowY + 10, width: col4Width - 10, height: 20),
                        font: .systemFont(ofSize: 12), color: .label, alignment: .right, in: ctx)

                // Vertical lines for row
                ctx.move(to: CGPoint(x: padding + col1Width, y: rowY))
                ctx.addLine(to: CGPoint(x: padding + col1Width, y: rowY + rowHeight))
                ctx.move(to: CGPoint(x: padding + col1Width + col2Width, y: rowY))
                ctx.addLine(to: CGPoint(x: padding + col1Width + col2Width, y: rowY + rowHeight))
                ctx.move(to: CGPoint(x: padding + col1Width + col2Width + col3Width, y: rowY))
                ctx.addLine(to: CGPoint(x: padding + col1Width + col2Width + col3Width, y: rowY + rowHeight))
                ctx.strokePath()
            }

            // Footer/Total
            let footerY = tableY + headerHeight + CGFloat(tipTransactions.count) * rowHeight
            let footerRect = CGRect(x: padding, y: footerY, width: width - 2*padding, height: footerHeight)
            ctx.setFillColor(UIColor.systemGreen.withAlphaComponent(0.1).cgColor)
            ctx.fill(footerRect)
            ctx.setStrokeColor(UIColor.systemGreen.cgColor)
            ctx.setLineWidth(2)
            ctx.stroke(footerRect)

            let totalText = "Total Tips: $\(String(format: "%.2f", totalAmount))"
            drawText(totalText, in: CGRect(x: padding, y: footerY + 10, width: width - 2*padding, height: 25),
                    font: .boldSystemFont(ofSize: 18), color: .systemGreen, alignment: .center, in: ctx)

            let matchedCount = tipTransactions.filter { !$0.isDelayedTip }.count
            let delayedCount = tipTransactions.filter { $0.isDelayedTip }.count
            let summaryText = "Matched: \(matchedCount) (\(matchedShifts.count) shifts) | Delayed: \(delayedCount)"
            drawText(summaryText, in: CGRect(x: padding, y: footerY + 40, width: width - 2*padding, height: 20),
                    font: .systemFont(ofSize: 14), color: .secondaryLabel, alignment: .center, in: ctx)
        }
    }

    // MARK: - Toll Reimbursement Summary Image

    /// Generate toll reimbursement breakdown summary image
    /// - Parameters:
    ///   - statementPeriod: Statement period string
    ///   - tollTransactions: Array of toll reimbursement transactions
    ///   - matchedShifts: Array of shifts that were matched
    ///   - totalAmount: Total toll reimbursement amount
    /// - Returns: Generated summary image
    static func generateTollSummaryImage(
        statementPeriod: String,
        tollTransactions: [UberTollReimbursementTransaction],
        matchedShifts: [RideshareShift],
        totalAmount: Double
    ) -> UIImage? {

        let width: CGFloat = 800
        let rowHeight: CGFloat = 40
        let headerHeight: CGFloat = 50
        let footerHeight: CGFloat = 80
        let padding: CGFloat = 20

        let height = headerHeight + CGFloat(tollTransactions.count) * rowHeight + footerHeight + (padding * 2) + 40

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))

        return renderer.image { context in
            let ctx = context.cgContext

            // Background
            ctx.setFillColor(UIColor.systemBackground.cgColor)
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))

            // Title
            let title = "Uber Toll Reimbursements - \(statementPeriod)"

            drawText(
                title,
                in: CGRect(x: padding, y: padding, width: width - 2*padding, height: 30),
                font: .boldSystemFont(ofSize: 24),
                color: .label,
                alignment: .center,
                in: ctx
            )

            let tableY = padding + 40

            // Table header
            let headerRect = CGRect(x: padding, y: tableY, width: width - 2*padding, height: headerHeight)
            ctx.setFillColor(UIColor.systemGray5.cgColor)
            ctx.fill(headerRect)
            ctx.setStrokeColor(UIColor.systemGray3.cgColor)
            ctx.setLineWidth(1)
            ctx.stroke(headerRect)

            // Header columns
            let col1Width = (width - 2*padding) * 0.30  // Date/Time
            let col2Width = (width - 2*padding) * 0.40  // Ride Type
            let col3Width = (width - 2*padding) * 0.15  // Status
            let col4Width = (width - 2*padding) * 0.15  // Amount

            drawText("Date/Time", in: CGRect(x: padding, y: tableY + 10, width: col1Width, height: 30),
                    font: .boldSystemFont(ofSize: 14), color: .label, alignment: .center, in: ctx)

            drawText("Ride Type", in: CGRect(x: padding + col1Width, y: tableY + 10, width: col2Width, height: 30),
                    font: .boldSystemFont(ofSize: 14), color: .label, alignment: .center, in: ctx)

            drawText("Status", in: CGRect(x: padding + col1Width + col2Width, y: tableY + 10, width: col3Width, height: 30),
                    font: .boldSystemFont(ofSize: 14), color: .label, alignment: .center, in: ctx)

            drawText("Amount", in: CGRect(x: padding + col1Width + col2Width + col3Width, y: tableY + 10, width: col4Width, height: 30),
                    font: .boldSystemFont(ofSize: 14), color: .label, alignment: .center, in: ctx)

            // Draw vertical lines for header
            ctx.move(to: CGPoint(x: padding + col1Width, y: tableY))
            ctx.addLine(to: CGPoint(x: padding + col1Width, y: tableY + headerHeight))
            ctx.move(to: CGPoint(x: padding + col1Width + col2Width, y: tableY))
            ctx.addLine(to: CGPoint(x: padding + col1Width + col2Width, y: tableY + headerHeight))
            ctx.move(to: CGPoint(x: padding + col1Width + col2Width + col3Width, y: tableY))
            ctx.addLine(to: CGPoint(x: padding + col1Width + col2Width + col3Width, y: tableY + headerHeight))
            ctx.strokePath()

            // Table rows
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "MM/dd h:mm a"

            for (index, toll) in tollTransactions.enumerated() {
                let rowY = tableY + headerHeight + CGFloat(index) * rowHeight
                let rowRect = CGRect(x: padding, y: rowY, width: width - 2*padding, height: rowHeight)

                // Alternate row background
                if index % 2 == 1 {
                    ctx.setFillColor(UIColor.systemGray6.cgColor)
                    ctx.fill(rowRect)
                }

                // Row border
                ctx.setStrokeColor(UIColor.systemGray4.cgColor)
                ctx.setLineWidth(0.5)
                ctx.stroke(rowRect)

                // Row data
                let dateText = timeFormatter.string(from: toll.transactionDate)
                drawText(dateText, in: CGRect(x: padding + 5, y: rowY + 10, width: col1Width - 10, height: 20),
                        font: .systemFont(ofSize: 12), color: .label, alignment: .left, in: ctx)

                drawText(toll.eventType, in: CGRect(x: padding + col1Width + 5, y: rowY + 10, width: col2Width - 10, height: 20),
                        font: .systemFont(ofSize: 12), color: .label, alignment: .left, in: ctx)

                drawText("✓ Matched", in: CGRect(x: padding + col1Width + col2Width + 5, y: rowY + 10, width: col3Width - 10, height: 20),
                        font: .systemFont(ofSize: 12), color: .systemBlue, alignment: .center, in: ctx)

                let amountText = String(format: "$%.2f", toll.amount)
                drawText(amountText, in: CGRect(x: padding + col1Width + col2Width + col3Width + 5, y: rowY + 10, width: col4Width - 10, height: 20),
                        font: .systemFont(ofSize: 12), color: .label, alignment: .right, in: ctx)

                // Vertical lines for row
                ctx.move(to: CGPoint(x: padding + col1Width, y: rowY))
                ctx.addLine(to: CGPoint(x: padding + col1Width, y: rowY + rowHeight))
                ctx.move(to: CGPoint(x: padding + col1Width + col2Width, y: rowY))
                ctx.addLine(to: CGPoint(x: padding + col1Width + col2Width, y: rowY + rowHeight))
                ctx.move(to: CGPoint(x: padding + col1Width + col2Width + col3Width, y: rowY))
                ctx.addLine(to: CGPoint(x: padding + col1Width + col2Width + col3Width, y: rowY + rowHeight))
                ctx.strokePath()
            }

            // Footer/Total
            let footerY = tableY + headerHeight + CGFloat(tollTransactions.count) * rowHeight
            let footerRect = CGRect(x: padding, y: footerY, width: width - 2*padding, height: footerHeight)
            ctx.setFillColor(UIColor.systemBlue.withAlphaComponent(0.1).cgColor)
            ctx.fill(footerRect)
            ctx.setStrokeColor(UIColor.systemBlue.cgColor)
            ctx.setLineWidth(2)
            ctx.stroke(footerRect)

            let totalText = "Total Toll Reimbursements: $\(String(format: "%.2f", totalAmount))"
            drawText(totalText, in: CGRect(x: padding, y: footerY + 10, width: width - 2*padding, height: 25),
                    font: .boldSystemFont(ofSize: 18), color: .systemBlue, alignment: .center, in: ctx)

            let summaryText = "Matched: \(tollTransactions.count) toll transactions across \(matchedShifts.count) shifts"
            drawText(summaryText, in: CGRect(x: padding, y: footerY + 40, width: width - 2*padding, height: 20),
                    font: .systemFont(ofSize: 14), color: .secondaryLabel, alignment: .center, in: ctx)
        }
    }

    // MARK: - Helper Methods

    private static func drawText(
        _ text: String,
        in rect: CGRect,
        font: UIFont,
        color: UIColor,
        alignment: NSTextAlignment,
        in context: CGContext
    ) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment
        paragraphStyle.lineBreakMode = .byTruncatingTail

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ]

        let attributedString = NSAttributedString(string: text, attributes: attributes)
        attributedString.draw(in: rect)
    }
}
