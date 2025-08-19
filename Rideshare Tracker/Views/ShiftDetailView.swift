//
//  ShiftDetailView.swift
//  Rideshare Tracker
//
//  Created by George Knaggs with Claude AI assistance on 8/10/25.
//  Updated for macOS support on 8/13/25
//

import SwiftUI

struct ShiftDetailView: View {
    @State var shift: RideshareShift
    @EnvironmentObject var dataManager: ShiftDataManager
    @EnvironmentObject var preferences: AppPreferences
    @State private var showingEndShift = false
    @State private var showingEditShift = false
    
    var body: some View {
        #if os(macOS)
        macOSView
        #else
        iOSView
        #endif
    }
    
    #if os(macOS)
    var macOSView: some View {
        VStack(spacing: 0) {
            // Header with action buttons
            HStack {
                Text("Shift Details")
                    .font(.largeTitle)
                    .bold()
                
                Spacer()
                
                HStack(spacing: 12) {
                    if shift.endDate == nil {
                        Button("End Shift") {
                            showingEndShift = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    
                    Button("Edit") {
                        showingEditShift = true
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            
            ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 20) {
                // Header with date
                VStack(spacing: 8) {
                    Text(DateFormatter.shortDateTime.string(from: shift.startDate))
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .padding()
                
                HStack(alignment: .top, spacing: 20) {
                    // Left Column
                    VStack(spacing: 20) {
                        // Shift Overview
                        GroupBox("Shift Overview") {
                            VStack(spacing: 8) {
                                DetailRow("Start Date & Time", DateFormatter.shortDateTime.string(from: shift.startDate))
                                
                                if let endDate = shift.endDate {
                                    DetailRow("End Date & Time", DateFormatter.shortDateTime.string(from: endDate))
                                    DetailRow("Duration", "\(shift.shiftHours)h \(shift.shiftMinutes)m")
                                }
                                
                                DetailRow("Start Odometer Reading", "\(shift.startMileage.formattedMileage) mi")
                                
                                if shift.endDate == nil {
                                    // Show tank level for active shifts
                                    DetailRow("Tank Level", tankLevelText(shift.startTankReading))
                                }
                                
                                if let endMileage = shift.endMileage {
                                    DetailRow("End Odometer Reading", "\(endMileage.formattedMileage) mi")
                                    DetailRow("Shift Mileage", "\(shift.shiftMileage.formattedMileage) mi")
                                }
                            }
                            .padding()
                        }
                        
                        if shift.endDate != nil {
                            // Trip Data
                            GroupBox("Trip Data") {
                                VStack(spacing: 8) {
                                    DetailRow("Total Trips", "\(shift.totalTrips ?? 0)")
                                    DetailRow("Net Fare", String(format: "$%.2f", shift.netFare ?? 0))
                                    DetailRow("Tips", String(format: "$%.2f", shift.tips ?? 0))
                                    DetailRow("Total Earnings", String(format: "$%.2f", shift.totalEarnings), valueColor: .green)
                                }
                                .padding()
                            }
                        }
                    }
                    
                    // Right Column
                    VStack(spacing: 20) {
                        if shift.endDate != nil {
                            // Expenses
                            GroupBox("Expenses") {
                                VStack(spacing: 8) {
                                    DetailRow("Gas Cost", String(format: "$%.2f", shift.shiftGasCost(tankCapacity: preferences.tankCapacity, gasPrice: preferences.gasPrice)))
                                    DetailRow("Gas Used", String(format: "%.1f gal", shift.shiftGasUsage(tankCapacity: preferences.tankCapacity)))
                                    DetailRow("MPG", String(format: "%.1f", shift.shiftMPG(tankCapacity: preferences.tankCapacity)))
                                    
                                    if let tolls = shift.totalTolls, tolls > 0 {
                                        DetailRow("Total Tolls", String(format: "$%.2f", tolls))
                                        DetailRow("Tolls Reimbursed", String(format: "$%.2f", shift.tollsReimbursed ?? 0))
                                    }
                                    if let parking = shift.parkingFees, parking > 0 {
                                        DetailRow("Parking Fees", String(format: "$%.2f", parking))
                                    }
                                }
                                .padding()
                            }
                            
                            // Tax Summary
                            GroupBox("Tax Summary") {
                                VStack(spacing: 8) {
                                    DetailRow("Total Earnings", String(format: "$%.2f", shift.totalEarnings))
                                    DetailRow("Total Tips", String(format: "$%.2f", shift.totalTips))
                                    DetailRow("Taxable Income", String(format: "$%.2f", shift.taxableIncome))
                                    DetailRow("Deductible Expenses", String(format: "$%.2f", shift.deductibleExpenses(mileageRate: preferences.standardMileageRate)))
                                }
                                .padding()
                            }
                            
                            // Cash Flow Summary
                            GroupBox("Cash Flow Summary") {
                                VStack(spacing: 8) {
                                    DetailRow("Expected Payout", String(format: "$%.2f", shift.expectedPayout), valueColor: .blue)
                                    DetailRow("Out of Pocket Costs", String(format: "$%.2f", shift.outOfPocketCosts(tankCapacity: preferences.tankCapacity, gasPrice: preferences.gasPrice)))
                                    
                                    let profit = shift.profit(tankCapacity: preferences.tankCapacity, gasPrice: preferences.gasPrice)
                                    let profitPerHour = shift.profitPerHour(tankCapacity: preferences.tankCapacity, gasPrice: preferences.gasPrice)
                                    
                                    DetailRow("Profit", String(format: "$%.2f", profit), valueColor: profit >= 0 ? .green : .red)
                                    DetailRow("Profit/hr", String(format: "$%.2f", profitPerHour), valueColor: profitPerHour >= 0 ? .green : .red)
                                }
                                .padding()
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .sheet(isPresented: $showingEndShift) {
            EndShiftView(shift: $shift)
        }
        .sheet(isPresented: $showingEditShift) {
            EditShiftView(shift: $shift)
        }
        }
    }
    #endif
    
    #if os(iOS)
    var iOSView: some View {
        Form {
            Section("Shift Overview") {
                HStack {
                    Text("Start Date & Time")
                    Spacer()
                    Text(DateFormatter.shortDateTime.string(from: shift.startDate))
                }
                
                if let endDate = shift.endDate {
                    HStack {
                        Text("End Date & Time")
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
                    Text("Start Odometer Reading")
                    Spacer()
                    Text("\(shift.startMileage.formattedMileage) mi")
                }
                
                if shift.endDate == nil {
                    HStack {
                        Text("Tank Level")
                        Spacer()
                        Text(tankLevelText(shift.startTankReading))
                    }
                }
                
                if let endMileage = shift.endMileage {
                    HStack {
                        Text("End Odometer Reading")
                        Spacer()
                        Text("\(endMileage.formattedMileage) mi")
                    }
                    HStack {
                        Text("Shift Mileage")
                        Spacer()
                        Text("\(shift.shiftMileage.formattedMileage) mi")
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
                
                Section("Tax Summary") {
                    HStack {
                        Text("Total Earnings")
                        Spacer()
                        Text("$\(shift.totalEarnings, specifier: "%.2f")")
                    }
                    HStack {
                        Text("Total Tips")
                        Spacer()
                        Text("$\(shift.totalTips, specifier: "%.2f")")
                    }
                    HStack {
                        Text("Taxable Income")
                        Spacer()
                        Text("$\(shift.taxableIncome, specifier: "%.2f")")
                    }
                    HStack {
                        Text("Deductible Expenses")
                        Spacer()
                        Text("$\(shift.deductibleExpenses(mileageRate: preferences.standardMileageRate), specifier: "%.2f")")
                    }
                }
                
                Section("Cash Flow Summary") {
                    HStack {
                        Text("Expected Payout")
                        Spacer()
                        Text("$\(shift.expectedPayout, specifier: "%.2f")")
                            .foregroundColor(.blue)
                    }
                    HStack {
                        Text("Out of Pocket Costs")
                        Spacer()
                        Text("$\(shift.outOfPocketCosts(tankCapacity: preferences.tankCapacity, gasPrice: preferences.gasPrice), specifier: "%.2f")")
                    }
                    HStack {
                        Text("Profit")
                        Spacer()
                        let profit = shift.profit(tankCapacity: preferences.tankCapacity, gasPrice: preferences.gasPrice)
                        Text("$\(profit, specifier: "%.2f")")
                            .foregroundColor(profit >= 0 ? .green : .red)
                    }
                    HStack {
                        Text("Profit/hr")
                        Spacer()
                        let profitPerHour = shift.profitPerHour(tankCapacity: preferences.tankCapacity, gasPrice: preferences.gasPrice)
                        Text("$\(profitPerHour, specifier: "%.2f")")
                            .foregroundColor(profitPerHour >= 0 ? .green : .red)
                    }
                }
            }
        }
        .navigationTitle("Shift Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                if shift.endDate == nil {
                    Button("End Shift") {
                        showingEndShift = true
                    }
                }
                
                Button("Edit") {
                    showingEditShift = true
                }
            }
        }
        .sheet(isPresented: $showingEndShift) {
            EndShiftView(shift: $shift)
        }
        .sheet(isPresented: $showingEditShift) {
            EditShiftView(shift: $shift)
        }
    }
    #endif
    
    private func tankLevelText(_ reading: Double) -> String {
        switch reading {
        case 0.0: return "E"
        case 1.0: return "1/8"
        case 2.0: return "1/4"
        case 3.0: return "3/8"
        case 4.0: return "1/2"
        case 5.0: return "5/8"
        case 6.0: return "3/4"
        case 7.0: return "7/8"
        case 8.0: return "F"
        default: return "\(Int(reading))/8"
        }
    }
}

// Helper view for macOS detail rows
struct DetailRow: View {
    let label: String
    let value: String
    let valueColor: Color?
    
    init(_ label: String, _ value: String, valueColor: Color? = nil) {
        self.label = label
        self.value = value
        self.valueColor = valueColor
    }
    
    var body: some View {
        HStack {
            Text(label)
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer()
            Text(value)
                .foregroundColor(valueColor ?? .primary)
                .fontWeight(valueColor != nil ? .semibold : .regular)
        }
    }
}
