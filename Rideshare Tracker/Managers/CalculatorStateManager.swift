//
//  CalculatorStateManager.swift
//  Rideshare Tracker
//
//  Created by George Knaggs with Claude AI assistance on 9/8/25.
//

import SwiftUI

// Global calculator state manager to persist across app lifecycle
@MainActor
class CalculatorStateManager: ObservableObject {
    static let shared = CalculatorStateManager()

    @Published var displayValue: String = "0"
    @Published var previousValue: Double = 0
    @Published var operation: String = ""
    @Published var waitingForOperand: Bool = false
    @Published var memoryValue: Double = 0
    @Published var calculationTape: [CalculationStep] = []

    private init() {}

    func reset() {
        displayValue = "0"
        previousValue = 0
        operation = ""
        waitingForOperand = false
        memoryValue = 0
        calculationTape = []
    }
}

// CalculationStep struct for calculator history
struct CalculationStep: Identifiable {
    let id = UUID()
    let expression: String
    let result: Double
}