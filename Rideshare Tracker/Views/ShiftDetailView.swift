//
//  ShiftDetailView.swift
//  Rideshare Tracker
//
//  Created by George Knaggs with Claude AI assistance on 8/10/25.
//  Optimized for iOS Universal (iPhone, iPad, Mac) on 8/19/25
//

import SwiftUI

struct ShiftDetailView: View {
    @State var shift: RideshareShift
    @EnvironmentObject var dataManager: ShiftDataManager
    @EnvironmentObject var preferences: AppPreferences
    @State private var showingEndShift = false
    @State private var showingEditShift = false
    
    var body: some View {
        GeometryReader { geometry in
            let isWideScreen = geometry.size.width > 600
            
            ScrollView {
                VStack(spacing: 20) {
                    // Header with date
                    VStack(spacing: 8) {
                        Text(DateFormatter.shortDateTime.string(from: shift.startDate))
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    
                    if isWideScreen {
                        // Two-column layout for larger screens
                        HStack(alignment: .top, spacing: 20) {
                            // Left Column
                            VStack(spacing: 20) {
                                shiftOverviewSection
                                if shift.endDate != nil {
                                    tripDataSection
                                }
                            }
                            
                            // Right Column
                            VStack(spacing: 20) {
                                if shift.endDate != nil {
                                    expensesSection
                                    taxSummarySection
                                    cashFlowSummarySection
                                }
                            }
                        }
                        .padding(.horizontal)
                    } else {
                        // Single column layout for smaller screens
                        VStack(spacing: 20) {
                            shiftOverviewSection
                            if shift.endDate != nil {
                                tripDataSection
                                expensesSection
                                taxSummarySection
                                cashFlowSummarySection
                            }
                        }
                        .padding(.horizontal)
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
    
    private var shiftOverviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Shift Overview")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 8) {
                DetailRow("Start Date & Time", DateFormatter.shortDateTime.string(from: shift.startDate))
                
                if let endDate = shift.endDate {
                    DetailRow("End Date & Time", DateFormatter.shortDateTime.string(from: endDate))
                    DetailRow("Duration", "\(shift.shiftHours)h \(shift.shiftMinutes)m")
                }
                
                DetailRow("Start Odometer Reading", "\(shift.startMileage.formattedMileage) mi")
                
                if shift.endDate == nil {
                    DetailRow("Tank Level", tankLevelText(shift.startTankReading))
                }
                
                if let endMileage = shift.endMileage {
                    DetailRow("End Odometer Reading", "\(endMileage.formattedMileage) mi")
                    DetailRow("Shift Mileage", "\(shift.shiftMileage.formattedMileage) mi")
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
    }
    
    private var tripDataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Trip Data")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 8) {
                DetailRow("Total Trips", "\(shift.totalTrips ?? 0)")
                DetailRow("Net Fare", String(format: "$%.2f", shift.netFare ?? 0))
                DetailRow("Tips", String(format: "$%.2f", shift.tips ?? 0))
                DetailRow("Total Earnings", String(format: "$%.2f", shift.totalEarnings), valueColor: .green)
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
    }
    
    private var expensesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Expenses")
                .font(.headline)
                .foregroundColor(.primary)
            
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
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
    }
    
    private var taxSummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tax Summary")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 8) {
                DetailRow("Total Earnings", String(format: "$%.2f", shift.totalEarnings))
                DetailRow("Total Tips", String(format: "$%.2f", shift.totalTips))
                DetailRow("Taxable Income", String(format: "$%.2f", shift.taxableIncome))
                DetailRow("Deductible Expenses", String(format: "$%.2f", shift.deductibleExpenses(mileageRate: preferences.standardMileageRate)))
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
    }
    
    private var cashFlowSummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cash Flow Summary")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 8) {
                DetailRow("Expected Payout", String(format: "$%.2f", shift.expectedPayout), valueColor: .blue)
                DetailRow("Out of Pocket Costs", String(format: "$%.2f", shift.outOfPocketCosts(tankCapacity: preferences.tankCapacity, gasPrice: preferences.gasPrice)))
                
                let profit = shift.profit(tankCapacity: preferences.tankCapacity, gasPrice: preferences.gasPrice)
                let profitPerHour = shift.profitPerHour(tankCapacity: preferences.tankCapacity, gasPrice: preferences.gasPrice)
                
                DetailRow("Profit", String(format: "$%.2f", profit), valueColor: profit >= 0 ? .green : .red)
                DetailRow("Profit/hr", String(format: "$%.2f", profitPerHour), valueColor: profitPerHour >= 0 ? .green : .red)
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
    }
    
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

// Helper view for detail rows
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
                .foregroundColor(.primary)
            Spacer()
            Text(value)
                .foregroundColor(valueColor ?? .secondary)
                .fontWeight(valueColor != nil ? .semibold : .regular)
        }
        .font(.body)
    }
}