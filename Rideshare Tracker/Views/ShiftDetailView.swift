//
//  ShiftDetailView.swift
//  Rideshare Tracker
//
//  Created by George on 8/10/25.
//


import SwiftUI

struct ShiftDetailView: View {
    @State var shift: RideshareShift
    @EnvironmentObject var dataManager: ShiftDataManager
    @EnvironmentObject var preferences: AppPreferences
    @State private var showingEndShift = false
    
    var body: some View {
        Form {
            Section("Shift Overview") {
                HStack {
                    Text("Start Time")
                    Spacer()
                    Text(DateFormatter.shortDateTime.string(from: shift.startDate))
                }
                
                if let endDate = shift.endDate {
                    HStack {
                        Text("End Time")
                        Spacer()
                        Text(DateFormatter.shortDateTime.string(from: endDate))
                    }
                    HStack {
                        Text("Duration")
                        Spacer()
                        Text("\(shift.shiftHours)h \(shift.shiftMinutes)m")
                    }
                }
                
                HStack {
                    Text("Start Mileage")
                    Spacer()
                    Text("\(shift.startMileage, specifier: "%.1f") mi")
                }
                
                if let endMileage = shift.endMileage {
                    HStack {
                        Text("End Mileage")
                        Spacer()
                        Text("\(endMileage, specifier: "%.1f") mi")
                    }
                    HStack {
                        Text("Shift Mileage")
                        Spacer()
                        Text("\(shift.shiftMileage, specifier: "%.1f") mi")
                    }
                }
            }
            
            if shift.endDate != nil {
                Section("Trip Data") {
                    HStack {
                        Text("Total Trips")
                        Spacer()
                        Text("\(shift.totalTrips ?? 0)")
                    }
                    HStack {
                        Text("Net Fare")
                        Spacer()
                        Text("$\(shift.netFare ?? 0, specifier: "%.2f")")
                    }
                    HStack {
                        Text("Tips")
                        Spacer()
                        Text("$\(shift.tips ?? 0, specifier: "%.2f")")
                    }
                    HStack {
                        Text("Total Earnings")
                        Spacer()
                        Text("$\(shift.totalEarnings, specifier: "%.2f")")
                            .foregroundColor(.green)
                    }
                }
                
                Section("Expenses") {
                    HStack {
                        Text("Gas Cost")
                        Spacer()
                        Text("$\(shift.shiftGasCost(tankCapacity: preferences.tankCapacity, gasPrice: preferences.gasPrice), specifier: "%.2f")")
                    }
                    HStack {
                        Text("Gas Used")
                        Spacer()
                        Text("\(shift.shiftGasUsage(tankCapacity: preferences.tankCapacity), specifier: "%.1f") gal")
                    }
                    HStack {
                        Text("MPG")
                        Spacer()
                        Text("\(shift.shiftMPG(tankCapacity: preferences.tankCapacity), specifier: "%.1f")")
                    }
                    if let tolls = shift.totalTolls, tolls > 0 {
                        HStack {
                            Text("Total Tolls")
                            Spacer()
                            Text("$\(tolls, specifier: "%.2f")")
                        }
                        HStack {
                            Text("Tolls Reimbursed")
                            Spacer()
                            Text("$\(shift.tollsReimbursed ?? 0, specifier: "%.2f")")
                        }
                    }
                    if let parking = shift.parkingFees, parking > 0 {
                        HStack {
                            Text("Parking Fees")
                            Spacer()
                            Text("$\(parking, specifier: "%.2f")")
                        }
                    }
                }
                
                Section("Financial Summary") {
                    HStack {
                        Text("Total Payment Due")
                        Spacer()
                        Text("$\(shift.totalPaymentDue, specifier: "%.2f")")
                            .foregroundColor(.blue)
                    }
                    HStack {
                        Text("Tax Deductible Expense")
                        Spacer()
                        Text("$\(shift.totalTaxDeductibleExpense(mileageRate: preferences.standardMileageRate), specifier: "%.2f")")
                    }
                    HStack {
                        Text("Total Shift Expenses")
                        Spacer()
                        Text("$\(shift.totalShiftExpenses(tankCapacity: preferences.tankCapacity, gasPrice: preferences.gasPrice), specifier: "%.2f")")
                    }
                    HStack {
                        Text("Net Profit")
                        Spacer()
                        Text("$\(shift.netProfit(mileageRate: preferences.standardMileageRate), specifier: "%.2f")")
                            .foregroundColor(shift.netProfit(mileageRate: preferences.standardMileageRate) >= 0 ? .green : .red)
                    }
                    HStack {
                        Text("Gross Profit")
                        Spacer()
                        Text("$\(shift.grossProfit(tankCapacity: preferences.tankCapacity, gasPrice: preferences.gasPrice), specifier: "%.2f")")
                            .foregroundColor(shift.grossProfit(tankCapacity: preferences.tankCapacity, gasPrice: preferences.gasPrice) >= 0 ? .green : .red)
                    }
                }
            }
        }
        .navigationTitle("Shift Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if shift.endDate == nil {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("End Shift") {
                        showingEndShift = true
                    }
                }
            }
        }
        .sheet(isPresented: $showingEndShift) {
            EndShiftView(shift: $shift)
        }
        .onChange(of: shift) { updatedShift in
            dataManager.updateShift(updatedShift)
        }
    }
}
