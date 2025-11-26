//
//  UberTransaction.swift
//  Rideshare Tracker
//
//  Created by Claude AI on 11/14/25.
//

import Foundation

/// Unified Uber transaction model for all transaction types
struct UberTransaction: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var transactionDate: Date       // When Uber processed the transaction
    var eventDate: Date?            // When the ride/trip actually occurred
    var eventType: String           // "Tip", "UberX", "Quest", etc.
    var amount: Double
    var tollsReimbursed: Double?    // Consistent naming throughout
    var needsManualVerification: Bool = false

    // Import metadata
    var statementPeriod: String     // "Oct 13 - Oct 20, 2025"
    var shiftID: UUID?              // nil = orphaned, waiting for shift
    var importDate: Date
    var sourceRow: Int = 0          // PDF row index for debugging

    init(
        id: UUID = UUID(),
        transactionDate: Date,
        eventDate: Date?,
        eventType: String,
        amount: Double,
        tollsReimbursed: Double? = nil,
        needsManualVerification: Bool = false,
        statementPeriod: String,
        shiftID: UUID? = nil,
        importDate: Date,
        sourceRow: Int = 0
    ) {
        self.id = id
        self.transactionDate = transactionDate
        self.eventDate = eventDate
        self.eventType = eventType
        self.amount = amount
        self.tollsReimbursed = tollsReimbursed
        self.needsManualVerification = needsManualVerification
        self.statementPeriod = statementPeriod
        self.shiftID = shiftID
        self.importDate = importDate
        self.sourceRow = sourceRow
    }
}

// MARK: - Transaction Category

/// Transaction category for aggregation
enum TransactionCategory: Equatable {
    case tip
    case promotion      // Quest, Incentive
    case netFare        // Ride earnings
    case ignore         // Bank transfers
}

// MARK: - Aggregated Totals

/// Aggregated transaction totals
struct TransactionTotals {
    let tips: Double
    let tollsReimbursed: Double
    let promotions: Double
    let netFare: Double
    let count: Int
}

// MARK: - Categorization Function

/// Categorize transaction by event type
func categorize(_ transaction: UberTransaction) -> TransactionCategory {
    let eventType = transaction.eventType

    if eventType == "Tip" {
        return .tip
    } else if eventType == "Quest" || eventType == "Incentive" {
        return .promotion
    } else if eventType.lowercased().contains("transferred to bank") {
        return .ignore
    } else {
        // All ride types: UberX, UberX Priority, Share, Delivery, etc.
        return .netFare
    }
}

// MARK: - Array Aggregation Extension

extension Array where Element == UberTransaction {
    /// Calculate totals for all transactions in array
    func totals() -> TransactionTotals {
        var tips = 0.0
        var tollsReimbursed = 0.0
        var promotions = 0.0
        var netFare = 0.0

        for transaction in self {
            let category = categorize(transaction)

            switch category {
            case .tip:
                tips += transaction.amount
            case .promotion:
                promotions += transaction.amount
            case .netFare:
                netFare += transaction.amount
            case .ignore:
                continue
            }

            // Use tollsReimbursed (not toll) to avoid confusion
            if let tollReimbursed = transaction.tollsReimbursed {
                tollsReimbursed += tollReimbursed
            }
        }

        return TransactionTotals(
            tips: tips,
            tollsReimbursed: tollsReimbursed,
            promotions: promotions,
            netFare: netFare,
            count: self.count
        )
    }

    /// Calculate totals for transactions within date range
    func totals(from startDate: Date, to endDate: Date) -> TransactionTotals {
        let filtered = self.filter {
            $0.transactionDate >= startDate && $0.transactionDate <= endDate
        }
        return filtered.totals()
    }
}
