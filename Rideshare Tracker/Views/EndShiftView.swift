//
//  EndShiftView.swift
//  Rideshare Tracker
//
//  Created by George on 8/10/25.
//


import SwiftUI

struct EndShiftView: View {
    @Binding var shift: RideshareShift
    @EnvironmentObject var dataManager: ShiftDataManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var endDate = Date()
    @State private var endMileage = ""
    @State private var didRefuel = false
    @State private var refuelGallons = ""
    @State private var refuelCost = ""
    @State private var tankReading = 8.0
    @State private var totalTrips = ""
    @State private var netFare = ""
    @State private var tips = ""
    @State private var totalTolls = ""
    @State private var tollsReimbursed = ""
    @State private var parkingFees = ""
    
    var body: some View {
        NavigationView {
            Form {
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
            .navigationTitle("End Shift")
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
                        endShift()
                    }
                    .disabled(endMileage.isEmpty || totalTrips.isEmpty)
                }
            }
        }
    }
    
    private func endShift() {
        shift.endDate = endDate
        shift.endMileage = Double(endMileage)
        shift.didRefuelAtEnd = didRefuel
        
        if didRefuel {
            shift.refuelGallons = Double(refuelGallons)
            shift.refuelCost = Double(refuelCost)
            shift.endTankReading = 8.0 // Assume full after refuel
        } else {
            shift.endTankReading = tankReading
        }
        
        shift.totalTrips = Int(totalTrips)
        shift.netFare = Double(netFare)
        shift.tips = Double(tips)
        shift.totalTolls = totalTolls.isEmpty ? nil : Double(totalTolls)
        shift.tollsReimbursed = tollsReimbursed.isEmpty ? nil : Double(tollsReimbursed)
        shift.parkingFees = parkingFees.isEmpty ? nil : Double(parkingFees)
        
        dataManager.updateShift(shift)
        presentationMode.wrappedValue.dismiss()
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
