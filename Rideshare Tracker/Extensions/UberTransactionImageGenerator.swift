//
//  UberTransactionImageGenerator.swift
//  Rideshare Tracker
//
//  Created by Claude AI on 11/14/25.
//

import UIKit

/// Generates detailed transaction list images for shifts
class UberTransactionImageGenerator {

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
