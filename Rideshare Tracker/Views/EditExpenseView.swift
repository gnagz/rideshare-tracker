//
//  EditExpenseView.swift
//  Rideshare Tracker
//
//  Created by George Knaggs with Claude AI assistance on 8/23/25.
//

import SwiftUI

struct EditExpenseView: View {
    @EnvironmentObject var expenseManager: ExpenseDataManager
    @EnvironmentObject var preferences: AppPreferences
    @Environment(\.presentationMode) var presentationMode
    
    let expense: ExpenseItem
    let isSheet: Bool
    
    @State private var selectedDate: Date
    @State private var selectedCategory: ExpenseCategory
    @State private var description: String
    @State private var amount: Double
    @State private var showingDatePicker = false
    @FocusState private var focusedField: FocusedField?
    
    enum FocusedField {
        case description, amount
    }
    
    init(expense: ExpenseItem, isSheet: Bool = true) {
        self.expense = expense
        self.isSheet = isSheet
        _selectedDate = State(initialValue: expense.date)
        _selectedCategory = State(initialValue: expense.category)
        _description = State(initialValue: expense.description)
        _amount = State(initialValue: expense.amount)
    }
    
    private var isFormValid: Bool {
        !description.isEmpty && amount > 0
    }
    
    var body: some View {
        if isSheet {
            NavigationView {
                formContent
                    .navigationTitle("Edit Expense")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Cancel") {
                                presentationMode.wrappedValue.dismiss()
                            }
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Save") {
                                saveChanges()
                            }
                            .disabled(!isFormValid)
                        }
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Done") {
                                hideKeyboard()
                            }
                        }
                    }
            }
        } else {
            formContent
                .navigationTitle("Edit Expense")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") {
                            saveChanges()
                        }
                        .disabled(!isFormValid)
                    }
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") {
                            hideKeyboard()
                        }
                    }
                }
        }
    }
    
    private var formContent: some View {
        Form {
            Section("Date") {
                Button(action: { showingDatePicker.toggle() }) {
                    HStack {
                        Text("Date")
                            .foregroundColor(.primary)
                        Spacer()
                        Text(preferences.formatDate(selectedDate))
                            .foregroundColor(.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                }
                
                if showingDatePicker {
                    DatePicker("", selection: $selectedDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                }
            }
            
            Section("Category") {
                Picker("Category", selection: $selectedCategory) {
                    ForEach(ExpenseCategory.allCases, id: \.self) { category in
                        HStack {
                            Image(systemName: category.systemImage)
                            Text(category.rawValue)
                        }
                        .tag(category)
                    }
                }
                .pickerStyle(.menu)
                .frame(minWidth: 200)
            }
            
            Section("Details") {
                HStack {
                    Text("Description")
                    Spacer()
                    TextField("Enter description", text: $description)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.trailing)
                        .frame(minWidth: 150)
                        .focused($focusedField, equals: .description)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(focusedField == .description ? Color.accentColor : Color.clear, lineWidth: 2)
                        )
                }
                
                HStack {
                    Text("Amount")
                    Spacer()
                    CurrencyTextField(placeholder: "$0.00", value: $amount)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)
                        .focused($focusedField, equals: .amount)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(focusedField == .amount ? Color.accentColor : Color.clear, lineWidth: 2)
                        )
                }
            }
        }
    }
    
    private func saveChanges() {
        var updatedExpense = expense
        updatedExpense.date = selectedDate
        updatedExpense.category = selectedCategory
        updatedExpense.description = description
        updatedExpense.amount = amount
        
        expenseManager.updateExpense(updatedExpense)
        presentationMode.wrappedValue.dismiss()
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}