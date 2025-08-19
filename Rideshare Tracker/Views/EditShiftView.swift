//
//  EditShiftView.swift
//  Rideshare Tracker
//
//  Created by George Knaggs with Claude AI assistance on 8/10/25.
//  Updated for macOS support on 8/13/25
//

import SwiftUI

struct EditShiftView: View {
    @Binding var shift: RideshareShift
    @EnvironmentObject var dataManager: ShiftDataManager
    @Environment(\.presentationMode) var presentationMode
    
    // Start shift data
    @State private var startDate: Date
    @State private var startMileage: String
    @State private var startTankReading: Double
    @State private var showStartDatePicker = false
    
    // End shift data
    @State private var endDate: Date
    @State private var endMileage: String
    @State private var didRefuel: Bool
    @State private var refuelGallons: String
    @State private var refuelCost: Double?
    @State private var endTankReading: Double
    @State private var totalTrips: String
    @State private var netFare: Double?
    @State private var tips: Double?
    @State private var totalTolls: Double?
    @State private var tollsReimbursed: Double?
    @State private var parkingFees: Double?
    @State private var showEndDatePicker = false
    @State private var odometerError = ""
    
    init(shift: Binding<RideshareShift>) {
        self._shift = shift
        
        // Initialize start shift data
        self._startDate = State(initialValue: shift.wrappedValue.startDate)
        self._startMileage = State(initialValue: String(shift.wrappedValue.startMileage))
        self._startTankReading = State(initialValue: shift.wrappedValue.startTankReading)
        
        // Initialize end shift data
        self._endDate = State(initialValue: shift.wrappedValue.endDate ?? Date())
        self._endMileage = State(initialValue: shift.wrappedValue.endMileage?.description ?? "")
        self._didRefuel = State(initialValue: shift.wrappedValue.didRefuelAtEnd ?? false)
        self._refuelGallons = State(initialValue: shift.wrappedValue.refuelGallons?.description ?? "")
        self._refuelCost = State(initialValue: shift.wrappedValue.refuelCost)
        self._endTankReading = State(initialValue: shift.wrappedValue.endTankReading ?? 8.0)
        self._totalTrips = State(initialValue: shift.wrappedValue.totalTrips?.description ?? "")
        self._netFare = State(initialValue: shift.wrappedValue.netFare)
        self._tips = State(initialValue: shift.wrappedValue.tips)
        self._totalTolls = State(initialValue: shift.wrappedValue.totalTolls)
        self._tollsReimbursed = State(initialValue: shift.wrappedValue.tollsReimbursed)
        self._parkingFees = State(initialValue: shift.wrappedValue.parkingFees)
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
        return allLevels.filter { $0.1 <= startTankReading }
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
                
                Text("Edit Shift")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Save") {
                    saveShift()
                }
                .disabled(startMileage.isEmpty || !odometerError.isEmpty)
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
            mainContent
                .navigationTitle("Edit Shift")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") {
                            hideKeyboard()
                        }
                    }
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") {
                            saveShift()
                        }
                        .disabled(startMileage.isEmpty || !odometerError.isEmpty)
                    }
                }
        }
        #endif
    }
    
    private var mainContent: some View {
        #if os(macOS)
        ScrollView {
            VStack(spacing: 20) {
                startSectionCustom
                
                if shift.endDate != nil {
                    endSectionCustom
                    earningsSectionCustom
                    expensesSectionCustom
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
            startSection
            
            if shift.endDate != nil {
                endSection
                earningsSection
                expensesSection
            }
        }
        #endif
    }
    
    #if os(macOS)
    private var startSectionCustom: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Shift Start")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 15) {
                HStack {
                    Text("Start Date & Time")
                    Spacer()
                    TextField("Start Date & Time", value: $startDate, format: .dateTime.month(.abbreviated).day().year().hour().minute())
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 300)
                    
                    Button(action: { showStartDatePicker.toggle() }) {
                        Image(systemName: "calendar")
                    }
                    .buttonStyle(.borderless)
                }
                
                if showStartDatePicker {
                    VStack(spacing: 10) {
                        DatePicker("Date", selection: $startDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                        
                        DatePicker("Time", selection: $startDate, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.compact)
                    }
                    .frame(maxHeight: 120)
                }
                
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
                    
                    Picker("Tank Reading", selection: $startTankReading) {
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
            .padding()
            .background(Color(.controlBackgroundColor))
            .cornerRadius(0)
        }
    }
    
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
                    Text("End Odometer Reading (miles)")
                    Spacer()
                    TextField("Miles", text: $endMileage)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 120)
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
                        Picker("Tank Reading", selection: $endTankReading) {
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
    
    private var startSection: some View {
        Group {
            Section("Shift Start") {
                #if os(macOS)
                HStack {
                    TextField("Date & Time", value: $startDate, format: .dateTime.month(.abbreviated).day().year().hour().minute())
                        .textFieldStyle(.roundedBorder)
                        .frame(minWidth: 200)
                    
                    Button(action: { showStartDatePicker.toggle() }) {
                        Image(systemName: "calendar")
                    }
                    .buttonStyle(.borderless)
                }
                
                if showStartDatePicker {
                    DatePicker("", selection: $startDate)
                        .datePickerStyle(.graphical)
                        .frame(maxHeight: 300)
                }
                #else
                DatePicker("", selection: $startDate)
                    .datePickerStyle(.compact)
                #endif
            }
            
            Section("Vehicle Information") {
                HStack {
                    Text("Start Odometer Reading (miles)")
                    Spacer()
                    TextField("Miles", text: $startMileage)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        #endif
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tank Level")
                        .font(.headline)
                    
                    Picker("Tank Reading", selection: $startTankReading) {
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
    
    private var endSection: some View {
        Group {
            Section("Shift End") {
                #if os(macOS)
                HStack {
                    TextField("Date & Time", value: $endDate, format: .dateTime.month(.abbreviated).day().year().hour().minute())
                        .textFieldStyle(.roundedBorder)
                        .frame(minWidth: 200)
                    
                    Button(action: { showEndDatePicker.toggle() }) {
                        Image(systemName: "calendar")
                    }
                    .buttonStyle(.borderless)
                }
                                
                if showEndDatePicker {
                    DatePicker("", selection: $endDate)
                        .datePickerStyle(.graphical)
                        .frame(maxHeight: 300)
                }
                #else
                DatePicker("", selection: $endDate)
                    .datePickerStyle(.compact)
                #endif
            }
            
            Section("Vehicle Information") {
                
                HStack {
                    Text("End Odometer Reading (miles)")
                    Spacer()
                    TextField("Miles", text: $endMileage)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        #endif
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)
                        .onSubmit {
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
                            .multilineTextAlignment(.trailing)
                            #endif
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120)
                    }
                    HStack {
                        Text("Fuel Cost")
                        Spacer()
                        TextField("$0.00", value: $refuelCost, format: .currency(code: "USD"))
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            #endif
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tank Level")
                            .font(.headline)
                        Picker("Tank Reading", selection: $endTankReading) {
                            ForEach(availableTankLevels, id: \.value) { level in
                                Text(level.label).tag(level.value)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
            }
        }
    }
    
    private var earningsSection: some View {
        Section("Trip & Earnings Data") {
            HStack {
                Text("Total Trips")
                Spacer()
                TextField("0", text: $totalTrips)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    #endif
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
            }
            HStack {
                Text("Net Fare")
                Spacer()
                TextField("$0.00", value: $netFare, format: .currency(code: "USD"))
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    #endif
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120)
            }
            HStack {
                Text("Tips")
                Spacer()
                TextField("$0.00", value: $tips, format: .currency(code: "USD"))
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    #endif
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120)
            }
        }
    }
    
    private var expensesSection: some View {
        Section("Additional Expenses") {
            HStack {
                Text("Total Tolls")
                Spacer()
                TextField("$0.00", value: $totalTolls, format: .currency(code: "USD"))
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    #endif
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120)
            }
            HStack {
                Text("Tolls Reimbursed")
                Spacer()
                TextField("$0.00", value: $tollsReimbursed, format: .currency(code: "USD"))
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    #endif
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120)
            }
            HStack {
                Text("Parking Fees")
                Spacer()
                TextField("$0.00", value: $parkingFees, format: .currency(code: "USD"))
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    #endif
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120)
            }
        }
    }
    
    
    private func validateOdometerReading() {
        guard let endMiles = Double(endMileage), endMiles > 0 else {
            odometerError = ""
            return
        }
        
        let startMiles = Double(startMileage) ?? 0
        if endMiles <= startMiles {
            odometerError = "End reading must be greater than start reading (\(startMiles.formattedMileage) miles)"
        } else {
            odometerError = ""
        }
    }
    
    private func saveShift() {
        // Update start shift data
        shift.startDate = startDate
        shift.startMileage = Double(startMileage) ?? shift.startMileage
        shift.hasFullTankAtStart = startTankReading == 8.0
        shift.startTankReading = startTankReading
        
        // Update end shift data if shift is completed
        if shift.endDate != nil {
            shift.endDate = endDate
            shift.endMileage = Double(endMileage)
            shift.didRefuelAtEnd = didRefuel
            
            if didRefuel {
                shift.refuelGallons = Double(refuelGallons)
                shift.refuelCost = refuelCost
                shift.endTankReading = 8.0 // Assume full after refuel
            } else {
                shift.endTankReading = endTankReading
            }
            
            shift.totalTrips = Int(totalTrips)
            shift.netFare = netFare
            shift.tips = tips
            shift.totalTolls = totalTolls
            shift.tollsReimbursed = tollsReimbursed
            shift.parkingFees = parkingFees
        }
        
        dataManager.updateShift(shift)
        presentationMode.wrappedValue.dismiss()
    }
    
    private func hideKeyboard() {
        #if os(iOS)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }
}
