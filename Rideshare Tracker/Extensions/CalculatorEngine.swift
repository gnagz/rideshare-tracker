//
//  CalculatorEngine.swift
//  Rideshare Tracker
//
//  Created by George Knaggs with Claude AI assistance on 9/7/25.
//

import Foundation

/// Mathematical expression evaluator for calculator functionality
/// Provides safe evaluation of mathematical expressions in text fields
class CalculatorEngine {
    static let shared = CalculatorEngine()
    
    private init() {}
    
    /// Evaluates a mathematical expression and returns the result
    /// - Parameter expression: The mathematical expression as a string (e.g., "45+23*2")
    /// - Returns: The calculated result as a Double, or nil if evaluation fails
    func evaluate(_ expression: String) -> Double? {
        debugPrint("Evaluating expression: '\(expression)'")
        
        // Clean and validate the expression
        guard let cleanExpression = sanitizeExpression(expression) else {
            debugPrint("Expression sanitization failed")
            return nil
        }
        
        debugPrint("Sanitized expression: '\(cleanExpression)'")
        
        // Use NSExpression for safe mathematical evaluation
        let nsExpression = NSExpression(format: cleanExpression)
        if let result = nsExpression.expressionValue(with: nil, context: nil) as? NSNumber {
            let doubleResult = result.doubleValue
            debugPrint("Expression evaluated successfully: \(doubleResult)")
            return doubleResult
        } else {
            debugPrint("NSExpression returned non-numeric result")
            return nil
        }
    }
    
    /// Checks if a string contains a mathematical expression
    /// - Parameter text: The input text to check
    /// - Returns: True if the text appears to contain mathematical operations
    func containsMathExpression(_ text: String) -> Bool {
        let mathOperators = CharacterSet(charactersIn: "+-*/()=")
        return text.rangeOfCharacter(from: mathOperators) != nil && text.count > 1
    }
    
    /// Checks if a string looks like a complete mathematical expression
    /// - Parameter text: The input text to validate
    /// - Returns: True if the text appears to be a valid mathematical expression
    func isValidExpression(_ text: String) -> Bool {
        guard containsMathExpression(text) else { return false }
        
        // Basic validation checks
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        
        // Must not be empty after trimming
        guard !trimmed.isEmpty else { return false }
        
        // Must not start or end with operators (except parentheses and minus for negatives)
        let invalidStartEnd = CharacterSet(charactersIn: "+*/")
        if let firstChar = trimmed.first, let lastChar = trimmed.last {
            if invalidStartEnd.contains(Unicode.Scalar(String(firstChar))!) ||
               invalidStartEnd.contains(Unicode.Scalar(String(lastChar))!) {
                return false
            }
        }
        
        // Check for balanced parentheses
        var parenCount = 0
        for char in trimmed {
            if char == "(" {
                parenCount += 1
            } else if char == ")" {
                parenCount -= 1
                if parenCount < 0 { return false } // More closing than opening
            }
        }
        
        return parenCount == 0 // Must be balanced
    }
    
    /// Sanitizes mathematical expression for safe evaluation
    /// - Parameter expression: Raw expression string
    /// - Returns: Sanitized expression safe for NSExpression, or nil if invalid
    private func sanitizeExpression(_ expression: String) -> String? {
        let trimmed = expression.trimmingCharacters(in: .whitespaces)
        
        // Replace common math symbols with NSExpression-compatible operators
        var sanitized = trimmed
            .replacingOccurrences(of: "×", with: "*")
            .replacingOccurrences(of: "÷", with: "/")
            .replacingOccurrences(of: "−", with: "-") // En-dash to hyphen
        
        // Remove equals sign if present at the end (user might type "5+5=")
        if sanitized.hasSuffix("=") {
            sanitized = String(sanitized.dropLast())
        }
        
        // Validate that we only have allowed characters
        let allowedCharacters = CharacterSet(charactersIn: "0123456789+-*/.() ")
        let sanitizedSet = CharacterSet(charactersIn: sanitized)
        
        guard allowedCharacters.isSuperset(of: sanitizedSet) else {
            debugPrint("Expression contains invalid characters")
            return nil
        }
        
        // Basic structure validation
        guard isValidExpression(sanitized) else {
            debugPrint("Expression failed basic validation")
            return nil
        }
        
        return sanitized
    }
}

// MARK: - String Extension for Convenience

extension String {
    /// Evaluates the string as a mathematical expression if it contains math operators
    /// - Returns: The calculated result as a Double, or nil if not a valid expression
    func evaluateAsMath() -> Double? {
        return CalculatorEngine.shared.evaluate(self)
    }
    
    /// Checks if the string contains mathematical operators
    var containsMathExpression: Bool {
        return CalculatorEngine.shared.containsMathExpression(self)
    }
    
    /// Checks if the string is a valid mathematical expression
    var isValidMathExpression: Bool {
        return CalculatorEngine.shared.isValidExpression(self)
    }
}