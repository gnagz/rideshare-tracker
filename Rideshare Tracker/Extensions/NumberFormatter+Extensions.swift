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

// MARK: - Currency TextField Component

/// A TextField that handles currency input without real-time formatting interference
/// Formats only when the user finishes editing for a better UX
struct CurrencyTextField: View {
    let placeholder: String
    @Binding var value: Double
    @State private var textValue: String = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        TextField(placeholder, text: $textValue)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .focused($isFocused)
            .onAppear {
                updateTextFromValue()
            }
            .onSubmit {
                updateValueFromText()
            }
            .onChange(of: isFocused) { _ in
                if !isFocused {
                    updateValueFromText()
                }
            }
            .onChange(of: value) { _ in
                if !isFocused {
                    updateTextFromValue()
                }
            }
    }
    
    private func updateTextFromValue() {
        if value > 0 {
            textValue = NumberFormatter.currency.string(from: NSNumber(value: value)) ?? ""
        } else {
            textValue = ""
        }
    }
    
    private func updateValueFromText() {
        // Remove currency symbols and parse the number
        let cleanText = textValue
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        if cleanText.isEmpty {
            value = 0.0
        } else if let newValue = Double(cleanText), newValue >= 0 {
            value = newValue
        }
        // Don't revert on invalid input - let user continue typing
    }
}

/// Overload for optional Double binding
extension CurrencyTextField {
    init(placeholder: String, value: Binding<Double?>) {
        self.placeholder = placeholder
        self._value = Binding(
            get: { value.wrappedValue ?? 0.0 },
            set: { newValue in
                value.wrappedValue = newValue > 0 ? newValue : nil
            }
        )
    }
}