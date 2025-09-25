//
//  ExpenseListView.swift
//  Rideshare Tracker
//
//  Created by George Knaggs with Claude AI assistance on 8/23/25.
//

import SwiftUI

struct ExpenseListView: View {
    @EnvironmentObject var expenseManager: ExpenseDataManager
    @EnvironmentObject var dataManager: ShiftDataManager
    @EnvironmentObject var preferences: AppPreferences
    @State private var selectedDate = Date()
    @State private var showingAddExpense = false
    @State private var showingDatePicker = false
    @State private var showingMainMenu = false
    
    private var currentMonthExpenses: [ExpenseItem] {
        expenseManager.expensesForMonth(selectedDate).sorted { 
            let calendar = Calendar.current
            let day1 = calendar.component(.day, from: $0.date)
            let day2 = calendar.component(.day, from: $1.date)
            return day1 < day2
        }
    }
    
    private var monthTotal: Double {
        expenseManager.totalForMonth(selectedDate)
    }
    
    private var monthTotalWithoutVehicle: Double {
        expenseManager.expensesForMonth(selectedDate)
            .filter { $0.category != .vehicle }
            .reduce(0) { $0 + $1.amount }
    }
    
    private var yearTotal: Double {
        expenseManager.totalForYear(selectedDate)
    }
    
    private var yearTotalWithoutVehicle: Double {
        expenseManager.expensesForYear(selectedDate)
            .filter { $0.category != .vehicle }
            .reduce(0) { $0 + $1.amount }
    }
    
    private func formatMonthYear(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
    
    private func moveMonth(_ offset: Int) {
        if let newDate = Calendar.current.date(byAdding: .month, value: offset, to: selectedDate) {
            selectedDate = newDate
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Month Navigation Header
                VStack(spacing: 8) {
                    HStack {
                        Button(action: { moveMonth(-1) }) {
                            Image(systemName: "chevron.left")
                                .font(.title2)
                        }
                        
                        Spacer()
                        
                        Button(action: { showingDatePicker.toggle() }) {
                            Text(formatMonthYear(selectedDate))
                                .font(.headline)
                        }
                        .popover(isPresented: $showingDatePicker) {
                            DatePicker("Select Month", 
                                     selection: $selectedDate, 
                                     displayedComponents: [.date])
                                .datePickerStyle(GraphicalDatePickerStyle())
                                .frame(minWidth: 300, minHeight: 300)
                                .padding()
                                .onChange(of: selectedDate) {
                                    showingDatePicker = false
                                }
                        }
                        
                        Spacer()
                        
                        Button(action: { moveMonth(1) }) {
                            Image(systemName: "chevron.right")
                                .font(.title2)
                        }
                        .disabled(Calendar.current.isDate(selectedDate, equalTo: Date(), toGranularity: .month))
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    // Totals Summary
                    VStack(spacing: 8) {
                        HStack(spacing: 20) {
                            VStack {
                                Text("Month Total")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("w/ Vehicle")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text("$\(monthTotal, specifier: "%.2f")")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundColor(monthTotal > 0 ? .red : .secondary)
                            }
                            
                            VStack {
                                Text("Month Total")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("w/o Vehicle")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text("$\(monthTotalWithoutVehicle, specifier: "%.2f")")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundColor(monthTotalWithoutVehicle > 0 ? .red : .secondary)
                            }
                        }
                        
                        HStack(spacing: 20) {
                            VStack {
                                Text("Year Total")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("w/ Vehicle")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text("$\(yearTotal, specifier: "%.2f")")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundColor(yearTotal > 0 ? .red : .secondary)
                            }
                            
                            VStack {
                                Text("Year Total")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("w/o Vehicle")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text("$\(yearTotalWithoutVehicle, specifier: "%.2f")")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundColor(yearTotalWithoutVehicle > 0 ? .red : .secondary)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
                .background(Color(UIColor.systemGroupedBackground))
                
                // Content Area
                if currentMonthExpenses.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "receipt.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text("No expenses for \(formatMonthYear(selectedDate))")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        
                        Text("Tap the + button to add an expense")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    Spacer()
                } else {
                    List {
                        ForEach(currentMonthExpenses) { expense in
                            NavigationLink(destination: EditExpenseView(expense: expense, isSheet: false)) {
                                ExpenseRowView(expense: expense)
                            }
                        }
                        .onDelete(perform: deleteExpenses)
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Expenses")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingMainMenu = true }) {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityIdentifier("settings_button")
                    .accessibilityLabel("Settings")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddExpense = true }) {
                        Image(systemName: "plus")
                    }
                    .accessibilityIdentifier("add_expense_button")
                    .accessibilityLabel("Add Expense")
                }
            }
            .sheet(isPresented: $showingAddExpense) {
                AddExpenseView()
            }
            .sheet(isPresented: $showingMainMenu) {
                MainMenuView()
                    .environmentObject(dataManager)
                    .environmentObject(expenseManager)
                    .environmentObject(preferences)
            }
        }
        .navigationViewStyle(.columns)
    }
    
    private func deleteExpenses(offsets: IndexSet) {
        for offset in offsets {
            let expense = currentMonthExpenses[offset]
            expenseManager.deleteExpense(expense)
        }
    }
}

struct ExpenseRowView: View {
    let expense: ExpenseItem
    @EnvironmentObject var preferences: AppPreferences
    @State private var showingImageViewer = false
    @State private var thumbnailImages: [UIImage] = []
    
    private var dayOfMonth: String {
        let calendar = Calendar.current
        let day = calendar.component(.day, from: expense.date)
        return "\(day)"
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Day of month as first item
            Text(dayOfMonth)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .frame(width: 40, alignment: .center)
                .fixedSize()
                .layoutPriority(1)
            
            // Category icon only
            Image(systemName: expense.category.systemImage)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 25)
                .layoutPriority(1)
            
            // Photo thumbnail indicator
            if !expense.imageAttachments.isEmpty {
                Button(action: { showingImageViewer = true }) {
                    if let firstImage = thumbnailImages.first {
                        Image(uiImage: firstImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 30, height: 30)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color(.systemGray4), lineWidth: 0.5)
                            )
                            .overlay(
                                // Show count if multiple images
                                expense.imageAttachments.count > 1 ?
                                Text("\(expense.imageAttachments.count)")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(2)
                                    .background(Color.black.opacity(0.7), in: Circle())
                                    .offset(x: 10, y: -10)
                                : nil
                            )
                    } else {
                        Image(systemName: "photo.fill")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .frame(width: 30, height: 30)
                            .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 4))
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .layoutPriority(1)
            }
            
            // Description with flexible space
            VStack(alignment: .leading, spacing: 2) {
                Text(expense.description)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(0)
            
            Text("$\(expense.amount, specifier: "%.2f")")
                .font(.headline)
                .foregroundColor(.red)
                .fontWeight(.semibold)
                .fixedSize()
                .layoutPriority(1)
        }
        .padding(.vertical, 6)
        .onAppear {
            loadThumbnails()
        }
        .sheet(isPresented: $showingImageViewer) {
            if !thumbnailImages.isEmpty {
                ImageViewerView(
                    images: thumbnailImages,
                    startingIndex: 0,
                    isPresented: $showingImageViewer
                )
            }
        }
    }
    
    private func loadThumbnails() {
        thumbnailImages.removeAll()
        
        for attachment in expense.imageAttachments {
            if let thumbnail = ImageManager.shared.loadThumbnail(
                for: expense.id,
                parentType: .expense,
                filename: attachment.filename
            ) {
                thumbnailImages.append(thumbnail)
            } else {
                // Fallback to full image if thumbnail not available
                if let fullImage = ImageManager.shared.loadImage(
                    for: expense.id,
                    parentType: .expense,
                    filename: attachment.filename
                ) {
                    thumbnailImages.append(fullImage)
                }
            }
        }
    }
}
