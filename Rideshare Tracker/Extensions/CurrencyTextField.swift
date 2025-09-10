//
//  CurrencyTextField.swift
//  Rideshare Tracker
//
//  Created by George Knaggs with Claude AI assistance on 9/7/25.
//

import SwiftUI

// MARK: - Currency TextField Component

/// A TextField that handles currency input with calculator functionality
/// Formats only when the user finishes editing for a better UX
struct CurrencyTextField: View {
    let placeholder: String
    @Binding var value: Double
    @State private var textValue: String = ""
    @FocusState private var isFocused: Bool
    @State private var showingCalculator = false
    
    var body: some View {
        HStack(spacing: 4) {
            TextField(placeholder, text: $textValue)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .focused($isFocused)
            
            Button(action: {
                // Parse current text value to clean number before opening calculator
                let cleanText = textValue
                    .replacingOccurrences(of: "$", with: "")
                    .replacingOccurrences(of: ",", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if let cleanValue = Double(cleanText), cleanValue > 0 {
                    value = cleanValue
                }
                showingCalculator = true
                isFocused = false
            }) {
                Image(systemName: "plus.forwardslash.minus")
                    .foregroundColor(.accentColor)
                    .font(.system(size: 14))
            }
            .buttonStyle(PlainButtonStyle())
            .frame(width: 20, height: 20)
        }
        .sheet(isPresented: $showingCalculator) {
            CalculatorPopupView(isPresented: $showingCalculator, resultValue: $value, decimalPlaces: 2)
        }
        .onAppear {
            updateTextFromValue()
        }
        .onSubmit {
            updateValueFromText()
        }
        .onChange(of: isFocused) {
            if !isFocused {
                updateValueFromText()
            }
        }
        .onChange(of: value) {
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
        
        debugPrint("CurrencyTextField processing input: '\(cleanText)'")
        
        if cleanText.isEmpty {
            value = 0.0
            debugPrint("Empty input, setting value to 0.0")
            return
        }
        
        // Check if the text contains mathematical expressions (fallback for Mac users)
        if cleanText.containsMathExpression {
            debugPrint("Math expression detected: '\(cleanText)'")
            if let calculatedValue = cleanText.evaluateAsMath(), calculatedValue >= 0 {
                value = calculatedValue
                debugPrint("Calculator result: \(calculatedValue)")
                
                // Update text field with calculated result formatted as currency
                DispatchQueue.main.async {
                    self.updateTextFromValue()
                }
                return
            } else {
                debugPrint("Mathematical evaluation failed or resulted in negative value")
            }
        }
        
        // Fall back to standard numeric parsing
        if let newValue = Double(cleanText), newValue >= 0 {
            value = newValue
            debugPrint("Standard numeric parsing: \(newValue)")
        } else {
            debugPrint("Failed to parse as number: '\(cleanText)'")
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
