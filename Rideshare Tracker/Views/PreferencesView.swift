//
//  PreferencesView.swift
//  Rideshare Tracker
//
//  Created by George Knaggs with Claude AI assistance on 8/10/25.
//  Optimized for iOS Universal (iPhone, iPad, Mac) on 8/19/25
//

import SwiftUI
import UIKit

struct PreferencesView: View {
    @EnvironmentObject var preferences: AppPreferences
    @EnvironmentObject var dataManager: ShiftDataManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var currentDate = Date()
    @FocusState private var focusedField: FocusedField?
    
    enum FocusedField {
        case tankCapacity, gasPrice, mileageRate, taxRate
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
                            .focused($focusedField, equals: .tankCapacity)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(focusedField == .tankCapacity ? Color.accentColor : Color.clear, lineWidth: 2)
                            )
                    }
                    HStack {
                        Text("Gas Price (per gallon)")
                        Spacer()
                        CurrencyTextField(placeholder: "$0.00", value: $preferences.gasPrice)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(focusedField == .gasPrice ? Color.accentColor : Color.clear, lineWidth: 2)
                            )
                    }
                }
                
                Section("Tax Settings") {
                    HStack {
                        Text("Standard Mileage Rate")
                        Spacer()
                        CurrencyTextField(placeholder: "$0.67", value: $preferences.standardMileageRate)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(focusedField == .mileageRate ? Color.accentColor : Color.clear, lineWidth: 2)
                            )
                    }
                    
                    Text("Standard mileage rate is the IRS-approved rate for tax deductions. Update this annually.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                    
                    Toggle("Tips are tax deductible", isOn: $preferences.tipDeductionEnabled)
                    
                    Text("Tips are deductible through tax year 2028 under current IRS rules.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 2)
                    
                    HStack {
                        Text("Effective Tax Rate (%)")
                        Spacer()
                        CalculatorTextField(placeholder: "22.0", value: $preferences.effectivePersonalTaxRate, formatter: .mileage)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                            .focused($focusedField, equals: .taxRate)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(focusedField == .taxRate ? Color.accentColor : Color.clear, lineWidth: 2)
                            )
                    }
                    
                    Text("Your combined Federal and State tax rate percentages used for estimating your taxes due.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 2)
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
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

