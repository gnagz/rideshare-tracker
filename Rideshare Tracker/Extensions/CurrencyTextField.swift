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
    
    var body: some View {
        TextField(placeholder, text: $textValue)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .focused($isFocused)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    if isFocused {
                        HStack(spacing: 8) {
                            // Primary math operators
                            Button("+") { insertOperator("+") }
                                .foregroundColor(.blue)
                                .font(.system(size: 16, weight: .semibold))
                            
                            Button("−") { insertOperator("-") }
                                .foregroundColor(.blue)
                                .font(.system(size: 16, weight: .semibold))
                            
                            Button("×") { insertOperator("*") }
                                .foregroundColor(.blue)
                                .font(.system(size: 16, weight: .semibold))
                            
                            Button("÷") { insertOperator("/") }
                                .foregroundColor(.blue)
                                .font(.system(size: 16, weight: .semibold))
                            
                            Button("(") { insertOperator("(") }
                                .foregroundColor(.blue)
                                .font(.system(size: 16, weight: .semibold))
                            
                            Button(")") { insertOperator(")") }
                                .foregroundColor(.blue)
                                .font(.system(size: 16, weight: .semibold))
                            
                            Button("=") {
                                debugPrint("Equals button tapped, calculating expression")
                                updateValueFromText()
                                let notificationFeedback = UINotificationFeedbackGenerator()
                                notificationFeedback.notificationOccurred(.success)
                            }
                            .foregroundColor(.green)
                            .font(.system(size: 16, weight: .bold))
                            
                            Spacer()
                            
                            Button("Done") {
                                isFocused = false
                            }
                            .foregroundColor(.primary)
                            .font(.system(size: 16, weight: .medium))
                        }
                    } else {
                        EmptyView()
                    }
                }
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
        
        // Check if the text contains mathematical expressions
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
    
    private func insertOperator(_ operatorString: String) {
        debugPrint("Inserting operator: '\(operatorString)' into currency field")
        textValue += operatorString
        
        // Provide haptic feedback for button press
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
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
