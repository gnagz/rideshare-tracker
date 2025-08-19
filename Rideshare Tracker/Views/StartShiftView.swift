//
//  StartShiftView.swift
//  Rideshare Tracker
//
//  Created by George Knaggs with Claude AI assistance on 8/10/25.
//  Updated for macOS support on 8/13/25
//

import SwiftUI

struct StartShiftView: View {
    @EnvironmentObject var dataManager: ShiftDataManager
    @Environment(\.presentationMode) var presentationMode
    
    var onShiftStarted: ((Date) -> Void)? = nil
    
    @State private var startDate = Date()
    @State private var startMileage = ""
    @State private var tankReading = 8.0 // Default to full tank (8/8)
    @State private var showDatePicker = false
    
    var body: some View {
        #if os(macOS)
        VStack(spacing: 0) {
            // Custom Title Bar
            HStack {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Text("Start Shift")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Start") {
                    startShift()
                }
                .disabled(startMileage.isEmpty)
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
            formContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 600, height: 500)
        #else
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
                        .disabled(startMileage.isEmpty)
                    }
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") {
                            hideKeyboard()
                        }
                    }
                }
        }
        #endif
    }
    
    private var formContent: some View {
        #if os(macOS)
        ScrollView {
            VStack(spacing: 20) {
                // Shift Start Time Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Shift Start Time")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    VStack(spacing: 10) {
                        HStack {
                            Text("Start Date & Time")
                            Spacer()
                            TextField("Start Date & Time", value: $startDate, format: .dateTime.month(.abbreviated).day().year().hour().minute())
                                .textFieldStyle(.roundedBorder)
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: 300)
                            
                            Button(action: { showDatePicker.toggle() }) {
                                Image(systemName: "calendar")
                            }
                            .buttonStyle(.borderless)
                        }
                        
                        if showDatePicker {
                            VStack(spacing: 10) {
                                DatePicker("Date", selection: $startDate, displayedComponents: .date)
                                    .datePickerStyle(.compact)
                                
                                DatePicker("Time", selection: $startDate, displayedComponents: .hourAndMinute)
                                    .datePickerStyle(.compact)
                            }
                            .frame(maxHeight: 120)
                        }
                    }
                    .padding(.horizontal, 15)
                    .padding(.vertical, 12)
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(0)
                }
                
                // Vehicle Information Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Vehicle Information")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    VStack(spacing: 15) {
                        HStack {
                            Text("Start Odometer Reading (miles)")
                            Spacer()
                            TextField("Miles", text: $startMileage)
                                .textFieldStyle(.roundedBorder)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 120)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Tank Level")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
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
                    .padding(.horizontal, 15)
                    .padding(.vertical, 12)
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
        #else
        Form {
            Section("Shift Start Time") {
                DatePicker("Date & Time", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.compact)
            }
            
            Section("Vehicle Information") {
                HStack {
                    Text("Start Odometer Reading (miles)")
                    Spacer()
                    TextField("Miles", text: $startMileage)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)
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
        #endif
    }
    
    private func startShift() {
        guard let mileage = Double(startMileage) else { return }
        
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
        #if os(iOS)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }
}