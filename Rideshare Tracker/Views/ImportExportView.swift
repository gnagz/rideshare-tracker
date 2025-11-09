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
    @EnvironmentObject var preferencesManager: PreferencesManager
    @EnvironmentObject var importExportManager: ImportExportManager
    @Environment(\.presentationMode) var presentationMode

    private var preferences: AppPreferences { preferencesManager.preferences }

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
                    .environmentObject(preferencesManager)

                ExportView()
                    .tabItem {
                        Image(systemName: "square.and.arrow.up")
                        Text("Export")
                    }
                    .environmentObject(dataManager)
                    .environmentObject(expenseManager)
                    .environmentObject(preferencesManager)
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
    @EnvironmentObject var preferencesManager: PreferencesManager
    @EnvironmentObject var importExportManager: ImportExportManager

    private var preferences: AppPreferences { preferencesManager.preferences }

    @State private var importType: ImportType = .shifts
    @State private var shiftSubtype: ShiftImportSubtype = .shiftCSV
    @State private var showingFilePicker = false
    @State private var showingUberImport = false
    @State private var importMessage = ""
    @State private var showingImportAlert = false
    @State private var importAlertTitle = ""
    @State private var showingDuplicateOptions = false
    @State private var pendingImportData: PendingImportData?
    @State private var duplicateAction: DuplicateAction = .merge

    enum ImportType: String, CaseIterable {
        case shifts = "Shifts"
        case expenses = "Expenses"

        var icon: String {
            switch self {
            case .shifts: return "car.fill"
            case .expenses: return "receipt.fill"
            }
        }
    }

    enum ShiftImportSubtype: String, CaseIterable {
        case shiftCSV = "Shift CSV"
        case tollCSV = "Toll Authority CSV"
        case uberPDF = "Uber Weekly Statement"

        var icon: String {
            switch self {
            case .shiftCSV: return "doc.text"
            case .tollCSV: return "road.lanes.curved.left"
            case .uberPDF: return "doc.text.fill"
            }
        }

        var description: String {
            switch self {
            case .shiftCSV:
                return "Import shift data from CSV files with flexible column detection and duplicate handling."
            case .tollCSV:
                return "Import toll transactions and automatically match them to existing shifts by date and time."
            case .uberPDF:
                return "Import tips and toll reimbursements from Uber weekly statements, matching to existing shifts."
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
        let shiftSubtype: ShiftImportSubtype?
    }

    private func getImportDescription(for type: ImportType) -> String {
        switch type {
        case .shifts:
            return "Import shift data from CSV or PDF files with flexible format detection."
        case .expenses:
            return "Import business expense records from CSV files with category and amount data."
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {

            VStack(spacing: 16) {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 60))
                    .foregroundColor(.green)

                Text("Import \(importType.rawValue)")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(getImportDescription(for: importType))
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal)

                // Import Type Picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Import Type")
                        .font(.headline)

                    Picker("Import Type", selection: $importType) {
                        ForEach(ImportType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.horizontal)

                // Shift Subtype Selection (only show when Shifts is selected)
                if importType == .shifts {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Shift Import Type")
                            .font(.headline)

                        Picker("Shift Import Type", selection: $shiftSubtype) {
                            ForEach(ShiftImportSubtype.allCases, id: \.self) { subtype in
                                Text(subtype.rawValue).tag(subtype)
                            }
                        }
                        .pickerStyle(.segmented)

                        Text(shiftSubtype.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal)
                }

                Button(importType == .shifts && shiftSubtype == .uberPDF ? "Select PDF File" : "Select CSV File") {
                    debugMessage("File picker button pressed for import type: \(importType.rawValue)")
                    if importType == .shifts && shiftSubtype == .uberPDF {
                        showingUberImport = true
                    } else {
                        showingFilePicker = true
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            
            Spacer()
            
            VStack(alignment: .leading, spacing: 8) {
                Label("Import Details", systemImage: "info.circle")
                    .font(.headline)

                switch importType {
                case .shifts:
                    switch shiftSubtype {
                    case .shiftCSV:
                        Text("• Rideshare Tracker shift CSV exports")
                        Text("• Custom CSV files with compatible columns")
                        Text("• Flexible date/time format detection")
                        Text("• Automatic preference detection and warnings")
                        Text("• Duplicate handling options available")
                            .foregroundColor(.blue)
                    case .tollCSV:
                        Text("• Toll authority CSV exports")
                        Text("• Automatically matches transactions to shifts by time")
                        Text("• Updates existing shift toll amounts")
                        Text("• Requires: Transaction Date/Time, Transaction Amount")
                    case .uberPDF:
                        Text("• Uber weekly statement PDF files")
                        Text("• Extracts tips and toll reimbursements")
                        Text("• Matches to existing shifts using 4 AM boundaries")
                        Text("• Generates summary images for matched data")
                        Text("• Creates CSV for missing shifts (unmatched transactions)")
                    }
                case .expenses:
                    Text("• Business expense CSV files")
                    Text("• Required columns: Date, Category, Description, Amount")
                    Text("• Categories: Vehicle, Equipment, Supplies, Amenities")
                    Text("• Flexible date format detection")
                    Text("• Duplicate handling options available")
                        .foregroundColor(.blue)
                }
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
        .sheet(isPresented: $showingUberImport) {
            UberImportView()
                .environmentObject(dataManager)
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

            pendingImportData = PendingImportData(url: url, type: importType, shiftSubtype: importType == .shifts ? shiftSubtype : nil)

            // Check if we have existing data that might cause duplicates
            // Tolls and Uber imports update existing shifts, no duplicate handling needed
            if (importType == .shifts && (shiftSubtype == .tollCSV || shiftSubtype == .uberPDF)) {
                // These update existing shifts, no duplicate handling needed
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
            if let subtype = pendingData.shiftSubtype {
                switch subtype {
                case .shiftCSV:
                    importShifts(from: pendingData.url)
                case .tollCSV:
                    importTolls(from: pendingData.url)
                case .uberPDF:
                    // Uber PDF handled via sheet modal, not file picker
                    break
                }
            } else {
                importShifts(from: pendingData.url)
            }
        case .expenses:
            importExpenses(from: pendingData.url)
        }

        pendingImportData = nil
    }
    
    private func importShifts(from url: URL) {
        debugMessage("Starting shift import from UI: \(url.lastPathComponent)")

        let csvResult: CSVImportResult
        do {
            csvResult = try importExportManager.importShifts(from: url)
        } catch {
            debugMessage("Shift import failed: \(error)")
            importAlertTitle = "Import Failed"
            importMessage = importExportManager.lastError?.localizedDescription ?? "Unknown error"
            showingImportAlert = true
            return
        }

        // Import successful, process shifts
        do {
            debugMessage("CSV import successful, processing \(csvResult.shifts.count) shifts with duplicate action: \(duplicateAction)")
            var addedCount = 0
            var updatedCount = 0
            var skippedCount = 0

            for shift in csvResult.shifts {
                let existingShiftIndex = dataManager.shifts.firstIndex { existingShift in
                    Calendar.current.isDate(existingShift.startDate, inSameDayAs: shift.startDate) &&
                    existingShift.startMileage == shift.startMileage
                }

                let isDuplicate = existingShiftIndex != nil
                debugMessage("Processing shift \(shift.startDate): duplicate=\(isDuplicate), action=\(duplicateAction)")

                switch duplicateAction {
                case .merge:
                    dataManager.addShift(shift)
                    addedCount += 1
                    debugMessage("MERGE: Added shift (total shifts: \(dataManager.shifts.count))")
                case .replace:
                    if let index = existingShiftIndex {
                        dataManager.shifts[index] = shift
                        updatedCount += 1
                        debugMessage("REPLACE: Updated existing shift at index \(index)")
                    } else {
                        dataManager.addShift(shift)
                        addedCount += 1
                        debugMessage("REPLACE: Added new shift (total shifts: \(dataManager.shifts.count))")
                    }
                case .skip:
                    if existingShiftIndex == nil {
                        dataManager.addShift(shift)
                        addedCount += 1
                        debugMessage("SKIP: Added non-duplicate shift (total shifts: \(dataManager.shifts.count))")
                    } else {
                        skippedCount += 1
                        debugMessage("SKIP: Skipped duplicate shift")
                    }
                }
            }

            var message = "Import completed:\n"
            if addedCount > 0 { message += "\n• Added: \(addedCount) shifts" }
            if updatedCount > 0 { message += "\n• Updated: \(updatedCount) shifts" }
            if skippedCount > 0 { message += "\n• Skipped: \(skippedCount) duplicates" }

            debugMessage("Import completed: added=\(addedCount), updated=\(updatedCount), skipped=\(skippedCount)")

            importAlertTitle = "Import Successful"
            importMessage = message
            showingImportAlert = true
        }
    }
    
    private func importExpenses(from url: URL) {
        let csvResult: ExpenseImportResult
        do {
            csvResult = try importExportManager.importExpenses(from: url)
        } catch {
            debugMessage("Expense import failed: \(error)")
            importAlertTitle = "Import Failed"
            importMessage = importExportManager.lastError?.localizedDescription ?? "Unknown error"
            showingImportAlert = true
            return
        }

        do {
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
        }
    }

    private func importTolls(from url: URL) {
        let tollResult: TollImportResult
        do {
            tollResult = try importExportManager.importTolls(from: url, dataManager: dataManager)
        } catch {
            debugMessage("Toll import failed: \(error)")
            importAlertTitle = "Import Failed"
            importMessage = importExportManager.lastError?.localizedDescription ?? "Unknown error"
            showingImportAlert = true
            return
        }

        do {
            importAlertTitle = "Toll Import Successful"
            var message = "Import completed:\n\n• Processed: \(tollResult.transactions.count) toll transactions\n• Updated: \(tollResult.updatedShifts.count) shifts"
            if tollResult.imagesGenerated > 0 {
                message += "\n• Generated: \(tollResult.imagesGenerated) toll summary images"
            }
            importMessage = message
            showingImportAlert = true
        }
    }

}

struct ExportView: View {
    @EnvironmentObject var dataManager: ShiftDataManager
    @EnvironmentObject var expenseManager: ExpenseDataManager
    @EnvironmentObject var preferencesManager: PreferencesManager

    private var preferences: AppPreferences { preferencesManager.preferences }
    @EnvironmentObject var importExportManager: ImportExportManager

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

            VStack(spacing: 16) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 60))
                    .foregroundColor(.green)

                Text("Export \(exportType.rawValue)")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Export data to CSV files for the selected date range.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal)

                // Export Type Picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Export Type")
                        .font(.headline)

                    Picker("Export Type", selection: $exportType) {
                        ForEach(ExportType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.horizontal)
                
                // Date Range Selection
                VStack(alignment: .leading, spacing: 8) {
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
                                    Text(preferencesManager.formatDate(fromDate))
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
                                    Text(preferencesManager.formatDate(toDate))
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
                        Text("\(preferencesManager.formatDate(fromDate)) - \(preferencesManager.formatDate(toDate))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                }
                .padding(.horizontal)

                Button("Export \(exportType.rawValue)") {
                    performExport()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(fromDate > toDate)
            }
            
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
                
                Text("• Date range: \(preferencesManager.formatDate(fromDate)) - \(preferencesManager.formatDate(toDate))")
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
        do {
            let exportURL: URL

            switch exportType {
            case .shifts:
                exportURL = try importExportManager.exportCSVWithRange(shifts: dataManager.shifts, preferencesManager: preferencesManager, selectedRange: selectedRange, fromDate: fromDate, toDate: toDate)
            case .expenses:
                exportURL = try importExportManager.exportExpensesCSVWithRange(expenses: expenseManager.expenses, preferencesManager: preferencesManager, selectedRange: selectedRange, fromDate: fromDate, toDate: toDate)
            }

            self.exportURL = exportURL
            showingShareSheet = true
        } catch {
            debugMessage("Export failed: \(error)")
            exportMessage = importExportManager.lastError?.localizedDescription ?? "Failed to create export file"
            showingExportAlert = true
        }
    }
}


