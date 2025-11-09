//
//  UberTipTransaction.swift
//  Rideshare Tracker
//
//  Created by Claude AI on 11/8/25.
//

import Foundation

/// Represents a single tip transaction from Uber weekly statement import
/// Tips can appear in statements weeks after the original ride occurred (delayed tips)
struct UberTipTransaction: Codable, Identifiable, Equatable, Hashable {
    var id: UUID = UUID()
    var transactionDate: Date
    var amount: Double
    var eventType: String  // "Tip"
    var isDelayedTip: Bool  // True if tip appeared in statement after original ride week

    init(id: UUID = UUID(), transactionDate: Date, amount: Double, eventType: String = "Tip", isDelayedTip: Bool = false) {
        self.id = id
        self.transactionDate = transactionDate
        self.amount = amount
        self.eventType = eventType
        self.isDelayedTip = isDelayedTip
    }
}
