//
//  TollSummaryImageGenerator.swift
//  Rideshare Tracker
//
//  Created by Claude AI on 9/19/25.
//

import UIKit
import CoreGraphics

struct TollTransaction {
    let date: Date
    let location: String
    let plate: String
    let amount: Double
}

struct TollSummaryImageGenerator {

    static func generateTollSummaryImage(
        shiftDate: Date,
        transactions: [TollTransaction],
        totalAmount: Double
    ) -> UIImage? {

        let width: CGFloat = 800
        let rowHeight: CGFloat = 40
        let headerHeight: CGFloat = 50
        let footerHeight: CGFloat = 60
        let padding: CGFloat = 20

        let height = headerHeight + CGFloat(transactions.count) * rowHeight + footerHeight + (padding * 2)

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))

        return renderer.image { context in
            let ctx = context.cgContext

            // Background
            ctx.setFillColor(UIColor.systemBackground.cgColor)
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))

            // Title
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            let title = "Toll Summary - \(dateFormatter.string(from: shiftDate))"

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
            let col1Width = (width - 2*padding) * 0.25  // Date
            let col2Width = (width - 2*padding) * 0.45  // Location
            let col3Width = (width - 2*padding) * 0.15  // Plate
            let col4Width = (width - 2*padding) * 0.15  // Amount

            drawText("Date/Time", in: CGRect(x: padding, y: tableY + 10, width: col1Width, height: 30),
                    font: .boldSystemFont(ofSize: 14), color: .label, alignment: .center, in: ctx)

            drawText("Location", in: CGRect(x: padding + col1Width, y: tableY + 10, width: col2Width, height: 30),
                    font: .boldSystemFont(ofSize: 14), color: .label, alignment: .center, in: ctx)

            drawText("Plate", in: CGRect(x: padding + col1Width + col2Width, y: tableY + 10, width: col3Width, height: 30),
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
            timeFormatter.dateFormat = "MM/dd HH:mm"

            for (index, transaction) in transactions.enumerated() {
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
                let dateText = timeFormatter.string(from: transaction.date)
                drawText(dateText, in: CGRect(x: padding + 5, y: rowY + 10, width: col1Width - 10, height: 20),
                        font: .systemFont(ofSize: 12), color: .label, alignment: .left, in: ctx)

                let locationText = truncateText(transaction.location, maxLength: 35)
                drawText(locationText, in: CGRect(x: padding + col1Width + 5, y: rowY + 10, width: col2Width - 10, height: 20),
                        font: .systemFont(ofSize: 12), color: .label, alignment: .left, in: ctx)

                drawText(transaction.plate, in: CGRect(x: padding + col1Width + col2Width + 5, y: rowY + 10, width: col3Width - 10, height: 20),
                        font: .systemFont(ofSize: 12), color: .label, alignment: .center, in: ctx)

                let amountText = String(format: "$%.2f", transaction.amount)
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
            let footerY = tableY + headerHeight + CGFloat(transactions.count) * rowHeight
            let footerRect = CGRect(x: padding, y: footerY, width: width - 2*padding, height: footerHeight)
            ctx.setFillColor(UIColor.systemBlue.withAlphaComponent(0.1).cgColor)
            ctx.fill(footerRect)
            ctx.setStrokeColor(UIColor.systemBlue.cgColor)
            ctx.setLineWidth(2)
            ctx.stroke(footerRect)

            let totalText = "Total Tolls: $\(String(format: "%.2f", totalAmount))"
            drawText(totalText, in: CGRect(x: padding, y: footerY + 15, width: width - 2*padding, height: 30),
                    font: .boldSystemFont(ofSize: 18), color: .systemBlue, alignment: .center, in: ctx)
        }
    }

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

    private static func truncateText(_ text: String, maxLength: Int) -> String {
        if text.count <= maxLength {
            return text
        }
        return String(text.prefix(maxLength - 3)) + "..."
    }
}