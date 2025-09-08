//
//  NumberFormatter+Extensions.swift
//  Rideshare Tracker
//
//  Created by George Knaggs with Claude AI assistance on 8/10/25.
//

import Foundation
import SwiftUI

extension NumberFormatter {
    static let mileage: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1
        formatter.usesGroupingSeparator = true
        formatter.groupingSeparator = ","
        return formatter
    }()
    
    static let mileageInteger: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        formatter.usesGroupingSeparator = true
        formatter.groupingSeparator = ","
        return formatter
    }()
    
    static let currency: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.locale = Locale.current
        return formatter
    }()
    
    static let currencyInput: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.usesGroupingSeparator = false
        return formatter
    }()
}

extension Double {
    var formattedMileage: String {
        return NumberFormatter.mileage.string(from: NSNumber(value: self)) ?? String(format: "%.1f", self)
    }
    
    var formattedMileageInteger: String {
        return NumberFormatter.mileageInteger.string(from: NSNumber(value: self)) ?? String(format: "%.0f", self)
    }
    
    var formattedCurrency: String {
        return NumberFormatter.currency.string(from: NSNumber(value: self)) ?? String(format: "$%.2f", self)
    }
    
    var formattedCurrencyInput: String {
        return NumberFormatter.currencyInput.string(from: NSNumber(value: self)) ?? String(format: "%.2f", self)
    }
}

// MARK: - Currency TextField moved to CurrencyTextField.swift for better organization