//
//  TollTransaction.swift
//  Rideshare Tracker
//
//  Created by Claude AI on 9/28/25.
//

import Foundation

/// Represents a toll transaction from imported toll history data
struct TollTransaction {
    let date: Date
    let location: String
    let plate: String
    let amount: Double
}