//
//  ExpenseDataManager.swift
//  Rideshare Tracker
//
//  Created by George Knaggs with Claude AI assistance on 8/23/25.
//

import Foundation

class ExpenseDataManager: ObservableObject {
    static let shared = ExpenseDataManager()
    
    @Published var expenses: [ExpenseItem] = []
    private let expensesKey = "expenses_data"
    
    private init() {
        loadExpenses()
    }
    
    // Public initializer for SwiftUI environment object usage  
    convenience init(forEnvironment: Bool = false) {
        if forEnvironment {
            self.init()
        } else {
            fatalError("Use ExpenseDataManager.shared")
        }
    }
    
    private func loadExpenses() {
        if let data = UserDefaults.standard.data(forKey: expensesKey),
           let decodedExpenses = try? JSONDecoder().decode([ExpenseItem].self, from: data) {
            expenses = decodedExpenses
        }
    }
    
    
    func saveExpenses() {
        if let encoded = try? JSONEncoder().encode(expenses) {
            UserDefaults.standard.set(encoded, forKey: expensesKey)
        }
    }
    
    func addExpense(_ expense: ExpenseItem) {
        expenses.append(expense)
        saveExpenses()
    }
    
    func updateExpense(_ expense: ExpenseItem) {
        if let index = expenses.firstIndex(where: { $0.id == expense.id }) {
            expenses[index] = expense
            saveExpenses()
        }
    }
    
    func deleteExpense(_ expense: ExpenseItem) {
        if AppPreferences.shared.incrementalSyncEnabled {
            // Cloud sync enabled: soft delete for sync propagation
            if let index = expenses.firstIndex(where: { $0.id == expense.id }) {
                expenses[index].isDeleted = true
                expenses[index].modifiedDate = Date()
                saveExpenses()
            }
        } else {
            // Cloud sync disabled: permanent delete
            expenses.removeAll { $0.id == expense.id }
            saveExpenses()
        }
    }
    
    func deleteExpenses(at offsets: IndexSet) {
        if AppPreferences.shared.incrementalSyncEnabled {
            // Cloud sync enabled: soft delete for sync propagation
            for index in offsets.sorted(by: >) {
                expenses[index].isDeleted = true
                expenses[index].modifiedDate = Date()
            }
            saveExpenses()
        } else {
            // Cloud sync disabled: permanent delete
            expenses.remove(atOffsets: offsets)
            saveExpenses()
        }
    }
    
    // Clean up soft-deleted records after successful sync
    func cleanupDeletedExpenses() {
        expenses.removeAll { $0.isDeleted }
        saveExpenses()
    }
    
    // Permanently delete soft-deleted records when sync is disabled
    func permanentlyDeleteSoftDeletedRecords() {
        let deletedCount = expenses.filter { $0.isDeleted }.count
        if deletedCount > 0 {
            expenses.removeAll { $0.isDeleted }
            saveExpenses()
        }
    }
    
    // Filtered access methods (always exclude soft-deleted)
    var activeExpenses: [ExpenseItem] {
        return expenses.filter { !$0.isDeleted }
    }
    
    // MARK: - Filtering and Calculations
    
    func expensesForMonth(_ date: Date) -> [ExpenseItem] {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: date)
        
        return activeExpenses.filter { expense in
            let expenseComponents = calendar.dateComponents([.year, .month], from: expense.date)
            return expenseComponents.year == components.year && expenseComponents.month == components.month
        }
    }
    
    func expensesForYear(_ date: Date) -> [ExpenseItem] {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        
        return activeExpenses.filter { expense in
            calendar.component(.year, from: expense.date) == year
        }
    }
    
    func totalForMonth(_ date: Date) -> Double {
        return expensesForMonth(date).reduce(0) { $0 + $1.amount }
    }
    
    func totalForYear(_ date: Date) -> Double {
        return expensesForYear(date).reduce(0) { $0 + $1.amount }
    }
    
    func expensesByCategory(for expenses: [ExpenseItem]) -> [ExpenseCategory: [ExpenseItem]] {
        return Dictionary(grouping: expenses, by: { $0.category })
    }
    
    func totalByCategory(for expenses: [ExpenseItem]) -> [ExpenseCategory: Double] {
        let groupedExpenses = expensesByCategory(for: expenses)
        var totals: [ExpenseCategory: Double] = [:]
        
        for (category, categoryExpenses) in groupedExpenses {
            totals[category] = categoryExpenses.reduce(0) { $0 + $1.amount }
        }
        
        return totals
    }
}