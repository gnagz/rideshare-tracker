//
//  EndShiftView.swift
//  Rideshare Tracker
//
//  Created by George Knaggs with Claude AI assistance on 8/10/25.
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
    @State private var promotions: Double? = nil
    @State private var totalTolls: Double? = nil
    @State private var tollsReimbursed: Double? = nil
    @State private var parkingFees: Double? = nil
    @State private var miscFees: Double? = nil
    @State private var odometerError = ""
    @State private var showEndDatePicker = false
    @State private var showEndTimePicker = false
    @FocusState private var focusedField: FocusedField?
    
    enum FocusedField {
        case endMileage, refuelGallons, refuelCost, trips, netFare, tips, promotions, totalTolls, tollsReimbursed, parkingFees, miscFees
    }
    
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
        NavigationView {
            formContent
        }
    }
    
    private var mainContent: some View {
        formContent
    }
    
    private var formContent: some View {
        Form {
                Section("Shift End") {
                    Button(action: { showEndDatePicker.toggle() }) {
                        HStack {
                            Text("Date")
                                .foregroundColor(.primary)
                            Spacer()
                            Text(preferences.formatDate(endDate))
                                .foregroundColor(.primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                    }
                    
                    if showEndDatePicker {
                        DatePicker("", selection: $endDate, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .labelsHidden()
                    }
                    
                    Button(action: { showEndTimePicker.toggle() }) {
                        HStack {
                            Text("Time")
                                .foregroundColor(.primary)
                            Spacer()
                            Text(preferences.formatTime(endDate))
                                .foregroundColor(.primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                    }
                    
                    if showEndTimePicker {
                        DatePicker("", selection: $endDate, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                    }
                }
                
                Section("Vehicle Information") {
                    HStack {
                        Text("End Odometer Reading")
                        Spacer()
                        CalculatorTextField(placeholder: "Miles", value: Binding(
                            get: { Double(endMileage) ?? 0.0 },
                            set: { newValue in 
                                endMileage = newValue > 0 ? String(newValue) : ""
                                validateOdometerReading()
                            }
                        ), formatter: .mileage, keyboardType: .decimalPad)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120)
                            .focused($focusedField, equals: .endMileage)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(focusedField == .endMileage ? Color.accentColor : Color.clear, lineWidth: 2)
                            )
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
                            CalculatorTextField(placeholder: "Gallons", value: Binding(
                                    get: { Double(refuelGallons) ?? 0.0 },
                                    set: { newValue in refuelGallons = newValue > 0 ? String(newValue) : "" }
                                ), formatter: .gallons, keyboardType: .decimalPad)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 120)
                                .focused($focusedField, equals: .refuelGallons)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(focusedField == .refuelGallons ? Color.accentColor : Color.clear, lineWidth: 2)
                                )
                        }
                        HStack {
                            Text("Fuel Cost")
                            Spacer()
                            CurrencyTextField(placeholder: "$0.00", value: $refuelCost)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 120)
                                .focused($focusedField, equals: .refuelCost)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(focusedField == .refuelCost ? Color.accentColor : Color.clear, lineWidth: 2)
                                )
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
                        Text("# Trips")
                        Spacer()
                        CalculatorTextField(placeholder: "0", intValue: Binding(
                                get: { Int(totalTrips) },
                                set: { newValue in totalTrips = newValue != nil && newValue! > 0 ? String(newValue!) : "" }
                            ), keyboardType: .numberPad)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                            .focused($focusedField, equals: .trips)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(focusedField == .trips ? Color.accentColor : Color.clear, lineWidth: 2)
                            )
                    }
                    HStack {
                        Text("Net Fare")
                        Spacer()
                        CurrencyTextField(placeholder: "$0.00", value: $netFare)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120)
                            .focused($focusedField, equals: .netFare)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(focusedField == .netFare ? Color.accentColor : Color.clear, lineWidth: 2)
                            )
                    }
                    HStack {
                        Text("Promotions")
                        Spacer()
                        CurrencyTextField(placeholder: "$0.00", value: $promotions)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120)
                            .focused($focusedField, equals: .promotions)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(focusedField == .promotions ? Color.accentColor : Color.clear, lineWidth: 2)
                            )
                    }
                    HStack {
                        Text("Tips")
                        Spacer()
                        CurrencyTextField(placeholder: "$0.00", value: $tips)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120)
                            .focused($focusedField, equals: .tips)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(focusedField == .tips ? Color.accentColor : Color.clear, lineWidth: 2)
                            )
                    }
                }
                
                Section("Additional Expenses") {
                    HStack {
                        Text("Tolls")
                        Spacer()
                        CurrencyTextField(placeholder: "$0.00", value: $totalTolls)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120)
                            .focused($focusedField, equals: .totalTolls)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(focusedField == .totalTolls ? Color.accentColor : Color.clear, lineWidth: 2)
                            )
                    }
                    HStack {
                        Text("Tolls Reimbursed")
                        Spacer()
                        CurrencyTextField(placeholder: "$0.00", value: $tollsReimbursed)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120)
                            .focused($focusedField, equals: .tollsReimbursed)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(focusedField == .tollsReimbursed ? Color.accentColor : Color.clear, lineWidth: 2)
                            )
                    }
                    HStack {
                        Text("Parking Fees")
                        Spacer()
                        CurrencyTextField(placeholder: "$0.00", value: $parkingFees)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120)
                            .focused($focusedField, equals: .parkingFees)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(focusedField == .parkingFees ? Color.accentColor : Color.clear, lineWidth: 2)
                            )
                    }
                    HStack {
                        Text("Misc Fees")
                        Spacer()
                        CurrencyTextField(placeholder: "$0.00", value: $miscFees)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120)
                            .focused($focusedField, equals: .miscFees)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(focusedField == .miscFees ? Color.accentColor : Color.clear, lineWidth: 2)
                            )
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
        
        shift.trips = Int(totalTrips)
        shift.netFare = netFare
        shift.tips = tips
        shift.promotions = promotions
        shift.tolls = totalTolls
        shift.tollsReimbursed = tollsReimbursed
        shift.parkingFees = parkingFees
        shift.miscFees = miscFees
        
        // Set gas price from refuel data if available, otherwise use preferences
        if didRefuel, let cost = refuelCost, let gallons = Double(refuelGallons), gallons > 0 {
            shift.gasPrice = cost / gallons  // Calculate from actual refuel
        } else {
            shift.gasPrice = preferences.gasPrice  // Use preference as fallback
        }

        // Always capture current mileage rate when ending shift
        shift.standardMileageRate = preferences.standardMileageRate
        
        dataManager.updateShift(shift)
        presentationMode.wrappedValue.dismiss()
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
