//
//  EditShiftView.swift
//  Rideshare Tracker
//
//  Created by George Knaggs with Claude AI assistance on 8/10/25.
//

import SwiftUI

struct EditShiftView: View {
    @Binding var shift: RideshareShift
    @EnvironmentObject var dataManager: ShiftDataManager
    @Environment(\.presentationMode) var presentationMode
    
    // Start shift data
    @State private var startDate: Date
    @State private var startMileage: String
    @State private var hasFullTankAtStart: Bool
    @State private var startTankReading: Double
    
    // End shift data
    @State private var endDate: Date
    @State private var endMileage: String
    @State private var didRefuel: Bool
    @State private var refuelGallons: String
    @State private var refuelCost: String
    @State private var endTankReading: Double
    @State private var totalTrips: String
    @State private var netFare: String
    @State private var tips: String
    @State private var totalTolls: String
    @State private var tollsReimbursed: String
    @State private var parkingFees: String
    
    init(shift: Binding<RideshareShift>) {
        self._shift = shift
        
        // Initialize start shift data
        self._startDate = State(initialValue: shift.wrappedValue.startDate)
        self._startMileage = State(initialValue: String(shift.wrappedValue.startMileage))
        self._hasFullTankAtStart = State(initialValue: shift.wrappedValue.hasFullTankAtStart)
        self._startTankReading = State(initialValue: shift.wrappedValue.startTankReading)
        
        // Initialize end shift data
        self._endDate = State(initialValue: shift.wrappedValue.endDate ?? Date())
        self._endMileage = State(initialValue: shift.wrappedValue.endMileage?.description ?? "")
        self._didRefuel = State(initialValue: shift.wrappedValue.didRefuelAtEnd ?? false)
        self._refuelGallons = State(initialValue: shift.wrappedValue.refuelGallons?.description ?? "")
        self._refuelCost = State(initialValue: shift.wrappedValue.refuelCost?.description ?? "")
        self._endTankReading = State(initialValue: shift.wrappedValue.endTankReading ?? 8.0)
        self._totalTrips = State(initialValue: shift.wrappedValue.totalTrips?.description ?? "")
        self._netFare = State(initialValue: shift.wrappedValue.netFare?.description ?? "")
        self._tips = State(initialValue: shift.wrappedValue.tips?.description ?? "")
        self._totalTolls = State(initialValue: shift.wrappedValue.totalTolls?.description ?? "")
        self._tollsReimbursed = State(initialValue: shift.wrappedValue.tollsReimbursed?.description ?? "")
        self._parkingFees = State(initialValue: shift.wrappedValue.parkingFees?.description ?? "")
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Shift Start Time") {
                    DatePicker("", selection: $startDate)
                        .datePickerStyle(.compact)
                }
                
                Section("Vehicle Information") {
                    HStack {
                        Text("Current Odometer Reading")
                        Spacer()
                        TextField("Miles", text: $startMileage)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                    }
                    
                    Toggle("Full Tank of Gas", isOn: $hasFullTankAtStart)
                    
                    if !hasFullTankAtStart {
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
                            .pickerStyle(SegmentedPickerStyle())
                        }
                    }
                }
                
                if shift.endDate != nil {
                    Section("Shift End Time") {
                        DatePicker("", selection: $endDate)
                            .datePickerStyle(.compact)
                    }
                    
                    Section("Vehicle Information") {
                        HStack {
                            Text("End Odometer Reading")
                            Spacer()
                            TextField("Miles", text: $endMileage)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 100)
                        }
                        
                        Toggle("Refueled Tank", isOn: $didRefuel)
                        
                        if didRefuel {
                            HStack {
                                Text("Gallons Filled")
                                Spacer()
                                TextField("Gallons", text: $refuelGallons)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 80)
                            }
                            HStack {
                                Text("Fuel Cost")
                                Spacer()
                                TextField("$0.00", text: $refuelCost)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 80)
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Tank Level")
                                    .font(.headline)
                                Picker("Tank Reading", selection: $endTankReading) {
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
                                .pickerStyle(SegmentedPickerStyle())
                            }
                        }
                    }
                    
                    Section("Trip & Earnings Data") {
                        HStack {
                            Text("Total Trips")
                            Spacer()
                            TextField("0", text: $totalTrips)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)
                        }
                        HStack {
                            Text("Net Fare")
                            Spacer()
                            TextField("$0.00", text: $netFare)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                        }
                        HStack {
                            Text("Tips")
                            Spacer()
                            TextField("$0.00", text: $tips)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                        }
                    }
                    
                    Section("Additional Expenses") {
                        HStack {
                            Text("Total Tolls")
                            Spacer()
                            TextField("$0.00", text: $totalTolls)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                        }
                        HStack {
                            Text("Tolls Reimbursed")
                            Spacer()
                            TextField("$0.00", text: $tollsReimbursed)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                        }
                        HStack {
                            Text("Parking Fees")
                            Spacer()
                            TextField("$0.00", text: $parkingFees)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                        }
                    }
                }
            }
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
                    .disabled(startMileage.isEmpty)
                }
            }
        }
    }
    
    private func saveShift() {
        // Update start shift data
        shift.startDate = startDate
        shift.startMileage = Double(startMileage) ?? shift.startMileage
        shift.hasFullTankAtStart = hasFullTankAtStart
        shift.startTankReading = hasFullTankAtStart ? 8.0 : startTankReading
        
        // Update end shift data if shift is completed
        if shift.endDate != nil {
            shift.endDate = endDate
            shift.endMileage = Double(endMileage)
            shift.didRefuelAtEnd = didRefuel
            
            if didRefuel {
                shift.refuelGallons = Double(refuelGallons)
                shift.refuelCost = Double(refuelCost)
                shift.endTankReading = 8.0 // Assume full after refuel
            } else {
                shift.endTankReading = endTankReading
            }
            
            shift.totalTrips = Int(totalTrips)
            shift.netFare = Double(netFare)
            shift.tips = Double(tips)
            shift.totalTolls = totalTolls.isEmpty ? nil : Double(totalTolls)
            shift.tollsReimbursed = tollsReimbursed.isEmpty ? nil : Double(tollsReimbursed)
            shift.parkingFees = parkingFees.isEmpty ? nil : Double(parkingFees)
        }
        
        dataManager.updateShift(shift)
        presentationMode.wrappedValue.dismiss()
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
