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
    @EnvironmentObject var expenseManager: ExpenseDataManager
    @EnvironmentObject var preferences: AppPreferences
    @State private var showingEndShift = false
    @State private var showingEditShift = false
    @State private var showingImageViewer = false
    @State private var selectedImageIndex = 0
    @State private var loadedImages: [UIImage] = []
    @State private var isLoadingImages = false
    @State private var viewerImages: [UIImage] = []
    
    private func formatDateTime(_ date: Date) -> String {
        return "\(preferences.formatDate(date)) \(preferences.formatTime(date))"
    }
    
    // Year-to-date calculations using model methods
    private var currentYear: Int {
        Calendar.current.component(.year, from: shift.startDate)
    }

    private var yearTotalRevenue: Double {
        RideshareShift.calculateYearTotalRevenue(shifts: dataManager.shifts, year: currentYear)
    }

    private var yearTotalTips: Double {
        RideshareShift.calculateYearTotalTips(shifts: dataManager.shifts, year: currentYear)
    }

    private var yearTotalDeductibleTips: Double {
        RideshareShift.calculateYearTotalDeductibleTips(shifts: dataManager.shifts, year: currentYear, tipDeductionEnabled: preferences.tipDeductionEnabled)
    }

    private var yearTotalMileageDeduction: Double {
        RideshareShift.calculateYearTotalMileageDeduction(shifts: dataManager.shifts, year: currentYear, mileageRate: preferences.standardMileageRate)
    }
    
    private var yearTotalExpensesWithoutVehicle: Double {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: shift.startDate)
        return expenseManager.expenses
            .filter { calendar.component(.year, from: $0.date) == currentYear && $0.category != .vehicle }
            .reduce(0) { $0 + $1.amount }
    }
    
    private var yearTotalFuelExpenses: Double {
        let calendar = Calendar.current
        return dataManager.shifts.filter {
            calendar.component(.year, from: $0.startDate) == currentYear && $0.endDate != nil
        }.reduce(0) { $0 + $1.shiftGasCost(tankCapacity: preferences.tankCapacity) }
    }

    private var yearTotalTollExpenses: Double {
        let calendar = Calendar.current
        return dataManager.shifts.filter {
            calendar.component(.year, from: $0.startDate) == currentYear && $0.endDate != nil
        }.reduce(0) { $0 + (($1.tolls ?? 0) - ($1.tollsReimbursed ?? 0)) }
    }

    private var yearTotalTripFees: Double {
        let calendar = Calendar.current
        return dataManager.shifts.filter {
            calendar.component(.year, from: $0.startDate) == currentYear && $0.endDate != nil
        }.reduce(0) { $0 + ($1.parkingFees ?? 0) + ($1.miscFees ?? 0) }
    }
    
    private var yearTotalExpensesWithVehicle: Double {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: shift.startDate)
        return expenseManager.expenses
            .filter { calendar.component(.year, from: $0.date) == currentYear }
            .reduce(0) { $0 + $1.amount }
    }
    
    var body: some View {
        GeometryReader { geometry in
            let isWideScreen = geometry.size.width > 600
            
            ScrollView {
                VStack(spacing: 20) {
                    // Header with date
                    VStack(spacing: 8) {
                        Text(formatDateTime(shift.startDate))
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
                                if !shift.imageAttachments.isEmpty {
                                    photosSection
                                }
                            }
                            
                            // Right Column
                            VStack(spacing: 20) {
                                if shift.endDate != nil {
                                    expensesSection
                                    cashFlowSummarySection
                                    taxSummarySection
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
                                cashFlowSummarySection
                                taxSummarySection
                            }
                            if !shift.imageAttachments.isEmpty {
                                photosSection
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
        .background(Color(.systemGroupedBackground))
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
        .sheet(isPresented: $showingImageViewer) {
            ImageViewerView(
                images: loadShiftImages(),
                startingIndex: selectedImageIndex,
                isPresented: $showingImageViewer
            )
        }
    }
    
    private var shiftOverviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Shift Overview")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 8) {
                DetailRow("Start Date & Time", formatDateTime(shift.startDate))
                
                if let endDate = shift.endDate {
                    DetailRow("End Date & Time", formatDateTime(endDate))
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
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray, lineWidth: 1.0)
            )
        }
    }
    
    private var tripDataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Trip Data")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 8) {
                DetailRow("# Trips", "\(shift.trips ?? 0)")
                DetailRow("Net Fare", String(format: "$%.2f", shift.netFare ?? 0))
                if let promotions = shift.promotions, promotions > 0 {
                    DetailRow("Promotions", String(format: "$%.2f", promotions))
                }
                DetailRow("Tips", String(format: "$%.2f", shift.tips ?? 0))
                DetailRow("Revenue", String(format: "$%.2f", shift.revenue), valueColor: .green)
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray, lineWidth: 1.0)
            )
        }
    }
    
    private var expensesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Expenses")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 8) {
                DetailRow("Gas Cost", String(format: "$%.2f", shift.shiftGasCost(tankCapacity: preferences.tankCapacity)))
                DetailRow("Gas Used", String(format: "%.1f gal", shift.shiftGasUsage(tankCapacity: preferences.tankCapacity)))
                DetailRow("MPG", String(format: "%.1f", shift.shiftMPG(tankCapacity: preferences.tankCapacity)))
                
                // Show gas price used for this shift
                DetailRow("Gas Price Used", String(format: "$%.3f/gal", shift.gasPrice))
                
                if let tolls = shift.tolls, tolls > 0 {
                    DetailRow("Tolls", String(format: "$%.2f", tolls))
                    DetailRow("Tolls Reimbursed", String(format: "$%.2f", shift.tollsReimbursed ?? 0))
                }
                if let parking = shift.parkingFees, parking > 0 {
                    DetailRow("Parking Fees", String(format: "$%.2f", parking))
                }
                if let miscFees = shift.miscFees, miscFees > 0 {
                    DetailRow("Misc Fees", String(format: "$%.2f", miscFees))
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray, lineWidth: 1.0)
            )
        }
    }
    
    private var taxSummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("YTD Tax Summary")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 8) {
                
                let adjustedGrossIncome = RideshareShift.calculateAdjustedGrossIncome(
                    grossIncome: yearTotalRevenue,
                    deductibleTips: yearTotalDeductibleTips
                )
                let selfEmploymentTax = RideshareShift.calculateSelfEmploymentTax(grossIncome: yearTotalRevenue)
                
                DetailRow("Gross Income", String(format: "$%.2f", yearTotalRevenue))

                if AppPreferences.shared.tipDeductionEnabled {
                    DetailRow("Deductible Tip Income†", String(format: "$%.2f", yearTotalDeductibleTips))
                } else {
                    DetailRow("Deductible Tip Income†", "$0.00")
                }

                DetailRow("Adjusted Gross Income", String(format: "$%.2f", adjustedGrossIncome), valueColor: .green)

                // Tax Calculations if Using Mileage Deduction
                Divider()
                    .padding(.vertical, 4)
                
                // Show mileage rate used for this shift
                DetailRow("Mileage Rate Used", String(format: "$%.3f/mi", shift.standardMileageRate))
                DetailRow("Mileage Deduction (This Trip)", String(format: "$%.2f", shift.deductibleExpenses(mileageRate: preferences.standardMileageRate)))
                DetailRow("Total Mileage Deduction", String(format: "$%.2f", yearTotalMileageDeduction))
                DetailRow("Total Expenses (Mileage)", String(format: "$%.2f", yearTotalExpensesWithoutVehicle))
                
                let taxableIncomeUsingMileage = RideshareShift.calculateTaxableIncome(
                    adjustedGrossIncome: adjustedGrossIncome,
                    mileageDeduction: yearTotalMileageDeduction,
                    otherExpenses: yearTotalExpensesWithoutVehicle
                )
                DetailRow("Taxable Income (Mileage)", String(format: "$%.2f", taxableIncomeUsingMileage))

                // Standard Mileage Method Tax Calculations
                let incomeTaxMileage = RideshareShift.calculateIncomeTax(
                    taxableIncome: taxableIncomeUsingMileage,
                    taxRate: AppPreferences.shared.effectivePersonalTaxRate
                )
                let totalTaxMileage = RideshareShift.calculateTotalTax(
                    incomeTax: incomeTaxMileage,
                    selfEmploymentTax: selfEmploymentTax
                )
                
                DetailRow("Income Tax (Mileage)", String(format: "$%.2f", incomeTaxMileage))
                DetailRow("Self-Employment Tax", String(format: "$%.2f", selfEmploymentTax))
                DetailRow("Total Tax Due (Mileage)", String(format: "$%.2f", totalTaxMileage), valueColor: .red)

                // Tax Calculations if Using Actual Auto Expenses
                Divider()
                    .padding(.vertical, 4)

                DetailRow("Total Fuel Costs", String(format: "$%.2f", yearTotalFuelExpenses))
                DetailRow("Total Tolls Not Reimbursed", String(format: "$%.2f", yearTotalTollExpenses))
                DetailRow("Total Trip Fees", String(format: "$%.2f", yearTotalTripFees))
                DetailRow("Total Expenses (Actual)", String(format: "$%.2f", yearTotalExpensesWithVehicle))
                
                let actualExpensesTotal = yearTotalFuelExpenses + yearTotalTollExpenses + yearTotalTripFees + yearTotalExpensesWithVehicle
                let taxableIncomeWithActualExpenses = RideshareShift.calculateTaxableIncome(
                    adjustedGrossIncome: adjustedGrossIncome,
                    mileageDeduction: 0, // No mileage deduction in actual expenses method
                    otherExpenses: actualExpensesTotal
                )
                DetailRow("Taxable Income (Actual)", String(format: "$%.2f", taxableIncomeWithActualExpenses))

                // Actual Expenses Method Tax Calculations
                let incomeTaxActual = RideshareShift.calculateIncomeTax(
                    taxableIncome: taxableIncomeWithActualExpenses,
                    taxRate: AppPreferences.shared.effectivePersonalTaxRate
                )
                let totalTaxActual = RideshareShift.calculateTotalTax(
                    incomeTax: incomeTaxActual,
                    selfEmploymentTax: selfEmploymentTax
                )
                
                DetailRow("Income Tax (Actual)", String(format: "$%.2f", incomeTaxActual))
                DetailRow("Self-Employment Tax", String(format: "$%.2f", selfEmploymentTax))
                DetailRow("Total Tax Due (Actual)", String(format: "$%.2f", totalTaxActual), valueColor: .red)
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray, lineWidth: 1.0)
            )
            
            Text("† Tip deduction capped at $25,000, reduced for high income earners")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
        }
    }
    
    private var cashFlowSummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cash Flow Summary")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 8) {
                DetailRow("Expected Payout", String(format: "$%.2f", shift.expectedPayout), valueColor: .blue)
                DetailRow("Out of Pocket Costs", String(format: "$%.2f", shift.outOfPocketCosts(tankCapacity: preferences.tankCapacity)))
                
                let profit = shift.cashFlowProfit(tankCapacity: preferences.tankCapacity)
                let profitPerHour = shift.profitPerHour(tankCapacity: preferences.tankCapacity)
                
                DetailRow("Cash Flow Profit", String(format: "$%.2f", profit), valueColor: profit >= 0 ? .green : .red)
                DetailRow("Profit/hr", String(format: "$%.2f", profitPerHour), valueColor: profitPerHour >= 0 ? .green : .red)
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray, lineWidth: 1.0)
            )
        }
    }

    private var photosSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Photos")
                .font(.headline)
                .foregroundColor(.primary)

            if shift.imageAttachments.isEmpty {
                Text("No photos attached")
                    .foregroundColor(.secondary)
                    .font(.body)
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray, lineWidth: 1.0)
                    )
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                    ForEach(shift.imageAttachments, id: \.id) { attachment in
                        AsyncImage(url: attachment.fileURL(for: shift.id, parentType: .shift)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray, lineWidth: 1.0)
                                )
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.systemGray5))
                                .frame(width: 80, height: 80)
                                .overlay(
                                    ProgressView()
                                        .scaleEffect(0.7)
                                )
                        }
                        .onTapGesture {
                            // Prevent multiple taps while sheet is already showing
                            guard !showingImageViewer else { return }

                            if let attachmentIndex = shift.imageAttachments.firstIndex(of: attachment) {
                                showImage(at: attachmentIndex)
                            }
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray, lineWidth: 1.0)
                )
            }
        }
    }

    @MainActor
    private func loadShiftImages() -> [UIImage] {

        var images: [UIImage] = []

        for (_, attachment) in shift.imageAttachments.enumerated() {

            if let image = ImageManager.shared.loadImage(
                for: shift.id,
                parentType: .shift,
                filename: attachment.filename
            ) {
                images.append(image)
            } else {
            }
        }

        return images
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

    private func showImage(at index: Int) {
        let shiftImages = loadShiftImages()
        ImageViewingUtilities.showImageViewer(
            images: shiftImages,
            startIndex: index,
            viewerImages: $viewerImages,
            viewerStartIndex: $selectedImageIndex,
            showingImageViewer: $showingImageViewer
        )
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
