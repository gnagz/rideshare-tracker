//
//  RideshareShift.swift
//  Rideshare Tracker
//
//  Created by George Knaggs with Claude AI assistance on 8/10/25.
//

import Foundation

struct RideshareShift: Codable, Identifiable, Equatable, Hashable {
    var id = UUID()
    
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
    var totalTrips: Int?
    var netFare: Double?
    var tips: Double?
    var totalTolls: Double?
    var tollsReimbursed: Double?
    var parkingFees: Double?
    
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
        if let refuelCost = refuelCost {
            return refuelCost
        } else {
            return shiftGasUsage(tankCapacity: tankCapacity) * gasPrice
        }
    }
    
    func shiftMPG(tankCapacity: Double) -> Double {
        let gasUsed = shiftGasUsage(tankCapacity: tankCapacity)
        return gasUsed > 0 ? shiftMileage / gasUsed : 0
    }
    
    var totalEarnings: Double {
        return (netFare ?? 0) + (tips ?? 0)
    }
    
    var totalPaymentDue: Double {
        return totalEarnings + (tollsReimbursed ?? 0)
    }
    
    func totalTaxDeductibleExpense(mileageRate: Double) -> Double {
        return (parkingFees ?? 0) + (shiftMileage * mileageRate)
    }
    
    func totalShiftExpenses(tankCapacity: Double, gasPrice: Double) -> Double {
        let gasExpense = shiftGasCost(tankCapacity: tankCapacity, gasPrice: gasPrice)
        let tollExpense = (totalTolls ?? 0) - (tollsReimbursed ?? 0)
        return gasExpense + tollExpense + (parkingFees ?? 0)
    }
    
    func netProfit(mileageRate: Double) -> Double {
        return totalEarnings - totalTaxDeductibleExpense(mileageRate: mileageRate)
    }
    
    func grossProfit(tankCapacity: Double, gasPrice: Double) -> Double {
        return totalEarnings - totalShiftExpenses(tankCapacity: tankCapacity, gasPrice: gasPrice)
    }
    
    // Tax Summary Properties
    var totalTips: Double {
        return tips ?? 0
    }
    
    var taxableIncome: Double {
        return totalEarnings - totalTips
    }
    
    func deductibleExpenses(mileageRate: Double) -> Double {
        let netTolls = (totalTolls ?? 0) - (tollsReimbursed ?? 0)
        return (shiftMileage * mileageRate) + netTolls + (parkingFees ?? 0)
    }
    
    // Cash Flow Summary Properties
    var expectedPayout: Double {
        return (netFare ?? 0) + (tips ?? 0) + (tollsReimbursed ?? 0)
    }
    
    func outOfPocketCosts(tankCapacity: Double, gasPrice: Double) -> Double {
        let gasExpense = shiftGasCost(tankCapacity: tankCapacity, gasPrice: gasPrice)
        return gasExpense + (totalTolls ?? 0) + (parkingFees ?? 0)
    }
    
    func profit(tankCapacity: Double, gasPrice: Double) -> Double {
        return expectedPayout - outOfPocketCosts(tankCapacity: tankCapacity, gasPrice: gasPrice)
    }
    
    func profitPerHour(tankCapacity: Double, gasPrice: Double) -> Double {
        let shiftProfit = profit(tankCapacity: tankCapacity, gasPrice: gasPrice)
        return shiftDuration > 0 ? shiftProfit / (shiftDuration / 3600.0) : 0
    }
}
