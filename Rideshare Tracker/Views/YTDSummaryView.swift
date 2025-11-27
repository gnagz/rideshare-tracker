//
//  YTDSummaryView.swift
//  Rideshare Tracker
//
//  Created by George Knaggs in collaboration with Claude AI on 11/26/25.
//

import SwiftUI

struct YTDSummaryView: View {
    @EnvironmentObject var preferencesManager: PreferencesManager
    @EnvironmentObject var dataManager: ShiftDataManager
    @EnvironmentObject var expenseManager: ExpenseDataManager
    @State private var selectedYear: Int
    @State private var showingMainMenu = false

    private var preferences: AppPreferences { preferencesManager.preferences }

    init() {
        _selectedYear = State(initialValue: Calendar.current.component(.year, from: Date()))
    }

    // MARK: - Available Years

    private var availableYears: [Int] {
        let years = RideshareShift.getAvailableYears(shifts: dataManager.shifts)
        if years.isEmpty {
            return [Calendar.current.component(.year, from: Date())]
        }
        return years
    }

    // MARK: - Section 1: YTD Income

    private var totalBusinessRevenue: Double {
        RideshareShift.calculateYearTotalBusinessRevenue(shifts: dataManager.shifts, year: selectedYear)
    }

    private var totalTips: Double {
        RideshareShift.calculateYearTotalTips(shifts: dataManager.shifts, year: selectedYear)
    }

    private var deductibleTipIncome: Double {
        RideshareShift.calculateYearTotalDeductibleTips(
            shifts: dataManager.shifts,
            year: selectedYear,
            tipDeductionEnabled: preferences.tipDeductionEnabled
        )
    }

    // MARK: - Section 2: Mileage Deduction Method

    private var mileageRate: Double {
        RideshareShift.getMileageRateForYear(selectedYear, shifts: dataManager.shifts, currentRate: preferences.standardMileageRate)
    }

    private var totalMileage: Double {
        RideshareShift.calculateYearTotalMileage(shifts: dataManager.shifts, year: selectedYear)
    }

    private var standardMileageDeduction: Double {
        totalMileage * mileageRate
    }

    private var totalNonVehicleExpenses: Double {
        let calendar = Calendar.current
        return expenseManager.expenses
            .filter { calendar.component(.year, from: $0.date) == selectedYear && $0.category != .vehicle && !$0.isDeleted }
            .reduce(0) { $0 + $1.amount }
    }

    private var mileageBusinessDeductions: Double {
        standardMileageDeduction + totalNonVehicleExpenses
    }

    private var mileageSENetEarnings: Double {
        max(0, totalBusinessRevenue - mileageBusinessDeductions)
    }

    private var mileageSETaxableEarnings: Double {
        RideshareShift.calculateSETaxableEarnings(netEarnings: mileageSENetEarnings)
    }

    private var mileageSETax: Double {
        RideshareShift.calculateSETax(taxableEarnings: mileageSETaxableEarnings)
    }

    private var mileageAGI: Double {
        RideshareShift.calculateAGI(netEarnings: mileageSENetEarnings, seTax: mileageSETax)
    }

    private var mileageTaxableIncome: Double {
        RideshareShift.calculateYTDTaxableIncome(agi: mileageAGI, deductibleTips: deductibleTipIncome)
    }

    private var mileageIncomeTax: Double {
        RideshareShift.calculateIncomeTax(taxableIncome: mileageTaxableIncome, taxRate: preferences.effectivePersonalTaxRate)
    }

    private var mileageTotalTaxDue: Double {
        RideshareShift.calculateTotalTaxDue(seTax: mileageSETax, incomeTax: mileageIncomeTax)
    }

    // MARK: - Section 3: Actual Expenses Method

    private var totalFuelCosts: Double {
        let calendar = Calendar.current
        return dataManager.shifts.filter {
            calendar.component(.year, from: $0.startDate) == selectedYear && $0.endDate != nil && !$0.isDeleted
        }.reduce(0) { $0 + $1.shiftGasCost(tankCapacity: preferences.tankCapacity) }
    }

    private var totalTollsNotReimbursed: Double {
        RideshareShift.calculateYearTotalTollsNotReimbursed(shifts: dataManager.shifts, year: selectedYear)
    }

    private var totalTripFees: Double {
        RideshareShift.calculateYearTotalTripFees(shifts: dataManager.shifts, year: selectedYear)
    }

    private var totalBusinessExpenses: Double {
        let calendar = Calendar.current
        return expenseManager.expenses
            .filter { calendar.component(.year, from: $0.date) == selectedYear && !$0.isDeleted }
            .reduce(0) { $0 + $1.amount }
    }

    private var actualBusinessDeductions: Double {
        totalFuelCosts + totalTollsNotReimbursed + totalTripFees + totalBusinessExpenses
    }

    private var actualSENetEarnings: Double {
        max(0, totalBusinessRevenue - actualBusinessDeductions)
    }

    private var actualSETaxableEarnings: Double {
        RideshareShift.calculateSETaxableEarnings(netEarnings: actualSENetEarnings)
    }

    private var actualSETax: Double {
        RideshareShift.calculateSETax(taxableEarnings: actualSETaxableEarnings)
    }

    private var actualAGI: Double {
        RideshareShift.calculateAGI(netEarnings: actualSENetEarnings, seTax: actualSETax)
    }

    private var actualTaxableIncome: Double {
        RideshareShift.calculateYTDTaxableIncome(agi: actualAGI, deductibleTips: deductibleTipIncome)
    }

    private var actualIncomeTax: Double {
        RideshareShift.calculateIncomeTax(taxableIncome: actualTaxableIncome, taxRate: preferences.effectivePersonalTaxRate)
    }

    private var actualTotalTaxDue: Double {
        RideshareShift.calculateTotalTaxDue(seTax: actualSETax, incomeTax: actualIncomeTax)
    }

    // MARK: - Body

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    yearSelectorSection
                    ytdIncomeSection
                    mileageDeductionSection
                    actualExpensesSection
                    footnotesSection
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("YTD Tax Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingMainMenu = true }) {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showingMainMenu) {
                MainMenuView()
            }
        }
    }

    // MARK: - Year Selector

    private var yearSelectorSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(availableYears, id: \.self) { year in
                    Button(action: { selectedYear = year }) {
                        Text(String(year))
                            .font(.headline)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(selectedYear == year ? Color.blue : Color(.systemGray5))
                            .foregroundColor(selectedYear == year ? .white : .primary)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }

    // MARK: - Section 1: YTD Income

    private var ytdIncomeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("YTD Income")
                .font(.headline)
                .foregroundColor(.primary)

            VStack(spacing: 8) {
                DetailRow("Total Business Revenue", String(format: "$%.2f", totalBusinessRevenue))
                if preferences.tipDeductionEnabled {
                    DetailRow("Deductible Tip Income†", String(format: "$%.2f", deductibleTipIncome))
                } else {
                    DetailRow("Deductible Tip Income†", "$0.00")
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

    // MARK: - Section 2: Mileage Deduction

    private var mileageDeductionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tax Summary using Mileage Deduction")
                .font(.headline)
                .foregroundColor(.primary)

            VStack(spacing: 8) {
                DetailRow("Standard Mileage Rate", String(format: "$%.3f/mi", mileageRate))
                DetailRow("Total Mileage", String(format: "%.1f mi", totalMileage))
                DetailRow("Standard Mileage Deduction", String(format: "$%.2f", standardMileageDeduction))
                DetailRow("Total Non-Vehicle Expenses‡", String(format: "$%.2f", totalNonVehicleExpenses))
                DetailRow("Total Business Deductions", String(format: "$%.2f", mileageBusinessDeductions))

                Divider().padding(.vertical, 4)

                DetailRow("Self-Employment (SE) Net Earnings", String(format: "$%.2f", mileageSENetEarnings))
                DetailRow("SE Taxable Earnings", String(format: "$%.2f", mileageSETaxableEarnings))
                DetailRow("SE Tax", String(format: "$%.2f", mileageSETax))
                DetailRow("Adjusted Gross Income*", String(format: "$%.2f", mileageAGI))
                DetailRow("Taxable Income", String(format: "$%.2f", mileageTaxableIncome))
                DetailRow("Income Tax", String(format: "$%.2f", mileageIncomeTax))
                DetailRow("Total Tax Due", String(format: "$%.2f", mileageTotalTaxDue), valueColor: .red)
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

    // MARK: - Section 3: Actual Expenses

    private var actualExpensesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tax Summary using Actual Expenses")
                .font(.headline)
                .foregroundColor(.primary)

            VStack(spacing: 8) {
                DetailRow("Total Fuel Costs", String(format: "$%.2f", totalFuelCosts))
                DetailRow("Total Tolls Not Reimbursed", String(format: "$%.2f", totalTollsNotReimbursed))
                DetailRow("Total Trip Fees", String(format: "$%.2f", totalTripFees))
                DetailRow("Total Business Expenses", String(format: "$%.2f", totalBusinessExpenses))
                DetailRow("Total Business Deductions", String(format: "$%.2f", actualBusinessDeductions))

                Divider().padding(.vertical, 4)

                DetailRow("Self-Employment (SE) Net Earnings", String(format: "$%.2f", actualSENetEarnings))
                DetailRow("SE Taxable Earnings", String(format: "$%.2f", actualSETaxableEarnings))
                DetailRow("SE Tax", String(format: "$%.2f", actualSETax))
                DetailRow("Adjusted Gross Income*", String(format: "$%.2f", actualAGI))
                DetailRow("Taxable Income", String(format: "$%.2f", actualTaxableIncome))
                DetailRow("Income Tax", String(format: "$%.2f", actualIncomeTax))
                DetailRow("Total Tax Due", String(format: "$%.2f", actualTotalTaxDue), valueColor: .red)
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

    // MARK: - Footnotes

    private var footnotesSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("* Other income sources, tax credits and deductions are not reflected in this calculation")
                .font(.caption)
                .foregroundColor(.secondary)
            Text("† Tip deduction capped at $25,000, reduced for high income earners")
                .font(.caption)
                .foregroundColor(.secondary)
            Text("‡ Vehicle expenses are included in the Standard Mileage Deduction")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
    }
}
