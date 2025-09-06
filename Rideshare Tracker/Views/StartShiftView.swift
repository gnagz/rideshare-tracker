//
//  StartShiftView.swift
//  Rideshare Tracker
//
//  Created by George Knaggs with Claude AI assistance on 8/10/25.
//

import SwiftUI

struct StartShiftView: View {
    @EnvironmentObject var dataManager: ShiftDataManager
    @EnvironmentObject var preferences: AppPreferences
    @Environment(\.presentationMode) var presentationMode
    
    var onShiftStarted: ((Date) -> Void)? = nil
    
    @State private var startDate = Date()
    @State private var startMileage: Double?
    @State private var tankReading = 8.0 // Default to full tank (8/8)
    @State private var showDatePicker = false
    @State private var showTimePicker = false
    @FocusState private var focusedField: FocusedField?
    
    enum FocusedField {
        case mileage, date, time
    }
    
    var body: some View {
        NavigationView {
            formContent
                .navigationTitle("Start Shift")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Start") {
                            startShift()
                        }
                        .disabled(startMileage == nil)
                        .accessibilityIdentifier("confirm_start_shift_button")
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
            Section("Shift Start Time") {
                Button(action: { 
                    focusedField = .date
                    showDatePicker.toggle() 
                }) {
                    HStack {
                        Text("Date")
                            .foregroundColor(.primary)
                        Spacer()
                        Text(preferences.formatDate(startDate))
                            .foregroundColor(.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(focusedField == .date ? Color.accentColor : Color.clear, lineWidth: 2)
                )
                
                if showDatePicker {
                    DatePicker("", selection: $startDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                }
                
                Button(action: { 
                    focusedField = .time
                    showTimePicker.toggle() 
                }) {
                    HStack {
                        Text("Time")
                            .foregroundColor(.primary)
                        Spacer()
                        Text(preferences.formatTime(startDate))
                            .foregroundColor(.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(focusedField == .time ? Color.accentColor : Color.clear, lineWidth: 2)
                )
                
                if showTimePicker {
                    DatePicker("", selection: $startDate, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                }
            }
            
            Section("Vehicle Information") {
                HStack {
                    Text("Start Odometer Reading (miles)")
                    Spacer()
                    TextField("Miles", value: $startMileage, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)
                        .focused($focusedField, equals: .mileage)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(focusedField == .mileage ? Color.accentColor : Color.clear, lineWidth: 2)
                        )
                        .accessibilityIdentifier("start_mileage_input")
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tank Level")
                        .font(.headline)
                    
                    Picker("Tank Reading", selection: $tankReading) {
                        Text("E").tag(0.0)
                        Text("1/8").tag(1.0)
                        Text("1/4").tag(2.0)
                        Text("3/8").tag(3.0)
                        Text("1/2").tag(4.0)
                        Text("5/8").tag(5.0)
                        Text("3/4").tag(6.0)
                        Text("7/8").tag(7.0)
                        Text("F").tag(8.0)
                    }
                    .pickerStyle(.segmented)
                }
            }
        }
    }
    
    private func startShift() {
        guard let mileage = startMileage else { return }
        
        let shift = RideshareShift(
            startDate: startDate,
            startMileage: mileage,
            startTankReading: tankReading,
            hasFullTankAtStart: tankReading == 8.0
        )
        
        dataManager.addShift(shift)
        onShiftStarted?(startDate)
        presentationMode.wrappedValue.dismiss()
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

