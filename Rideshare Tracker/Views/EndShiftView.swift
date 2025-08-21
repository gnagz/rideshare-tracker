//
//  EndShiftView.swift
//  Rideshare Tracker
//
//  Created by George Knaggs with Claude AI assistance on 8/10/25.
//  Updated for macOS support on 8/13/25
//

import SwiftUI

struct EndShiftView: View {
    @Binding var shift: RideshareShift
    @EnvironmentObject var dataManager: ShiftDataManager
    @EnvironmentObject var preferences: AppPreferences
    @Environment(\.presentationMode) var presentationMode
    
    @State private var endDate = Date()
    @State private var endMileage = ""
    @State private var didRefuel = false
    @State private var refuelGallons = ""
    @State private var refuelCost: Double? = nil
    @State private var tankReading: Double
    @State private var totalTrips = ""
    @State private var netFare: Double? = nil
    @State private var tips: Double? = nil
    @State private var totalTolls: Double? = nil
    @State private var tollsReimbursed: Double? = nil
    @State private var parkingFees: Double? = nil
    @State private var odometerError = ""
    @State private var showEndDatePicker = false
    
    init(shift: Binding<RideshareShift>) {
        self._shift = shift
        self._tankReading = State(initialValue: shift.wrappedValue.startTankReading)
    }
    
    private var availableTankLevels: [(label: String, value: Double)] {
        let allLevels = [
            ("E", 0.0),
            ("1/8", 1.0),
            ("1/4", 2.0),
            ("3/8", 3.0),
            ("1/2", 4.0),
            ("5/8", 5.0),
            ("3/4", 6.0),
            ("7/8", 7.0),
            ("F", 8.0)
        ]
        return allLevels.filter { $0.1 <= shift.startTankReading }
    }
    
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
                
                Text("End Shift")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Save") {
                    endShift()
                }
                .disabled(endMileage.isEmpty || totalTrips.isEmpty || !odometerError.isEmpty)
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
            mainContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 700, height: 700)
        #else
        NavigationView {
            formContent
        }
        #endif
    }
    
    private var mainContent: some View {
        #if os(macOS)
        ScrollView {
            VStack(spacing: 20) {
                endSectionCustom
                earningsSectionCustom
                expensesSectionCustom
                
                Spacer()
            }
            .padding(.horizontal, 15)
            .padding(.vertical)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.windowBackgroundColor))
        #else
        formContent
        #endif
    }
    
    private var formContent: some View {
        Form {
                Section("Shift End") {
                    HStack {
                        Text("Date")
                        Spacer()
                        Button(preferences.formatDate(endDate)) {
                            // Date picker will be shown in overlay
                        }
                        .foregroundColor(.primary)
                    }
                    .background(
                        DatePicker("", selection: $endDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .opacity(0.011) // Nearly invisible but still functional
                    )
                    
                    HStack {
                        Text("Time")
                        Spacer()
                        Button(preferences.formatTime(endDate)) {
                            // Time picker will be shown in overlay
                        }
                        .foregroundColor(.primary)
                    }
                    .background(
                        DatePicker("", selection: $endDate, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .opacity(0.011) // Nearly invisible but still functional
                    )
                }
                
                Section("Vehicle Information") {
                    HStack {
                        Text("End Odometer Reading")
                        Spacer()
                        TextField("Miles", text: $endMileage)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120)
                            .onChange(of: endMileage) { _ in
                                validateOdometerReading()
                            }
                    }
                    
                    if !odometerError.isEmpty {
                        Text(odometerError)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                    
                    HStack {
                        Text("Refueled Tank")
                        Spacer()
                        Toggle("", isOn: $didRefuel)
                    }
                    
                    if didRefuel {
                        HStack {
                            Text("Gallons Filled")
                            Spacer()
                            TextField("Gallons", text: $refuelGallons)
                                #if os(iOS)
                                .keyboardType(.decimalPad)
                                #endif
                                .multilineTextAlignment(.trailing)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 120)
                        }
                        HStack {
                            Text("Fuel Cost")
                            Spacer()
                            TextField("$0.00", value: $refuelCost, format: .currency(code: "USD"))
                                #if os(iOS)
                                .keyboardType(.decimalPad)
                                #endif
                                .multilineTextAlignment(.trailing)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 120)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Tank Level")
                                .font(.headline)
                            Picker("Tank Reading", selection: $tankReading) {
                                ForEach(availableTankLevels, id: \.value) { level in
                                    Text(level.label).tag(level.value)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                }
                
                Section("Trip & Earnings Data") {
                    HStack {
                        Text("Total Trips")
                        Spacer()
                        TextField("0", text: $totalTrips)
                            #if os(iOS)
                            .keyboardType(.numberPad)
                            #endif
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                    HStack {
                        Text("Net Fare")
                        Spacer()
                        TextField("$0.00", value: $netFare, format: .currency(code: "USD"))
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120)
                    }
                    HStack {
                        Text("Tips")
                        Spacer()
                        TextField("$0.00", value: $tips, format: .currency(code: "USD"))
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120)
                    }
                }
                
                Section("Additional Expenses") {
                    HStack {
                        Text("Total Tolls")
                        Spacer()
                        TextField("$0.00", value: $totalTolls, format: .currency(code: "USD"))
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120)
                    }
                    HStack {
                        Text("Tolls Reimbursed")
                        Spacer()
                        TextField("$0.00", value: $tollsReimbursed, format: .currency(code: "USD"))
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120)
                    }
                    HStack {
                        Text("Parking Fees")
                        Spacer()
                        TextField("$0.00", value: $parkingFees, format: .currency(code: "USD"))
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120)
                    }
                }
            }
            .navigationTitle("End Shift")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar(content: {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        hideKeyboard()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        endShift()
                    }
                    .disabled(endMileage.isEmpty || totalTrips.isEmpty || !odometerError.isEmpty)
                }
            })
    }
    
    #if os(macOS)
    private var endSectionCustom: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Shift End")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 15) {
                HStack {
                    Text("End Date & Time")
                    Spacer()
                    TextField("End Date & Time", value: $endDate, format: .dateTime.month(.abbreviated).day().year().hour().minute())
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 300)
                    
                    Button(action: { showEndDatePicker.toggle() }) {
                        Image(systemName: "calendar")
                    }
                    .buttonStyle(.borderless)
                }
                
                if showEndDatePicker {
                    VStack(spacing: 10) {
                        DatePicker("Date", selection: $endDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                        
                        DatePicker("Time", selection: $endDate, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.compact)
                    }
                    .frame(maxHeight: 120)
                }
                
                HStack {
                    Text("End Odometer Reading")
                    Spacer()
                    TextField("Miles", text: $endMileage)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 120)
                        .onChange(of: endMileage) { _ in
                            validateOdometerReading()
                        }
                }
                
                if !odometerError.isEmpty {
                    Text(odometerError)
                        .foregroundColor(.red)
                        .font(.caption)
                }
                
                HStack {
                    Text("Refueled Tank")
                    Spacer()
                    Toggle("", isOn: $didRefuel)
                }
                
                if didRefuel {
                    HStack {
                        Text("Gallons Filled")
                        Spacer()
                        TextField("Gallons", text: $refuelGallons)
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 120)
                    }
                    HStack {
                        Text("Fuel Cost")
                        Spacer()
                        TextField("$0.00", value: $refuelCost, format: .currency(code: "USD"))
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 120)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tank Level")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Picker("Tank Reading", selection: $tankReading) {
                            ForEach(availableTankLevels, id: \.value) { level in
                                Text(level.label).tag(level.value)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
            }
            .padding()
            .background(Color(.controlBackgroundColor))
            .cornerRadius(0)
        }
    }
    
    private var earningsSectionCustom: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Trip & Earnings Data")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 15) {
                HStack {
                    Text("Total Trips")
                    Spacer()
                    TextField("0", text: $totalTrips)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }
                HStack {
                    Text("Net Fare")
                    Spacer()
                    TextField("$0.00", value: $netFare, format: .currency(code: "USD"))
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 120)
                }
                HStack {
                    Text("Tips")
                    Spacer()
                    TextField("$0.00", value: $tips, format: .currency(code: "USD"))
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 120)
                }
            }
            .padding()
            .background(Color(.controlBackgroundColor))
            .cornerRadius(0)
        }
    }
    
    private var expensesSectionCustom: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Additional Expenses")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 15) {
                HStack {
                    Text("Total Tolls")
                    Spacer()
                    TextField("$0.00", value: $totalTolls, format: .currency(code: "USD"))
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 120)
                }
                HStack {
                    Text("Tolls Reimbursed")
                    Spacer()
                    TextField("$0.00", value: $tollsReimbursed, format: .currency(code: "USD"))
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 120)
                }
                HStack {
                    Text("Parking Fees")
                    Spacer()
                    TextField("$0.00", value: $parkingFees, format: .currency(code: "USD"))
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 120)
                }
            }
            .padding()
            .background(Color(.controlBackgroundColor))
            .cornerRadius(0)
        }
    }
    #endif
    
    private func validateOdometerReading() {
        guard let endMiles = Double(endMileage), endMiles > 0 else {
            odometerError = ""
            return
        }
        
        let startMiles = shift.startMileage
        if endMiles <= startMiles {
            odometerError = "End reading must be greater than start reading (\(String(format: "%.1f", startMiles)) miles)"
        } else {
            odometerError = ""
        }
    }
    
    private func endShift() {
        shift.endDate = endDate
        shift.endMileage = Double(endMileage)
        shift.didRefuelAtEnd = didRefuel
        
        if didRefuel {
            shift.refuelGallons = Double(refuelGallons)
            shift.refuelCost = refuelCost
            shift.endTankReading = 8.0 // Assume full after refuel
        } else {
            shift.endTankReading = tankReading
        }
        
        shift.totalTrips = Int(totalTrips)
        shift.netFare = netFare
        shift.tips = tips
        shift.totalTolls = totalTolls
        shift.tollsReimbursed = tollsReimbursed
        shift.parkingFees = parkingFees
        
        dataManager.updateShift(shift)
        presentationMode.wrappedValue.dismiss()
    }
    
    private func hideKeyboard() {
        #if os(iOS)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }
}
