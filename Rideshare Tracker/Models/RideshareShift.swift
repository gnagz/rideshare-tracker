//
//  RideshareShift.swift
//  Rideshare Tracker
//
//  Created by George Knaggs with Claude AI assistance on 8/10/25.
//

import Foundation
import UIKit

struct RideshareShift: Codable, Identifiable, Equatable, Hashable {
    var id = UUID()
    
    // Sync metadata
    var createdDate: Date = Date()
    var modifiedDate: Date = Date()
    var deviceID: String = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
    var isDeleted: Bool = false
    
    // Start of shift data
    var startDate: Date
    var startMileage: Double
    var startTankReading: Double // in 8ths
    var hasFullTankAtStart: Bool
    
    // End of shift data
    var endDate: Date?
    var endMileage: Double?
    var endTankReading: Double? // in 8ths
    var didRefuelAtEnd: Bool?
    var refuelGallons: Double?
    var refuelCost: Double?
    
    // Trip and earnings data
    var trips: Int?
    var netFare: Double?
    var tips: Double?
    var promotions: Double?
    var tolls: Double?
    var tollsReimbursed: Double?
    var parkingFees: Double?
    var miscFees: Double?
    
    // Shift-specific rates (captured at shift creation)
    var gasPrice: Double?
    var standardMileageRate: Double?
    
    // Computed properties
    var shiftMileage: Double {
        guard let endMileage = endMileage else { return 0 }
        return endMileage - startMileage
    }
    
    var shiftDuration: TimeInterval {
        guard let endDate = endDate else { return 0 }
        return endDate.timeIntervalSince(startDate)
    }
    
    var shiftHours: Int {
        return Int(shiftDuration / 3600)
    }
    
    var shiftMinutes: Int {
        return Int((shiftDuration.truncatingRemainder(dividingBy: 3600)) / 60)
    }
    
    // Trip Data
    
    // Backward compatibility properties
    var totalTrips: Int? {
        get { trips }
        set { trips = newValue }
    }

    // Tax Summary Properties
    var totalTips: Double {
        return tips ?? 0
    }
    
    var taxableIncome: Double {
        return (netFare ?? 0) + (promotions ?? 0)
    }
    
    var revenue: Double {
        return taxableIncome + (tips ?? 0)
    }
    
    // Keep for backward compatibility in UI
    var totalEarnings: Double {
        return revenue
    }
    
    // Expenses
    
    func shiftGasUsage(tankCapacity: Double) -> Double {
        guard let endTankReading = endTankReading else { return 0 }
        let startGallons = (startTankReading / 8.0) * tankCapacity
        let endGallons = (endTankReading / 8.0) * tankCapacity
        var gasUsed = startGallons - endGallons
        
        // Add refueled amount if applicable
        if let refuelGallons = refuelGallons {
            gasUsed += refuelGallons
        }
        
        return max(gasUsed, 0)
    }
    
    func shiftGasCost(tankCapacity: Double, gasPrice: Double) -> Double {
        if let refuelCost = refuelCost, let refuelGallons = refuelGallons, refuelGallons > 0 {
            // Calculate actual gas price from refuel data
            let actualGasPrice = refuelCost / refuelGallons

            // When refueling, the total gallons pumped includes:
            // 1. Gas used during the shift
            // 2. Gas to "top off" the tank (shortage at start)
            let tankShortageAtStart = tankCapacityShortageAtStart(tankCapacity: tankCapacity)
            let gasUsedForShift = refuelGallons - tankShortageAtStart

            return max(gasUsedForShift * actualGasPrice, 0)
        } else {
            return shiftGasUsage(tankCapacity: tankCapacity) * gasPrice
        }
    }

    private func tankCapacityShortageAtStart(tankCapacity: Double) -> Double {
        let fullTankGallons = tankCapacity
        let startGallons = (startTankReading / 8.0) * tankCapacity
        return max(fullTankGallons - startGallons, 0)
    }
    
    func shiftMPG(tankCapacity: Double) -> Double {
        let gasUsed = shiftGasUsage(tankCapacity: tankCapacity)
        return gasUsed > 0 ? shiftMileage / gasUsed : 0
    }
    
    // Backward compatibility properties
    var totalTolls: Double? {
        get { tolls }
        set { tolls = newValue }
    }
    
    func deductibleExpenses(mileageRate: Double) -> Double {
        let tollExpense = (tolls ?? 0) - (tollsReimbursed ?? 0)
        return (shiftMileage * mileageRate) + tollExpense + (parkingFees ?? 0) + (miscFees ?? 0)
    }
    
    // Keep for backward compatibility
    func totalTaxDeductibleExpense(mileageRate: Double) -> Double {
        return deductibleExpenses(mileageRate: mileageRate)
    }
    
    func directCosts(tankCapacity: Double, gasPrice: Double) -> Double {
        let gasExpense = shiftGasCost(tankCapacity: tankCapacity, gasPrice: gasPrice)
        let tollExpense = (tolls ?? 0) - (tollsReimbursed ?? 0)
        return gasExpense + tollExpense + (parkingFees ?? 0) + (miscFees ?? 0)
    }
    
    // Keep for backward compatibility
    func totalShiftExpenses(tankCapacity: Double, gasPrice: Double) -> Double {
        return directCosts(tankCapacity: tankCapacity, gasPrice: gasPrice)
    }
       
    func grossProfit(tankCapacity: Double, gasPrice: Double) -> Double {
        return revenue - directCosts(tankCapacity: tankCapacity, gasPrice: gasPrice)
    }

    // Cash Flow Summary Properties
    
    var expectedPayout: Double {
        return revenue + (tollsReimbursed ?? 0)
    }
    
    func outOfPocketCosts(tankCapacity: Double, gasPrice: Double) -> Double {
        let gasExpense = shiftGasCost(tankCapacity: tankCapacity, gasPrice: gasPrice)
        return gasExpense + (tolls ?? 0) + (parkingFees ?? 0) + (miscFees ?? 0)
    }
    
    func cashFlowProfit(tankCapacity: Double, gasPrice: Double) -> Double {
        return expectedPayout - outOfPocketCosts(tankCapacity: tankCapacity, gasPrice: gasPrice)
    }
    
    // Keep for backward compatibility
    func profit(tankCapacity: Double, gasPrice: Double) -> Double {
        return cashFlowProfit(tankCapacity: tankCapacity, gasPrice: gasPrice)
    }
    
    func profitPerHour(tankCapacity: Double, gasPrice: Double) -> Double {
        let shiftProfit = cashFlowProfit(tankCapacity: tankCapacity, gasPrice: gasPrice)
        return shiftDuration > 0 ? shiftProfit / (shiftDuration / 3600.0) : 0
    }
    
    // MARK: - Convenience methods using shift-specific rates
    
    func shiftGasCost(tankCapacity: Double) -> Double {
        return shiftGasCost(tankCapacity: tankCapacity, gasPrice: gasPrice ?? AppPreferences.shared.gasPrice)
    }
    
    func totalTaxDeductibleExpense() -> Double {
        return totalTaxDeductibleExpense(mileageRate: standardMileageRate ?? AppPreferences.shared.standardMileageRate)
    }
    
    func directCosts(tankCapacity: Double) -> Double {
        return directCosts(tankCapacity: tankCapacity, gasPrice: gasPrice ?? AppPreferences.shared.gasPrice)
    }
    
    func totalShiftExpenses(tankCapacity: Double) -> Double {
        return totalShiftExpenses(tankCapacity: tankCapacity, gasPrice: gasPrice ?? AppPreferences.shared.gasPrice)
    }
    
    func grossProfit(tankCapacity: Double) -> Double {
        return grossProfit(tankCapacity: tankCapacity, gasPrice: gasPrice ?? AppPreferences.shared.gasPrice)
    }
    
    func deductibleExpenses() -> Double {
        return deductibleExpenses(mileageRate: standardMileageRate ?? AppPreferences.shared.standardMileageRate)
    }
    
    func outOfPocketCosts(tankCapacity: Double) -> Double {
        return outOfPocketCosts(tankCapacity: tankCapacity, gasPrice: gasPrice ?? AppPreferences.shared.gasPrice)
    }
    
    func cashFlowProfit(tankCapacity: Double) -> Double {
        return cashFlowProfit(tankCapacity: tankCapacity, gasPrice: gasPrice ?? AppPreferences.shared.gasPrice)
    }
    
    func profit(tankCapacity: Double) -> Double {
        return profit(tankCapacity: tankCapacity, gasPrice: gasPrice ?? AppPreferences.shared.gasPrice)
    }
    
    func profitPerHour(tankCapacity: Double) -> Double {
        return profitPerHour(tankCapacity: tankCapacity, gasPrice: gasPrice ?? AppPreferences.shared.gasPrice)
    }

    // MARK: - Tax Calculation Methods (moved from view layer)

    static func calculateYearTotalRevenue(shifts: [RideshareShift], year: Int) -> Double {
        let calendar = Calendar.current
        return shifts.filter {
            calendar.component(.year, from: $0.startDate) == year && $0.endDate != nil
        }.reduce(0) { $0 + $1.revenue }
    }

    static func calculateYearTotalTips(shifts: [RideshareShift], year: Int) -> Double {
        let calendar = Calendar.current
        return shifts.filter {
            calendar.component(.year, from: $0.startDate) == year && $0.endDate != nil
        }.reduce(0) { $0 + $1.totalTips }
    }

    static func calculateYearTotalMileageDeduction(shifts: [RideshareShift], year: Int) -> Double {
        let calendar = Calendar.current
        return shifts.filter {
            calendar.component(.year, from: $0.startDate) == year && $0.endDate != nil
        }.reduce(0) { $0 + $1.deductibleExpenses() }
    }

    static func calculateYearTotalDeductibleTips(shifts: [RideshareShift], year: Int) -> Double {
        guard AppPreferences.shared.tipDeductionEnabled else { return 0 }
        let totalTips = calculateYearTotalTips(shifts: shifts, year: year)
        // Apply $25,000 cap on deductible tip income
        return min(totalTips, 25000.0)
    }

    static func calculateAdjustedGrossIncome(grossIncome: Double, deductibleTips: Double) -> Double {
        return grossIncome - deductibleTips
    }

    static func calculateSelfEmploymentTax(grossIncome: Double) -> Double {
        return grossIncome * 0.153
    }

    static func calculateTaxableIncome(adjustedGrossIncome: Double, mileageDeduction: Double, otherExpenses: Double) -> Double {
        return max(0, adjustedGrossIncome - mileageDeduction - otherExpenses)
    }

    static func calculateIncomeTax(taxableIncome: Double, taxRate: Double) -> Double {
        return taxableIncome * (taxRate / 100.0)
    }

    static func calculateTotalTax(incomeTax: Double, selfEmploymentTax: Double) -> Double {
        return incomeTax + selfEmploymentTax
    }
}

// MARK: - Backward Compatibility for Decoding
extension RideshareShift {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode required fields
        id = try container.decode(UUID.self, forKey: .id)
        startDate = try container.decode(Date.self, forKey: .startDate)
        startMileage = try container.decode(Double.self, forKey: .startMileage)
        startTankReading = try container.decode(Double.self, forKey: .startTankReading)
        hasFullTankAtStart = try container.decode(Bool.self, forKey: .hasFullTankAtStart)
        
        // Decode optional fields
        endDate = try container.decodeIfPresent(Date.self, forKey: .endDate)
        endMileage = try container.decodeIfPresent(Double.self, forKey: .endMileage)
        endTankReading = try container.decodeIfPresent(Double.self, forKey: .endTankReading)
        didRefuelAtEnd = try container.decodeIfPresent(Bool.self, forKey: .didRefuelAtEnd)
        refuelGallons = try container.decodeIfPresent(Double.self, forKey: .refuelGallons)
        refuelCost = try container.decodeIfPresent(Double.self, forKey: .refuelCost)
        trips = try container.decodeIfPresent(Int.self, forKey: .trips)
        netFare = try container.decodeIfPresent(Double.self, forKey: .netFare)
        tips = try container.decodeIfPresent(Double.self, forKey: .tips)
        promotions = try container.decodeIfPresent(Double.self, forKey: .promotions)
        tolls = try container.decodeIfPresent(Double.self, forKey: .tolls)
        tollsReimbursed = try container.decodeIfPresent(Double.self, forKey: .tollsReimbursed)
        parkingFees = try container.decodeIfPresent(Double.self, forKey: .parkingFees)
        miscFees = try container.decodeIfPresent(Double.self, forKey: .miscFees)
        
        // Decode shift-specific rates (new fields - backward compatible)
        gasPrice = try container.decodeIfPresent(Double.self, forKey: .gasPrice)
        standardMileageRate = try container.decodeIfPresent(Double.self, forKey: .standardMileageRate)
        
        // Decode sync metadata with backward compatibility
        createdDate = try container.decodeIfPresent(Date.self, forKey: .createdDate) ?? startDate
        modifiedDate = try container.decodeIfPresent(Date.self, forKey: .modifiedDate) ?? endDate ?? startDate
        deviceID = try container.decodeIfPresent(String.self, forKey: .deviceID) ?? UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        isDeleted = try container.decodeIfPresent(Bool.self, forKey: .isDeleted) ?? false
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, createdDate, modifiedDate, deviceID, isDeleted
        case startDate, startMileage, startTankReading, hasFullTankAtStart
        case endDate, endMileage, endTankReading, didRefuelAtEnd, refuelGallons, refuelCost
        case trips, netFare, tips, promotions, tolls, tollsReimbursed, parkingFees, miscFees
        case gasPrice, standardMileageRate
    }
}
