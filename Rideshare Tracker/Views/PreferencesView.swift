//
//  PreferencesView.swift
//  Rideshare Tracker
//
//  Created by George Knaggs with Claude AI assistance on 8/10/25.
//  Updated for macOS support on 8/13/25
//

import SwiftUI
import UniformTypeIdentifiers
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

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
    
    var body: some View {
        #if os(macOS)
        macOSView
        #else
        iOSView
        #endif
    }
    
    #if os(macOS)
    var macOSView: some View {
        VStack(spacing: 0) {
            // Custom Title Bar
            HStack {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Text("Preferences")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Save") {
                    preferences.savePreferences()
                    presentationMode.wrappedValue.dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(.windowBackgroundColor))
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color(.separatorColor)),
                alignment: .bottom
            )
            
            // Content
            ScrollView {
                VStack(spacing: 20) {
                    // Display Settings
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Display Settings")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        VStack(spacing: 15) {
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
                        }
                        .padding()
                        .background(Color(.controlBackgroundColor))
                        .cornerRadius(0)
                    }
                    
                    // Vehicle Settings
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Vehicle Settings")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        VStack(spacing: 15) {
                            HStack {
                                Text("Gas Tank Capacity (gallons)")
                                Spacer()
                                TextField("Gallons", value: $preferences.tankCapacity, format: .number)
                                    .textFieldStyle(.roundedBorder)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 80)
                            }
                            HStack {
                                Text("Gas Price (per gallon)")
                                Spacer()
                                TextField("$0.00", value: $preferences.gasPrice, format: .currency(code: "USD"))
                                    .textFieldStyle(.roundedBorder)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 80)
                            }
                        }
                        .padding()
                        .background(Color(.controlBackgroundColor))
                        .cornerRadius(0)
                    }
                    
                    // Tax Settings
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Tax Settings")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        VStack(spacing: 15) {
                            HStack {
                                Text("Standard Mileage Rate")
                                Spacer()
                                TextField("$0.00", value: $preferences.standardMileageRate, format: .currency(code: "USD"))
                                    .textFieldStyle(.roundedBorder)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 80)
                            }
                            
                            HStack {
                                Text("Standard mileage rate is the IRS-approved rate for tax deductions. Update this annually.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.leading)
                                Spacer()
                            }
                        }
                        .padding()
                        .background(Color(.controlBackgroundColor))
                        .cornerRadius(0)
                    }
                    
                    // Data Management
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Data Management")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        VStack(spacing: 15) {
                            HStack {
                                Button("Export Data") {
                                    exportData()
                                }
                                .buttonStyle(.bordered)
                                
                                Spacer()
                                
                                Button("Import Data") {
                                    showingImportSheet = true
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding()
                        .background(Color(.controlBackgroundColor))
                        .cornerRadius(0)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 15)
                .padding(.vertical)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.windowBackgroundColor))
        }
        .frame(width: 600, height: 500)
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
    #endif
    
    #if os(iOS)
    var iOSView: some View {
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
        .sheet(isPresented: $showingExportSheet) {
            if let url = backupFileURL {
                #if os(iOS)
                ActivityView(activityItems: [url])
                #endif
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
    #endif
    
    private func hideKeyboard() {
        #if os(iOS)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }
    
    private func exportData() {
        guard let url = preferences.exportData(shifts: dataManager.shifts) else {
            importAlertTitle = "Export Failed"
            importAlertMessage = "Unable to create backup file."
            showingImportAlert = true
            return
        }
        
        #if os(macOS)
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [UTType.json]
        savePanel.nameFieldStringValue = url.lastPathComponent
        savePanel.begin { result in
            if result == .OK, let destinationURL = savePanel.url {
                do {
                    try FileManager.default.copyItem(at: url, to: destinationURL)
                    importAlertTitle = "Export Successful"
                    importAlertMessage = "Data exported to \(destinationURL.lastPathComponent)"
                    showingImportAlert = true
                } catch {
                    importAlertTitle = "Export Failed"
                    importAlertMessage = "Unable to save file: \(error.localizedDescription)"
                    showingImportAlert = true
                }
            }
        }
        #else
        backupFileURL = url
        showingExportSheet = true
        #endif
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

#if os(iOS)
struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        
    }
}
#endif
