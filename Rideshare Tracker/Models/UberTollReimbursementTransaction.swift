//
//  UberTollReimbursementTransaction.swift
//  Rideshare Tracker
//
//  Created by Claude AI on 11/8/25.
//

import Foundation

/// Represents a toll reimbursement transaction from Uber weekly statement import
/// Toll reimbursements appear in the "Refunds & Expenses" column of statements
struct UberTollReimbursementTransaction: Codable, Identifiable, Equatable, Hashable {
    var id: UUID = UUID()
    var transactionDate: Date
    var amount: Double
    var eventType: String  // Original ride type (e.g., "UberX", "UberX Priority", "Share", "Delivery")

    init(id: UUID = UUID(), transactionDate: Date, amount: Double, eventType: String) {
        self.id = id
        self.transactionDate = transactionDate
        self.amount = amount
        self.eventType = eventType
    }
}
