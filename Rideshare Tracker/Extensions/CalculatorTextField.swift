//
//  CalculatorTextField.swift
//  Rideshare Tracker
//
//  Created by George Knaggs with Claude AI assistance on 9/7/25.
//

import SwiftUI

/// A TextField that handles numeric input with calculator functionality
/// Uses calculator popup for complex calculations
struct CalculatorTextField: View {
    let placeholder: String
    @Binding var value: Double
    let formatter: NumberFormatter
    let keyboardType: UIKeyboardType
    
    @State private var textValue: String = ""
    @FocusState private var isFocused: Bool
    @State private var showingCalculator = false
    
    init(placeholder: String, value: Binding<Double>, formatter: NumberFormatter = .mileage, keyboardType: UIKeyboardType = .decimalPad) {
        self.placeholder = placeholder
        self._value = value
        self.formatter = formatter
        self.keyboardType = keyboardType
    }
    
    var body: some View {
        HStack(spacing: 4) {
            TextField(placeholder, text: $textValue)
                .keyboardType(keyboardType)
                .multilineTextAlignment(.trailing)
                .focused($isFocused)
            
            Button(action: {
                // Parse current text value to clean number before opening calculator
                let cleanText = textValue
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
            CalculatorPopupView(isPresented: $showingCalculator, resultValue: $value, decimalPlaces: formatter == .mileageInteger ? 0 : 1)
        }
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
            textValue = formatter.string(from: NSNumber(value: value)) ?? String(value)
        } else {
            textValue = ""
        }
    }
    
    private func updateValueFromText() {
        let cleanText = textValue
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        debugPrint("CalculatorTextField processing input: '\(cleanText)'")
        
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
                
                // Update text field with calculated result formatted
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
    }
}

/// Overload for optional Double binding
extension CalculatorTextField {
    init(placeholder: String, value: Binding<Double?>, formatter: NumberFormatter = .mileage, keyboardType: UIKeyboardType = .decimalPad) {
        self.placeholder = placeholder
        self.formatter = formatter
        self.keyboardType = keyboardType
        self._value = Binding(
            get: { value.wrappedValue ?? 0.0 },
            set: { newValue in
                value.wrappedValue = newValue > 0 ? newValue : nil
            }
        )
    }
}

/// Overload for integer values (like trip counts)
extension CalculatorTextField {
    init(placeholder: String, intValue: Binding<Int?>, keyboardType: UIKeyboardType = .numberPad) {
        self.placeholder = placeholder
        self.formatter = .mileageInteger
        self.keyboardType = keyboardType
        self._value = Binding(
            get: { Double(intValue.wrappedValue ?? 0) },
            set: { newValue in
                let intResult = Int(round(newValue))
                intValue.wrappedValue = intResult > 0 ? intResult : nil
            }
        )
    }
}