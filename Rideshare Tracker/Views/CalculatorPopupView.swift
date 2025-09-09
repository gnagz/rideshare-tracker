//
//  CalculatorPopupView.swift
//  Rideshare Tracker
//
//  Created by George Knaggs with Claude AI assistance on 9/8/25.
//

import SwiftUI

struct CalculatorPopupView: View {
    @Binding var isPresented: Bool
    @Binding var resultValue: Double
    let initialValue: Double
    let decimalPlaces: Int
    
    @State private var displayValue: String = "0"
    @State private var previousValue: Double = 0
    @State private var operation: String = ""
    @State private var waitingForOperand: Bool = false
    @State private var memoryValue: Double = 0
    @State private var calculationTape: [CalculationStep] = []
    
    struct CalculationStep: Identifiable {
        let id = UUID()
        let expression: String
        let result: Double
    }
    
    private let buttonSize: CGFloat = 60
    private let spacing: CGFloat = 12
    
    init(isPresented: Binding<Bool>, resultValue: Binding<Double>, decimalPlaces: Int = 2) {
        self._isPresented = isPresented
        self._resultValue = resultValue
        self.initialValue = resultValue.wrappedValue
        self.decimalPlaces = decimalPlaces
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Calculation Tape (Scrollable History)
                calculationTapeView
                
                // Current Display
                currentDisplayView
                
                // Memory and Action Bar
                memoryActionBar
                
                // Calculator Grid
                calculatorGrid
                
                Spacer()
            }
            .padding()
            .navigationTitle("Calculator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        useResult()
                    }
                }
            }
        }
        .onAppear {
            if initialValue > 0 {
                displayValue = formatNumber(initialValue)
            }
        }
    }
    
    private var calculationTapeView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .trailing, spacing: 4) {
                    ForEach(calculationTape) { step in
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(step.expression)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("= \(formatNumber(step.result))")
                                .font(.caption2)
                                .fontWeight(.medium)
                        }
                        .id(step.id)
                    }
                }
                .padding(.horizontal)
            }
            .frame(height: 80)
            .background(Color(.systemGray6))
            .cornerRadius(8)
            .onChange(of: calculationTape.count) { _ in
                if let lastStep = calculationTape.last {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(lastStep.id, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    private var currentDisplayView: some View {
        HStack {
            Spacer()
            Text(displayValue)
                .font(.system(size: 32, weight: .light, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }
    
    private var memoryActionBar: some View {
        HStack(spacing: spacing) {
            // Memory functions
            Button("M+") { memoryAdd() }
                .buttonStyle(MemoryButtonStyle())
            
            Button("M-") { memorySubtract() }
                .buttonStyle(MemoryButtonStyle())
            
            Button("MR") { memoryRecall() }
                .buttonStyle(MemoryButtonStyle())
            
            Button("MC") { memoryClear() }
                .buttonStyle(MemoryButtonStyle())
            
            Spacer()
            
            // Action buttons
            Button(action: deleteLastDigit) {
                Image(systemName: "delete.left")
                    .font(.system(size: 20))
            }
            .buttonStyle(ActionButtonStyle())
            
            Button("AC") { allClear() }
                .buttonStyle(ActionButtonStyle())
        }
    }
    
    private var calculatorGrid: some View {
        VStack(spacing: spacing) {
            // Row 1: 7 8 9 ÷ (
            HStack(spacing: spacing) {
                numberButton("7")
                numberButton("8")
                numberButton("9")
operatorButton("÷", "÷")
                Button("(") { insertOperator("(") }
                    .buttonStyle(SpecialButtonStyle())
            }
            
            // Row 2: 4 5 6 × )
            HStack(spacing: spacing) {
                numberButton("4")
                numberButton("5")
                numberButton("6")
                operatorButton("×", "*")
                Button(")") { insertOperator(")") }
                    .buttonStyle(SpecialButtonStyle())
            }
            
            // Row 3: 1 2 3 - %
            HStack(spacing: spacing) {
                numberButton("1")
                numberButton("2")
                numberButton("3")
                operatorButton("−", "-")
                Button("%") { applyPercentage() }
                    .buttonStyle(SpecialButtonStyle())
            }
            
            // Row 4: 0 . = + +/-
            HStack(spacing: spacing) {
                numberButton("0")
                Button(".") { addDecimalPoint() }
                    .buttonStyle(NumberButtonStyle())
                Button("=") { calculateResult() }
                    .buttonStyle(EqualsButtonStyle())
                operatorButton("+", "+")
                Button(action: { toggleSign() }) {
                    Image(systemName: "plus.forwardslash.minus")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.white)
                }
                .buttonStyle(SpecialButtonStyle())
            }
        }
    }
    
    private func numberButton(_ number: String) -> some View {
        Button(number) { addDigit(number) }
            .buttonStyle(NumberButtonStyle())
    }
    
    private func operatorButton(_ display: String, _ op: String) -> some View {
        Button(display) { setOperation(op) }
            .buttonStyle(OperatorButtonStyle())
    }
    
    // MARK: - Calculator Logic
    
    private func addDigit(_ digit: String) {
        if displayValue == "0" {
            displayValue = digit
        } else {
            displayValue += digit
        }
        waitingForOperand = false
    }
    
    private func addDecimalPoint() {
        if displayValue == "0" {
            displayValue = "0."
        } else {
            // Check if we need a decimal point (look at the last number in the expression)
            let components = displayValue.components(separatedBy: CharacterSet(charactersIn: "+-*/()"))
            if let lastComponent = components.last, !lastComponent.isEmpty && !lastComponent.contains(".") {
                displayValue += "."
            } else if displayValue.last?.isOperator == true || displayValue.last == "(" {
                // If last character is an operator or opening parenthesis, add "0."
                displayValue += "0."
            }
        }
        waitingForOperand = false
    }
    
    private func setOperation(_ op: String) {
        // iPhone calculator style - append operator, but replace if last character is already an operator
        if !displayValue.isEmpty && displayValue != "0" {
            let lastChar = displayValue.last
            // Only replace operators, not parentheses
            if lastChar == "+" || lastChar == "-" || lastChar == "*" || lastChar == "/" {
                // Replace the last operator with the new one
                displayValue = String(displayValue.dropLast()) + op
            } else {
                displayValue += op
            }
        }
        waitingForOperand = false
    }
    
    private func calculateResult() {
        let expression = displayValue
        
        debugPrint("calculateResult called with expression: '\(expression)'")
        debugPrint("containsMathExpression: \(expression.containsMathExpression)")
        
        // Check if it's just a number (no math operators)
        if !expression.containsMathExpression {
            // Just a number, no calculation needed - do nothing on equals
            debugPrint("No math expression detected, returning early")
            return
        }
        
        // Try to evaluate mathematical expression
        if let result = expression.evaluateAsMath(), result.isFinite {
            calculationTape.append(CalculationStep(expression: expression, result: result))
            displayValue = formatNumber(result)
            debugPrint("Calculation successful, result: \(result)")
        } else {
            displayValue = "Error"
            debugPrint("Calculation failed, showing Error")
        }
        
        operation = ""
        waitingForOperand = true
    }
    
    private func allClear() {
        displayValue = "0"
        previousValue = 0
        operation = ""
        waitingForOperand = false
        // Don't clear the calculation tape - let it persist
    }
    
    private func deleteLastDigit() {
        if displayValue.count > 1 {
            displayValue.removeLast()
        } else {
            displayValue = "0"
        }
    }
    
    private func memoryAdd() {
        let valueToAdd = getEvaluatedValue()
        memoryValue += valueToAdd
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func memorySubtract() {
        let valueToSubtract = getEvaluatedValue()
        memoryValue -= valueToSubtract
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func getEvaluatedValue() -> Double {
        // Try to evaluate the expression, fall back to direct conversion
        if let result = displayValue.evaluateAsMath(), result.isFinite {
            return result
        } else if let directValue = Double(displayValue) {
            return directValue
        } else {
            return 0
        }
    }
    
    private func memoryRecall() {
        if displayValue == "0" {
            displayValue = formatNumber(memoryValue)
        } else {
            displayValue += formatNumber(memoryValue)
        }
        waitingForOperand = false
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func memoryClear() {
        memoryValue = 0
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func applyPercentage() {
        // Apply percentage to the last number in the expression
        let operators = CharacterSet(charactersIn: "+-*/()")
        let components = displayValue.components(separatedBy: operators)
        
        if let lastComponent = components.last, let lastValue = Double(lastComponent.trimmingCharacters(in: .whitespaces)) {
            let percentValue = formatNumber(lastValue / 100)
            let rangeToReplace = displayValue.range(of: lastComponent, options: .backwards)!
            displayValue.replaceSubrange(rangeToReplace, with: percentValue)
        }
        
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func toggleSign() {
        // Toggle sign of the last number in the expression
        let operators = CharacterSet(charactersIn: "+-*/()")
        let components = displayValue.components(separatedBy: operators)
        
        if let lastComponent = components.last, let lastValue = Double(lastComponent.trimmingCharacters(in: .whitespaces)) {
            let negatedValue = formatNumber(-lastValue)
            let rangeToReplace = displayValue.range(of: lastComponent, options: .backwards)!
            displayValue.replaceSubrange(rangeToReplace, with: negatedValue)
        }
        
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func insertOperator(_ operatorString: String) {
        if operatorString == "(" {
            insertOpenParenthesis()
        } else if operatorString == ")" {
            insertCloseParenthesis()
        } else {
            if displayValue == "0" {
                displayValue = "("
            } else {
                displayValue += operatorString
            }
        }
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func insertOpenParenthesis() {
        let lastChar = displayValue.last
        
        // Allow ( at start, after operators, or after (
        if displayValue == "0" ||
           lastChar == "+" || lastChar == "-" || lastChar == "*" || lastChar == "/" || lastChar == "(" {
            if displayValue == "0" {
                displayValue = "("
            } else {
                displayValue += "("
            }
        }
        // After a number, auto-insert multiplication: 5( becomes 5*(
        else if lastChar?.isNumber == true || lastChar == "." {
            displayValue += "*("
        }
    }
    
    private func insertCloseParenthesis() {
        let lastChar = displayValue.last
        let openCount = displayValue.filter { $0 == "(" }.count
        let closeCount = displayValue.filter { $0 == ")" }.count
        
        // Only allow ) if there are unmatched open parentheses and last char is number, ., or )
        if openCount > closeCount && 
           (lastChar?.isNumber == true || lastChar == "." || lastChar == ")") {
            displayValue += ")"
        }
    }
    
    
    private func useResult() {
        let finalValue = Double(displayValue) ?? 0
        resultValue = finalValue >= 0 ? finalValue : 0
        isPresented = false
    }
    
    private func formatNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        // Show more precision during calculations, final rounding happens on Done
        formatter.maximumFractionDigits = max(decimalPlaces, 6)
        formatter.minimumFractionDigits = 0
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false  // No thousand separators in calculator
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }
}

// MARK: - Button Styles

struct NumberButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 24, weight: .medium))
            .foregroundColor(.primary)
            .frame(width: 60, height: 60)
            .background(Color(.systemGray5))
            .cornerRadius(30)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct OperatorButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 24, weight: .medium))
            .foregroundColor(.white)
            .frame(width: 60, height: 60)
            .background(Color.accentColor)
            .cornerRadius(30)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct EqualsButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 24, weight: .bold))
            .foregroundColor(.white)
            .frame(width: 60, height: 60)
            .background(Color.green)
            .cornerRadius(30)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct MemoryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.accentColor)
            .frame(width: 40, height: 30)
            .background(Color(.systemGray6))
            .cornerRadius(6)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct ActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(.red)
            .frame(width: 40, height: 30)
            .background(Color(.systemGray6))
            .cornerRadius(6)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SpecialButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 20, weight: .medium))
            .foregroundColor(.white)
            .frame(width: 60, height: 60)
            .background(Color.purple)
            .cornerRadius(30)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Character Extension

extension Character {
    var isOperator: Bool {
        return self == "+" || self == "-" || self == "*" || self == "/" || self == "÷" || self == "×"
    }
}

#Preview {
    CalculatorPopupView(isPresented: .constant(true), resultValue: .constant(123.45), decimalPlaces: 2)
}