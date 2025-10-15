//
//  ImportExportView.swift
//  Rideshare Tracker
//
//  Created by George Knaggs with Claude AI assistance on 8/26/25.
//

import SwiftUI
import UniformTypeIdentifiers

struct ImportExportView: View {
    @EnvironmentObject var dataManager: ShiftDataManager
    @EnvironmentObject var expenseManager: ExpenseDataManager
    @EnvironmentObject var preferences: AppPreferences
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            TabView {
                ImportView()
                    .tabItem {
                        Image(systemName: "square.and.arrow.down")
                        Text("Import")
                    }
                    .environmentObject(dataManager)
                    .environmentObject(expenseManager)
                    .environmentObject(preferences)
                
                ExportView()
                    .tabItem {
                        Image(systemName: "square.and.arrow.up")
                        Text("Export")
                    }
                    .environmentObject(dataManager)
                    .environmentObject(expenseManager)
                    .environmentObject(preferences)
            }
            .navigationTitle("Import/Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

struct ImportView: View {
    @EnvironmentObject var dataManager: ShiftDataManager
    @EnvironmentObject var expenseManager: ExpenseDataManager
    @EnvironmentObject var preferences: AppPreferences
    
    @State private var importType: ImportType = .shifts
    @State private var showingFilePicker = false
    @State private var importMessage = ""
    @State private var showingImportAlert = false
    @State private var importAlertTitle = ""
    @State private var showingDuplicateOptions = false
    @State private var pendingImportData: PendingImportData?
    @State private var duplicateAction: DuplicateAction = .merge
    
    enum ImportType: String, CaseIterable {
        case shifts = "Shifts"
        case expenses = "Expenses"
        case tolls = "Tolls"

        var icon: String {
            switch self {
            case .shifts: return "car.fill"
            case .expenses: return "receipt.fill"
            case .tolls: return "road.lanes.curved.left"
            }
        }
    }
    
    enum DuplicateAction: String, CaseIterable {
        case merge = "Add New Records"
        case replace = "Replace Existing"
        case skip = "Skip Duplicates"
        
        var description: String {
            switch self {
            case .merge: return "Add all imported records alongside existing data"
            case .replace: return "Replace existing records with imported data"
            case .skip: return "Only add records that don't already exist"
            }
        }
    }
    
    struct PendingImportData {
        let url: URL
        let type: ImportType
    }

    private func getImportDescription(for type: ImportType) -> String {
        switch type {
        case .shifts:
            return "Import shift data from CSV files with trip details, earnings, and expenses."
        case .expenses:
            return "Import business expense records with categories, descriptions, and amounts."
        case .tolls:
            return "Import toll transaction data and automatically match tolls to existing shifts by date and time."
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            
            VStack(spacing: 20) {
                // Import Type Selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Import Type")
                        .font(.headline)
                    
                    Picker("Import Type", selection: $importType) {
                        ForEach(ImportType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding()
                .background(Color(.systemGroupedBackground))
                .cornerRadius(12)
                .padding(.horizontal)
                
                // Import Section
                VStack(spacing: 16) {
                    Image(systemName: "square.and.arrow.down.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)
                    
                    Text("Import \(importType.rawValue)")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(getImportDescription(for: importType))
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button("Select CSV File") {
                        debugMessage("CSV file picker button pressed for import type: \(importType.rawValue)")
                        showingFilePicker = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
            
            Spacer()
            
            VStack(alignment: .leading, spacing: 8) {
                Label("Import Details", systemImage: "info.circle")
                    .font(.headline)
                
                switch importType {
                case .shifts:
                    Text("• Rideshare Tracker shift CSV exports")
                    Text("• Custom CSV files with compatible columns")
                    Text("• Flexible date/time format detection")
                    Text("• Automatic preference detection and warnings")
                case .expenses:
                    Text("• Business expense CSV files")
                    Text("• Required columns: Date, Category, Description, Amount")
                    Text("• Categories: Vehicle, Equipment, Supplies, Amenities")
                    Text("• Flexible date format detection")
                case .tolls:
                    Text("• Toll authority CSV exports")
                    Text("• Automatically matches transactions to shifts by time")
                    Text("• Updates existing shift toll amounts")
                    Text("• Requires: Transaction Date/Time, Transaction Amount")
                }
                
                Text("• Duplicate handling options available")
                    .foregroundColor(.blue)
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.systemGroupedBackground))
            .cornerRadius(8)
            .padding(.horizontal)
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [UTType.commaSeparatedText],
            allowsMultipleSelection: false
        ) { result in
            handleFileSelection(result)
        }
        .alert("Duplicate Data Found", isPresented: $showingDuplicateOptions) {
            Button("Cancel", role: .cancel) {
                pendingImportData = nil
            }
            Button("Add New Records") {
                duplicateAction = .merge
                performImport()
            }
            Button("Replace Existing", role: .destructive) {
                duplicateAction = .replace
                performImport()
            }
            Button("Skip Duplicates") {
                duplicateAction = .skip
                performImport()
            }
        } message: {
            Text("Records with matching start date and odometer reading were found.\n\nHow would you like to handle these duplicates?\n\n• Add New: Import all records alongside existing data\n• Replace: Replace existing records with imported data\n• Skip: Only import records that don't already exist")
        }
        .alert(importAlertTitle, isPresented: $showingImportAlert) {
            Button("OK") { }
        } message: {
            Text(importMessage)
        }
    }
    
    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            debugMessage("File picker succeeded with \(urls.count) URLs")
            guard let url = urls.first else {
                debugMessage("File picker success but no URLs returned")
                return
            }
            debugMessage("Selected file: \(url.lastPathComponent)")
            debugMessage("File URL: \(url)")

            pendingImportData = PendingImportData(url: url, type: importType)
            
            // Check if we have existing data that might cause duplicates (not applicable for tolls)
            if importType == .tolls {
                // Tolls update existing shifts, no duplicate handling needed
                performImport()
            } else {
                let hasExistingData = importType == .shifts ? !dataManager.shifts.isEmpty : !expenseManager.expenses.isEmpty

                if hasExistingData {
                    showingDuplicateOptions = true
                } else {
                    duplicateAction = .merge
                    performImport()
                }
            }
            
        case .failure(let error):
            debugMessage("File picker failed with error: \(error.localizedDescription)")
            debugMessage("File picker error type: \(type(of: error))")
            if let nsError = error as NSError? {
                debugMessage("File picker error domain: \(nsError.domain), code: \(nsError.code)")
                debugMessage("File picker error userInfo: \(nsError.userInfo)")
            }
            importAlertTitle = "Import Failed"
            importMessage = "Failed to access file: \(error.localizedDescription)"
            showingImportAlert = true
        }
    }
    
    private func performImport() {
        guard let pendingData = pendingImportData else { return }
        
        switch pendingData.type {
        case .shifts:
            importShifts(from: pendingData.url)
        case .expenses:
            importExpenses(from: pendingData.url)
        case .tolls:
            importTolls(from: pendingData.url)
        }
        
        pendingImportData = nil
    }
    
    private func importShifts(from url: URL) {
        debugPrint("Starting shift import from UI: \(url.lastPathComponent)")
        let importResult = CSVImportManager.importShifts(from: url)

        switch importResult {
        case .success(let csvResult):
            debugPrint("CSV import successful, processing \(csvResult.shifts.count) shifts with duplicate action: \(duplicateAction)")
            var addedCount = 0
            var updatedCount = 0
            var skippedCount = 0

            for shift in csvResult.shifts {
                let existingShiftIndex = dataManager.shifts.firstIndex { existingShift in
                    Calendar.current.isDate(existingShift.startDate, inSameDayAs: shift.startDate) &&
                    existingShift.startMileage == shift.startMileage
                }

                let isDuplicate = existingShiftIndex != nil
                debugPrint("Processing shift \(shift.startDate): duplicate=\(isDuplicate), action=\(duplicateAction)")

                switch duplicateAction {
                case .merge:
                    dataManager.addShift(shift)
                    addedCount += 1
                    debugPrint("MERGE: Added shift (total shifts: \(dataManager.shifts.count))")
                case .replace:
                    if let index = existingShiftIndex {
                        dataManager.shifts[index] = shift
                        updatedCount += 1
                        debugPrint("REPLACE: Updated existing shift at index \(index)")
                    } else {
                        dataManager.addShift(shift)
                        addedCount += 1
                        debugPrint("REPLACE: Added new shift (total shifts: \(dataManager.shifts.count))")
                    }
                case .skip:
                    if existingShiftIndex == nil {
                        dataManager.addShift(shift)
                        addedCount += 1
                        debugPrint("SKIP: Added non-duplicate shift (total shifts: \(dataManager.shifts.count))")
                    } else {
                        skippedCount += 1
                        debugPrint("SKIP: Skipped duplicate shift")
                    }
                }
            }

            var message = "Import completed:\n"
            if addedCount > 0 { message += "\n• Added: \(addedCount) shifts" }
            if updatedCount > 0 { message += "\n• Updated: \(updatedCount) shifts" }
            if skippedCount > 0 { message += "\n• Skipped: \(skippedCount) duplicates" }

            debugPrint("Import completed: added=\(addedCount), updated=\(updatedCount), skipped=\(skippedCount)")

            importAlertTitle = "Import Successful"
            importMessage = message
            showingImportAlert = true

        case .failure(let error):
            debugMessage("CSV import failed: \(error.localizedDescription)")
            importAlertTitle = "Import Failed"
            importMessage = error.localizedDescription
            showingImportAlert = true
        }
    }
    
    private func importExpenses(from url: URL) {
        let importResult = CSVImportManager.importExpenses(from: url)

        switch importResult {
        case .success(let csvResult):
            var addedCount = 0
            var updatedCount = 0
            var skippedCount = 0

            for expense in csvResult.expenses {
                let existingExpenseIndex = expenseManager.expenses.firstIndex { existingExpense in
                    Calendar.current.isDate(existingExpense.date, inSameDayAs: expense.date) &&
                    existingExpense.category == expense.category &&
                    existingExpense.description == expense.description
                }

                switch duplicateAction {
                case .merge:
                    expenseManager.addExpense(expense)
                    addedCount += 1
                case .replace:
                    if let index = existingExpenseIndex {
                        expenseManager.expenses[index] = expense
                        updatedCount += 1
                    } else {
                        expenseManager.addExpense(expense)
                        addedCount += 1
                    }
                case .skip:
                    if existingExpenseIndex == nil {
                        expenseManager.addExpense(expense)
                        addedCount += 1
                    } else {
                        skippedCount += 1
                    }
                }
            }

            var message = "Import completed:\n"
            if addedCount > 0 { message += "\n• Added: \(addedCount) expenses" }
            if updatedCount > 0 { message += "\n• Updated: \(updatedCount) expenses" }
            if skippedCount > 0 { message += "\n• Skipped: \(skippedCount) duplicates" }

            importAlertTitle = "Import Successful"
            importMessage = message
            showingImportAlert = true

        case .failure(let error):
            importAlertTitle = "Import Failed"
            importMessage = error.localizedDescription
            showingImportAlert = true
        }
    }

    private func importTolls(from url: URL) {
        let importResult = CSVImportManager.importTolls(from: url, dataManager: dataManager)

        switch importResult {
        case .success(let tollResult):
            importAlertTitle = "Toll Import Successful"
            var message = "Import completed:\n\n• Processed: \(tollResult.transactions.count) toll transactions\n• Updated: \(tollResult.updatedShifts.count) shifts"
            if tollResult.imagesGenerated > 0 {
                message += "\n• Generated: \(tollResult.imagesGenerated) toll summary images"
            }
            importMessage = message
            showingImportAlert = true

        case .failure(let error):
            importAlertTitle = "Import Failed"
            importMessage = error.localizedDescription
            showingImportAlert = true
        }
    }

}

struct ExportView: View {
    @EnvironmentObject var dataManager: ShiftDataManager
    @EnvironmentObject var expenseManager: ExpenseDataManager
    @EnvironmentObject var preferences: AppPreferences
    
    @State private var exportType: ExportType = .shifts
    @State private var selectedRange: DateRangeOption = .thisWeek // Default to "This Week" for exports
    @State private var fromDate = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date()) ?? Date()
    @State private var toDate = Date()
    @State private var showingFromDatePicker = false
    @State private var showingToDatePicker = false
    @State private var showingShareSheet = false
    @State private var exportURL: URL?
    @State private var showingExportAlert = false
    @State private var exportMessage = ""
    
    enum ExportType: String, CaseIterable {
        case shifts = "Shifts"
        case expenses = "Expenses"
        
        var icon: String {
            switch self {
            case .shifts: return "car.fill"
            case .expenses: return "receipt.fill"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            
            VStack(spacing: 20) {
                // Export Type Selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Export Type")
                        .font(.headline)
                    
                    Picker("Export Type", selection: $exportType) {
                        ForEach(ExportType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                // Date Range Selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Date Range")
                        .font(.headline)
                    
                    // Range Selector Dropdown
                    Picker("Range", selection: $selectedRange) {
                        ForEach(DateRangeOption.allCases, id: \.self) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: selectedRange) { oldRange, newRange in
                        if newRange != .custom {
                            let dateRange = newRange.getDateRange(weekStartDay: preferences.weekStartDay)
                            fromDate = dateRange.start
                            toDate = dateRange.end
                        }
                    }
                    
                    // Show custom date pickers only when "Custom" is selected
                    if selectedRange == .custom {
                        HStack {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("From")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Button(action: { showingFromDatePicker.toggle() }) {
                                    Text(preferences.formatDate(fromDate))
                                        .foregroundColor(.primary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(8)
                                }
                                
                                if showingFromDatePicker {
                                    DatePicker("", selection: $fromDate, displayedComponents: .date)
                                        .datePickerStyle(.graphical)
                                        .labelsHidden()
                                }
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("To")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Button(action: { showingToDatePicker.toggle() }) {
                                    Text(preferences.formatDate(toDate))
                                        .foregroundColor(.primary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(8)
                                }
                                
                                if showingToDatePicker {
                                    DatePicker("", selection: $toDate, displayedComponents: .date)
                                        .datePickerStyle(.graphical)
                                        .labelsHidden()
                                }
                            }
                        }
                    } else {
                        // Show selected range info for non-custom options
                        Text("Range: \(preferences.formatDate(fromDate)) - \(preferences.formatDate(toDate))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                }
                
                // Export Button
                Button(action: performExport) {
                    HStack {
                        Image(systemName: "square.and.arrow.up.fill")
                        Text("Export \(exportType.rawValue)")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(fromDate > toDate)
            }
            .padding()
            .background(Color(.systemGroupedBackground))
            .cornerRadius(12)
            .padding(.horizontal)
            
            Spacer()
            
            // Export Info
            VStack(alignment: .leading, spacing: 8) {
                Label("Export Details", systemImage: "info.circle")
                    .font(.headline)
                
                switch exportType {
                case .shifts:
                    Text("• All shift data with earnings and expenses")
                    Text("• Calculated fields (profit, MPG, etc.)")
                    Text("• User preferences included")
                case .expenses:
                    Text("• Business expense records")
                    Text("• Categories and descriptions")
                    Text("• Simple format for analysis")
                }
                
                Text("• Date range: \(preferences.formatDate(fromDate)) - \(preferences.formatDate(toDate))")
                    .foregroundColor(.blue)
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.systemGroupedBackground))
            .cornerRadius(8)
            .padding(.horizontal)
        }
        .fileExporter(
            isPresented: $showingShareSheet,
            document: exportURL.map { DocumentFile(url: $0) },
            contentType: .commaSeparatedText,
            defaultFilename: exportURL?.lastPathComponent ?? "export.csv"
        ) { result in
            switch result {
            case .success(let url):
                exportMessage = "Export saved to: \(url.lastPathComponent)"
                showingExportAlert = true
            case .failure(let error):
                exportMessage = "Export failed: \(error.localizedDescription)"
                showingExportAlert = true
            }
        }
        .onAppear {
            // Set initial date range based on default selection
            let dateRange = selectedRange.getDateRange(weekStartDay: preferences.weekStartDay)
            fromDate = dateRange.start
            toDate = dateRange.end
        }
        .alert("Export Result", isPresented: $showingExportAlert) {
            Button("OK") { }
        } message: {
            Text(exportMessage)
        }
    }
    
    private func performExport() {
        let exportURL: URL?
        
        switch exportType {
        case .shifts:
            exportURL = preferences.exportCSVWithRange(shifts: dataManager.shifts, selectedRange: selectedRange, fromDate: fromDate, toDate: toDate)
        case .expenses:
            exportURL = preferences.exportExpensesCSVWithRange(expenses: expenseManager.expenses, selectedRange: selectedRange, fromDate: fromDate, toDate: toDate)
        }
        
        if let url = exportURL {
            self.exportURL = url
            showingShareSheet = true
        } else {
            exportMessage = "Failed to create export file"
            showingExportAlert = true
        }
    }
}


