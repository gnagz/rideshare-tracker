//
//  PreferencesView.swift
//  Rideshare Tracker
//
//  Created by George Knaggs with Claude AI assistance on 8/10/25.
//

import SwiftUI

struct PreferencesView: View {
    @EnvironmentObject var preferences: AppPreferences
    @Environment(\.presentationMode) var presentationMode
    
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
                }
                
                Section(footer: Text("Standard mileage rate is the IRS-approved rate for tax deductions. Update this annually.")) {
                    EmptyView()
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
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
