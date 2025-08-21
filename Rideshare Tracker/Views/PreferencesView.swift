//
//  PreferencesView.swift
//  Rideshare Tracker
//
//  Created by George Knaggs with Claude AI assistance on 8/10/25.
//  Optimized for iOS Universal (iPhone, iPad, Mac) on 8/19/25
//

import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct PreferencesView: View {
    @EnvironmentObject var preferences: AppPreferences
    @EnvironmentObject var dataManager: ShiftDataManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var showingExportSheet = false
    @State private var showingImportSheet = false
    @State private var showingImportAlert = false
    @State private var importAlertTitle = ""
    @State private var importAlertMessage = ""
    @State private var backupFileURL: URL?
    @State private var pendingBackupData: BackupData?
    @State private var showingImportOptions = false
    @State private var currentDate = Date()
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    private var dateFormatExamples: [(String, String)] {
        let formats = [
            ("M/d/yyyy", "US Format"),
            ("MMM d, yyyy", "Written Format"), 
            ("d/M/yyyy", "International Format"),
            ("yyyy-MM-dd", "ISO Format")
        ]
        
        return formats.map { (format, description) in
            let formatter = DateFormatter()
            formatter.dateFormat = format
            return (format, formatter.string(from: currentDate))
        }
    }
    
    private var timeFormatExamples: [(String, String)] {
        let formats = [
            ("h:mm a", "12-hour"),
            ("HH:mm", "24-hour")
        ]
        
        return formats.map { (format, description) in
            let formatter = DateFormatter()
            formatter.dateFormat = format
            return (format, formatter.string(from: currentDate))
        }
    }
    
    private var commonTimeZones: [(String, String)] {
        let timeZoneIdentifiers = [
            "America/New_York",
            "America/Chicago", 
            "America/Denver",
            "America/Phoenix",
            "America/Los_Angeles",
            "America/Anchorage",
            "Pacific/Honolulu",
            "UTC"
        ]
        
        return timeZoneIdentifiers.compactMap { identifier in
            guard let timeZone = TimeZone(identifier: identifier) else { return nil }
            let formatter = DateFormatter()
            formatter.timeZone = timeZone
            formatter.dateFormat = "HH:mm"
            let timeExample = formatter.string(from: currentDate)
            return (identifier, "\(timeZone.localizedName(for: .shortStandard, locale: .current) ?? identifier) (\(timeExample))")
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Display Settings") {
                    HStack {
                        Text("Week Start Day")
                        Spacer()
                        Picker("", selection: $preferences.weekStartDay) {
                            Text("Sunday").tag(1)
                            Text("Monday").tag(2)
                            Text("Tuesday").tag(3)
                            Text("Wednesday").tag(4)
                            Text("Thursday").tag(5)
                            Text("Friday").tag(6)
                            Text("Saturday").tag(7)
                        }
                        .pickerStyle(MenuPickerStyle())
                        .fixedSize()
                    }
                    
                    HStack {
                        Text("Date Format")
                        Spacer()
                        Picker("", selection: $preferences.dateFormat) {
                            ForEach(dateFormatExamples, id: \.0) { format, example in
                                Text(example).tag(format)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .fixedSize()
                    }
                    
                    HStack {
                        Text("Time Format")
                        Spacer()
                        Picker("", selection: $preferences.timeFormat) {
                            ForEach(timeFormatExamples, id: \.0) { format, example in
                                Text(example).tag(format)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .fixedSize()
                    }
                    
                    HStack {
                        Text("Time Zone")
                        Spacer()
                        Picker("", selection: $preferences.timeZoneIdentifier) {
                            ForEach(commonTimeZones, id: \.0) { identifier, displayName in
                                Text(displayName).tag(identifier)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .fixedSize()
                    }
                }
                
                Section("Vehicle Settings") {
                    HStack {
                        Text("Gas Tank Capacity (gallons)")
                        Spacer()
                        TextField("Gallons", value: $preferences.tankCapacity, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                    HStack {
                        Text("Gas Price (per gallon)")
                        Spacer()
                        TextField("$0.00", value: $preferences.gasPrice, format: .currency(code: "USD"))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                }
                
                Section("Tax Settings") {
                    HStack {
                        Text("Standard Mileage Rate")
                        Spacer()
                        TextField("Rate", value: $preferences.standardMileageRate, format: .currency(code: "USD"))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                    
                    Text("Standard mileage rate is the IRS-approved rate for tax deductions. Update this annually.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
                
                Section("Data Management") {
                    Button("Export Data") {
                        exportData()
                    }
                    
                    Button("Import Data") {
                        showingImportSheet = true
                    }
                }
                
                Section("App Info") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(appVersion)
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Build")
                        Spacer()
                        Text(buildNumber)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Preferences")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        hideKeyboard()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        preferences.savePreferences()
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .onAppear {
            currentDate = Date()
            // Update the date every minute to keep examples current
            Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { _ in
                currentDate = Date()
            }
        }
        .sheet(isPresented: $showingExportSheet) {
            if let url = backupFileURL {
                ActivityView(activityItems: [url])
            }
        }
        .fileImporter(
            isPresented: $showingImportSheet,
            allowedContentTypes: [UTType.json],
            allowsMultipleSelection: false
        ) { result in
            handleImportFile(result: result)
        }
        .alert(isPresented: $showingImportAlert) {
            Alert(
                title: Text(importAlertTitle),
                message: Text(importAlertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .alert(isPresented: $showingImportOptions) {
            Alert(
                title: Text("Import Options"),
                message: Text("How would you like to import the data?"),
                primaryButton: .destructive(Text("Replace All")) {
                    performImport(replaceExisting: true)
                },
                secondaryButton: .default(Text("Merge")) {
                    performImport(replaceExisting: false)
                }
            )
        }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private func exportData() {
        guard let url = preferences.exportData(shifts: dataManager.shifts) else {
            importAlertTitle = "Export Failed"
            importAlertMessage = "Unable to create backup file."
            showingImportAlert = true
            return
        }
        
        backupFileURL = url
        showingExportSheet = true
    }
    
    private func handleImportFile(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            let importResult = AppPreferences.importData(from: url)
            switch importResult {
            case .success(let backupData):
                pendingBackupData = backupData
                showingImportOptions = true
                
            case .failure(let error):
                importAlertTitle = "Import Failed"
                importAlertMessage = error.localizedDescription
                showingImportAlert = true
            }
            
        case .failure(let error):
            importAlertTitle = "Import Failed"
            importAlertMessage = error.localizedDescription
            showingImportAlert = true
        }
    }
    
    private func performImport(replaceExisting: Bool) {
        guard let backupData = pendingBackupData else { return }
        
        dataManager.importShifts(backupData.shifts, replaceExisting: replaceExisting)
        preferences.importPreferences(backupData.preferences)
        
        importAlertTitle = "Import Successful"
        if replaceExisting {
            importAlertMessage = "Data has been replaced with backup data."
        } else {
            let newShiftsCount = backupData.shifts.count
            importAlertMessage = "Successfully merged \(newShiftsCount) shifts from backup."
        }
        showingImportAlert = true
        
        pendingBackupData = nil
    }
}

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        
    }
}