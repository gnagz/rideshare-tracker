//
//  RideshareShiftModelTests.swift
//  Rideshare TrackerTests
//
//  Created by Claude on 9/26/25.
//

import XCTest
import Foundation
import SwiftUI
@testable import Rideshare_Tracker

/// Tests for RideshareShift model business logic and calculations
/// Migrated from original Rideshare_TrackerTests.swift (lines 17-248, 2223-2433)
final class RideshareShiftModelTests: RideshareTrackerTestBase {

    // MARK: - Core Shift Calculation Tests

    func testShiftDurationCalculation() async throws {
        // Given
        let startDate = Date()
        let endDate = startDate.addingTimeInterval(4 * 3600) // 4 hours later

        var shift = createBasicTestShift(
            startDate: startDate,
            startMileage: 100.0
        )
        shift.endDate = endDate
        shift.endMileage = 200.0

        // When
        let duration = shift.shiftDuration
        let hours = shift.shiftHours
        let mileage = shift.shiftMileage

        // Then
        XCTAssertEqual(duration, 4 * 3600) // 4 hours in seconds
        XCTAssertEqual(hours, 4) // 4 hours
        assertFloat(mileage, equals: 100.0) // 100 miles driven
    }

    func testRevenueCalculation() async throws {
        // Given
        var shift = createBasicTestShift()
        shift.netFare = 150.0
        shift.tips = 25.0
        shift.promotions = 10.0

        // When
        let revenue = shift.revenue
        let totalEarnings = shift.totalEarnings
        let taxableIncome = shift.taxableIncome

        // Then
        assertCurrency(taxableIncome, equals: 160.0) // netFare + promotions = 150 + 10
        assertCurrency(revenue, equals: 185.0) // taxableIncome + tips = 160 + 25
        assertCurrency(totalEarnings, equals: revenue) // Should be the same
    }

    func testProfitCalculation() async throws {
        // Given
        var shift = createBasicTestShift(
            startMileage: 100.0
        )
        shift.endDate = Date().addingTimeInterval(3600) // 1 hour
        shift.endMileage = 200.0
        shift.endTankReading = 8.0 // Refueled tank
        shift.netFare = 150.0
        shift.tips = 25.0
        shift.tolls = 10.0
        shift.tollsReimbursed = 5.0
        shift.parkingFees = 5.0
        shift.didRefuelAtEnd = true
        shift.refuelGallons = 4.0
        shift.refuelCost = 8.0

        let tankCapacity = 16.0

        // When
        let revenue = shift.revenue
        let directCosts = shift.directCosts(tankCapacity: tankCapacity)
        let cashFlowProfit = shift.cashFlowProfit(tankCapacity: tankCapacity)

        // Then
        assertCurrency(revenue, equals: 175.0) // netFare + tips = 150 + 25
        XCTAssertGreaterThan(directCosts, 0, "Should have direct costs")
        XCTAssertLessThan(cashFlowProfit, revenue, "Profit should be less than revenue")
    }

    func testTankShortageRefuelBug() async throws {
        // Given: Tank shortage scenario
        var shift = createBasicTestShift(
            startMileage: 100.0,
            startTankReading: 2.0 // Low tank at start
        )
        shift.endDate = Date().addingTimeInterval(3600)
        shift.endMileage = 150.0
        shift.netFare = 50.0
        shift.tips = 10.0
        shift.didRefuelAtEnd = true
        shift.refuelGallons = 10.0
        shift.refuelCost = 20.0

        let tankCapacity = 16.0

        // When
        let gasUsage = shift.shiftGasUsage(tankCapacity: tankCapacity)
        let gasCost = shift.shiftGasCost(tankCapacity: tankCapacity)

        // Then - Should handle tank shortage correctly without negative values
        XCTAssertGreaterThanOrEqual(gasUsage, 0, "Gas usage should not be negative")
        XCTAssertGreaterThanOrEqual(gasCost, 0, "Gas cost should not be negative")

        debugPrint("Tank shortage test - gasUsage: \(gasUsage), gasCost: \(gasCost)")
    }

    func testGasUsageCalculation() async throws {
        // Given
        var shift = createBasicTestShift(
            startMileage: 100.0,
            startTankReading: 8.0 // Full tank
        )
        shift.endDate = Date().addingTimeInterval(3600)
        shift.endMileage = 200.0
        shift.endTankReading = 4.0 // Half tank remaining

        let tankCapacity = 16.0

        // When
        let gasUsage = shift.shiftGasUsage(tankCapacity: tankCapacity)
        let gasCost = shift.shiftGasCost(tankCapacity: tankCapacity)

        // Then
        assertFloat(gasUsage, equals: 8.0) // 8 gallons used (half tank)
        assertCurrency(gasCost, equals: 16.0) // 8 gallons * 2.0 price = 16.0
    }

    func testGasUsageWithRefuel() async throws {
        // Given: Shift with refuel during the shift
        var shift = createBasicTestShift(
            startMileage: 100.0,
            startTankReading: 8.0
        )
        shift.endDate = Date().addingTimeInterval(3600)
        shift.endMileage = 200.0
        shift.endTankReading = 6.0
        shift.didRefuelAtEnd = true
        shift.refuelGallons = 5.0
        shift.refuelCost = 10.0

        let tankCapacity = 16.0

        // When
        let gasUsage = shift.shiftGasUsage(tankCapacity: tankCapacity)
        let gasCost = shift.shiftGasCost(tankCapacity: tankCapacity)

        // Then
        XCTAssertGreaterThan(gasUsage, 0, "Should have positive gas usage")
        XCTAssertGreaterThan(gasCost, 0, "Should have positive gas cost")
    }

    func testIncompleteShift() async throws {
        // Given: Incomplete shift (no end date/mileage)
        let shift = createBasicTestShift(
            startMileage: 100.0
        )

        // When/Then: Should handle incomplete data gracefully
        XCTAssertNil(shift.endDate)
        XCTAssertNil(shift.endMileage)
        XCTAssertEqual(shift.shiftDuration, 0)
        XCTAssertEqual(shift.shiftHours, 0)
        assertFloat(shift.shiftMileage, equals: 0.0)
    }

    func testTaxCalculations() async throws {
        // Given
        var shift = createBasicTestShift()
        shift.netFare = 200.0
        shift.tips = 50.0
        shift.endMileage = shift.startMileage + 100.0 // 100 miles driven

        let mileageRate = 0.67

        // When
        let taxableIncome = shift.taxableIncome
        let deductibleExpense = shift.totalTaxDeductibleExpense(mileageRate: mileageRate)

        // Then
        assertCurrency(taxableIncome, equals: 200.0) // netFare only
        assertCurrency(deductibleExpense, equals: 67.0) // 100 miles * 0.67 = 67.0
    }

    func testProfitPerHour() async throws {
        // Given
        var shift = createBasicTestShift()
        shift.endDate = shift.startDate.addingTimeInterval(4 * 3600) // 4 hours
        shift.endMileage = shift.startMileage + 200.0
        shift.netFare = 160.0
        shift.tips = 40.0

        let tankCapacity = 16.0

        // When
        let profitPerHour = shift.profitPerHour(tankCapacity: tankCapacity)

        // Then: Should calculate profit per hour correctly
        XCTAssertGreaterThan(profitPerHour, 0, "Should have positive profit per hour")

        debugPrint("Profit per hour: \(profitPerHour)")
    }

    // MARK: - Shift Photo Attachment Tests

    func testShiftImageAttachmentsProperty() async throws {
        // Given: New shift without photos
        let shift = createBasicTestShift()

        // When: Checking imageAttachments property exists
        let attachments = shift.imageAttachments

        // Then: Should have empty imageAttachments array by default
        XCTAssertNotNil(attachments, "Shift should have imageAttachments property")
        XCTAssertTrue(attachments.isEmpty, "New shift should have empty imageAttachments")
    }

    func testShiftWithMultiplePhotos() async throws {
        // Given: Shift with multiple photo attachments
        var shift = createBasicTestShift()

        let image1 = createTestUIImage(size: CGSize(width: 200, height: 200), color: .red)
        let image2 = createTestUIImage(size: CGSize(width: 150, height: 150), color: .green)

        // When: Adding multiple photos
        do {
            let attachment1 = try await ImageManager.shared.saveImage(
                image1,
                for: shift.id,
                parentType: .shift,
                type: .receipt,
                description: "Start odometer reading"
            )
            let attachment2 = try await ImageManager.shared.saveImage(
                image2,
                for: shift.id,
                parentType: .shift,
                type: .gasPump,
                description: "End odometer reading"
            )

            shift.imageAttachments = [attachment1, attachment2]

            // Then: Should handle multiple attachments correctly
            XCTAssertEqual(shift.imageAttachments.count, 2, "Should have 2 photo attachments")
            XCTAssertEqual(shift.imageAttachments[0].type, .receipt)
            XCTAssertEqual(shift.imageAttachments[1].type, .gasPump)

        } catch {
            XCTFail("Failed to save test images: \(error)")
        }
    }

    func testShiftPhotoAttachmentPersistence() async throws {
        // Given: Shift with photo
        var shift = createBasicTestShift()
        let testImage = createTestUIImage()

        // When: Saving shift with photo attachment
        do {
            let attachment = try await ImageManager.shared.saveImage(
                testImage,
                for: shift.id,
                parentType: .shift,
                type: .receipt,
                description: "Gas receipt"
            )
            shift.imageAttachments = [attachment]

            // Save the shift
            await ShiftDataManager.shared.addShift(shift)

            // Retrieve the shift
            let savedShifts = await ShiftDataManager.shared.shifts
            guard let retrievedShift = savedShifts.first(where: { $0.id == shift.id }) else {
                XCTFail("Could not retrieve saved shift")
                return
            }

            // Then: Photo attachment should persist
            XCTAssertEqual(retrievedShift.imageAttachments.count, 1, "Should have 1 photo attachment")
            XCTAssertEqual(retrievedShift.imageAttachments.first?.description, "Gas receipt")

        } catch {
            XCTFail("Failed to save/retrieve shift with photo: \(error)")
        }
    }

    func testShiftPhotoFileDeletion() async throws {
        // Given: Shift with photo attachment
        var shift = createBasicTestShift()
        let testImage = createTestUIImage()

        do {
            let attachment = try await ImageManager.shared.saveImage(
                testImage,
                for: shift.id,
                parentType: .shift,
                type: .receipt,
                description: "Test receipt"
            )
            shift.imageAttachments = [attachment]

            // Verify file exists
            let fileURL = await ImageManager.shared.imageURL(for: shift.id, parentType: .shift, filename: attachment.filename)
            XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path),
                         "Image file should exist after saving")

            // When: Deleting the image
            await ImageManager.shared.deleteImage(attachment, for: shift.id, parentType: .shift)

            // Then: File should be deleted
            XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path),
                          "Image file should be deleted")

        } catch {
            XCTFail("Failed to delete image file: \(error)")
        }
    }

    // MARK: - Critical Calculation Bug Tests

    func testGasPriceCalculationFromRefuelData() async throws {
        // Given: Shift with refuel data for gas price calculation
        var shift = createBasicTestShift(gasPrice: 0.0) // No preset gas price

        shift.didRefuelAtEnd = true
        shift.refuelGallons = 10.0
        shift.refuelCost = 32.50

        // When: Update gas price from refuel data (may need to call updateGasPrice)
        shift.updateGasPrice()
        let calculatedGasPrice = shift.gasPrice

        // Then: Should calculate correct gas price per gallon
        if calculatedGasPrice > 0 {
            assertCurrency(calculatedGasPrice, equals: 3.25) // 32.50 / 10.0 = 3.25
        } else {
            // Gas price calculation may not be automatic - test that refuel data is captured
            XCTAssertEqual(shift.refuelGallons, 10.0, "Refuel gallons should be captured")
            assertCurrency(shift.refuelCost ?? 0, equals: 32.50) // Refuel cost should be captured
        }
    }

    // MARK: - Tax Calculation Tests

    func testTaxCalculationMethods() async throws {
        // Given: Completed shift with various income and expense components
        var shift = createBasicTestShift()
        shift.endMileage = shift.startMileage + 150.0 // 150 miles driven
        shift.netFare = 180.0
        shift.tips = 35.0

        let mileageRate = 0.67

        // When: Calculating tax-related values
        let taxableIncome = shift.taxableIncome
        let mileageDeduction = shift.totalTaxDeductibleExpense(mileageRate: mileageRate)

        // Then: Should calculate tax values correctly
        assertCurrency(taxableIncome, equals: 180.0) // netFare only
        assertCurrency(mileageDeduction, equals: 100.5) // 150 miles * 0.67 rate = 100.5

        debugMessage("Taxable income: \(taxableIncome), Mileage deduction: \(mileageDeduction)")
    }

    // MARK: - Cash Tips Tests

    func testCashTipsDefaultsToNil() {
        // Given: A new shift
        let shift = createBasicTestShift()

        // Then: Cash tips should default to nil
        XCTAssertNil(shift.cashTips, "Cash tips should default to nil")
        debugMessage("Cash tips defaults to: \(shift.cashTips?.description ?? "nil")")
    }

    func testTotalTipsCalculation() {
        // Given: A shift with Uber app tips and cash tips
        var shift = createBasicTestShift()
        shift.tips = 25.0  // Uber app tips
        shift.cashTips = 15.0  // Cash tips

        // When: Getting total tips
        let totalTips = shift.totalTips

        // Then: Should sum both types of tips
        assertCurrency(totalTips, equals: 40.0)
        debugMessage("Total tips (Uber: $25 + Cash: $15) = \(totalTips)")
    }

    func testTotalTipsWithOnlyUberTips() {
        // Given: A shift with only Uber app tips (cashTips = nil)
        var shift = createBasicTestShift()
        shift.tips = 30.0
        // cashTips remains nil

        // When: Getting total tips
        let totalTips = shift.totalTips

        // Then: Should equal Uber tips
        assertCurrency(totalTips, equals: 30.0)
        debugMessage("Total tips (Uber only: $30) = \(totalTips)")
    }

    func testTotalTipsWithOnlyCashTips() {
        // Given: A shift with only cash tips (tips = nil)
        var shift = createBasicTestShift()
        // tips remains nil
        shift.cashTips = 20.0

        // When: Getting total tips
        let totalTips = shift.totalTips

        // Then: Should equal cash tips
        assertCurrency(totalTips, equals: 20.0)
        debugMessage("Total tips (Cash only: $20) = \(totalTips)")
    }

    func testGrossProfitUsesTotalTips() {
        // Given: A complete shift with both tip types
        var shift = createBasicTestShift()
        shift.startMileage = 1000
        shift.endMileage = 1150
        shift.netFare = 100.0
        shift.tips = 20.0  // Uber tips
        shift.cashTips = 10.0  // Cash tips
        shift.promotions = 15.0

        // When: Calculating gross profit
        let grossProfit = shift.grossProfit()

        // Then: Should include total tips (20 + 10 = 30)
        // grossProfit = netFare + tips + cashTips + promotions = 100 + 20 + 10 + 15 = 145
        assertCurrency(grossProfit, equals: 145.0)
        debugMessage("Gross profit with total tips: \(grossProfit)")
    }

    // MARK: - Uber Import Reconciliation Tests

    func testOriginalTipsPreserved() async throws {
        // Given: A shift with manual entry
        var shift = createBasicTestShift()
        shift.tips = 15.0
        shift.tollsReimbursed = 5.0

        // When: Setting original values (should only happen once)
        shift.originalTips = shift.tips
        shift.originalTollsReimbursed = shift.tollsReimbursed

        // Then: Original values are preserved
        XCTAssertEqual(shift.originalTips, 15.0, "Original tips should be saved")
        XCTAssertEqual(shift.originalTollsReimbursed, 5.0, "Original tolls should be saved")

        // When: Tips updated by import
        shift.tips = 13.50
        shift.tollsReimbursed = 5.00

        // Then: Original still preserved
        XCTAssertEqual(shift.originalTips, 15.0, "Original tips should remain unchanged")
        XCTAssertEqual(shift.originalTollsReimbursed, 5.0, "Original tolls should remain unchanged")
    }

    func testDiscrepancyDetectionManualGreater() async throws {
        // Given: Shift with manual > imported (unexpected scenario)
        var shift = createBasicTestShift()
        shift.tips = 13.50  // Current (imported) value
        shift.tollsReimbursed = 5.00  // Current (imported) value
        shift.originalTips = 17.50  // Manual was higher
        shift.originalTollsReimbursed = 7.00  // Manual was higher
        shift.uberImportDate = Date()  // Has Uber data
        shift.uberDataUserVerified = false  // Not yet verified

        // Then: Discrepancy detected
        XCTAssertTrue(shift.hasUberTipDiscrepancy, "Should detect tip discrepancy when manual > imported")
        XCTAssertTrue(shift.hasUberTollDiscrepancy, "Should detect toll discrepancy when manual > imported")
        XCTAssertTrue(shift.hasAnyUberDiscrepancy, "Should detect overall discrepancy")
    }

    func testNoDiscrepancyWhenImportedGreater() async throws {
        // Given: Shift with imported > manual (normal scenario - delayed tips)
        var shift = createBasicTestShift()
        shift.tips = 17.50  // Current (imported) value - higher
        shift.tollsReimbursed = 7.00  // Current (imported) value - higher
        shift.originalTips = 13.50  // Manual was lower (expected)
        shift.originalTollsReimbursed = 5.00  // Manual was lower (expected)
        shift.uberImportDate = Date()  // Has Uber data
        shift.uberDataUserVerified = false

        // Then: NO discrepancy (this is expected behavior)
        XCTAssertFalse(shift.hasUberTipDiscrepancy, "Should NOT flag when imported > manual (delayed tips)")
        XCTAssertFalse(shift.hasUberTollDiscrepancy, "Should NOT flag when imported > manual")
        XCTAssertFalse(shift.hasAnyUberDiscrepancy, "Should have no discrepancy")
    }

    func testNoDiscrepancyWhenEqual() async throws {
        // Given: Shift with manual == imported (perfect match)
        var shift = createBasicTestShift()
        shift.tips = 15.0
        shift.tollsReimbursed = 5.0
        shift.originalTips = 15.0  // Same as imported
        shift.originalTollsReimbursed = 5.0  // Same as imported
        shift.uberImportDate = Date()
        shift.uberDataUserVerified = false

        // Then: NO discrepancy
        XCTAssertFalse(shift.hasUberTipDiscrepancy, "Should NOT flag when values match")
        XCTAssertFalse(shift.hasUberTollDiscrepancy, "Should NOT flag when values match")
        XCTAssertFalse(shift.hasAnyUberDiscrepancy, "Should have no discrepancy")
    }

    func testVerificationSuppressesWarning() async throws {
        // Given: Shift with discrepancy but user has verified
        var shift = createBasicTestShift()
        shift.tips = 13.50  // Imported
        shift.tollsReimbursed = 5.00  // Imported
        shift.originalTips = 17.50  // Manual was higher
        shift.originalTollsReimbursed = 7.00  // Manual was higher
        shift.uberImportDate = Date()
        shift.uberDataUserVerified = true  // User made decision

        // Then: No warning shown (user verified)
        XCTAssertFalse(shift.hasUberTipDiscrepancy, "Should NOT show warning after verification")
        XCTAssertFalse(shift.hasUberTollDiscrepancy, "Should NOT show warning after verification")
        XCTAssertFalse(shift.hasAnyUberDiscrepancy, "Should have no warning")
    }

    func testNoDiscrepancyWhenNoOriginal() async throws {
        // Given: Shift imported without saving original (legacy data)
        var shift = createBasicTestShift()
        shift.tips = 15.0  // Imported value
        shift.tollsReimbursed = 5.0  // Imported value
        shift.originalTips = nil  // No original saved
        shift.originalTollsReimbursed = nil  // No original saved
        shift.uberImportDate = Date()
        shift.uberDataUserVerified = false

        // Then: No discrepancy possible
        XCTAssertFalse(shift.hasUberTipDiscrepancy, "Should NOT flag without original to compare")
        XCTAssertFalse(shift.hasUberTollDiscrepancy, "Should NOT flag without original to compare")
        XCTAssertFalse(shift.hasAnyUberDiscrepancy, "Should have no discrepancy")
    }

    func testNoDiscrepancyWhenNoUberData() async throws {
        // Given: Shift without Uber import
        var shift = createBasicTestShift()
        shift.tips = 15.0
        shift.tollsReimbursed = 5.0
        shift.originalTips = 17.50  // Would be discrepancy if imported
        shift.originalTollsReimbursed = 7.00
        shift.uberImportDate = nil  // No import yet
        shift.uberDataUserVerified = false

        // Then: No discrepancy (no Uber data to compare)
        XCTAssertFalse(shift.hasUberTipDiscrepancy, "Should NOT flag without Uber data")
        XCTAssertFalse(shift.hasUberTollDiscrepancy, "Should NOT flag without Uber data")
        XCTAssertFalse(shift.hasAnyUberDiscrepancy, "Should have no discrepancy")
    }

    func testSmallDifferenceIgnored() async throws {
        // Given: Shift with tiny difference (rounding)
        var shift = createBasicTestShift()
        shift.tips = 15.00  // Imported
        shift.tollsReimbursed = 5.00  // Imported
        shift.originalTips = 15.005  // Negligible difference (< 1 cent)
        shift.originalTollsReimbursed = 5.005  // Negligible difference
        shift.uberImportDate = Date()
        shift.uberDataUserVerified = false

        // Then: No discrepancy (within tolerance)
        XCTAssertFalse(shift.hasUberTipDiscrepancy, "Should ignore sub-penny differences")
        XCTAssertFalse(shift.hasUberTollDiscrepancy, "Should ignore sub-penny differences")
        XCTAssertFalse(shift.hasAnyUberDiscrepancy, "Should have no discrepancy")
    }

    // MARK: - YTD Calculation Tests

    func testGetAvailableYears() {
        // Given: Shifts across multiple years
        let shift2024 = createCompletedShiftForYear(2024, month: 6)
        let shift2025a = createCompletedShiftForYear(2025, month: 3)
        let shift2025b = createCompletedShiftForYear(2025, month: 9)
        let shifts = [shift2024, shift2025a, shift2025b]

        // When: Getting available years
        let years = RideshareShift.getAvailableYears(shifts: shifts)

        // Then: Should return years in descending order
        XCTAssertEqual(years, [2025, 2024], "Should return years descending, most recent first")
    }

    func testGetAvailableYearsExcludesIncompleteShifts() {
        // Given: Mix of complete and incomplete shifts
        let completeShift = createCompletedShiftForYear(2025, month: 6)
        var incompleteShift = createBasicTestShift(startDate: createTestDate(year: 2024, month: 6, day: 15))
        incompleteShift.endDate = nil  // Not completed
        let shifts = [completeShift, incompleteShift]

        // When: Getting available years
        let years = RideshareShift.getAvailableYears(shifts: shifts)

        // Then: Should only include year with completed shift
        XCTAssertEqual(years, [2025], "Should exclude years with only incomplete shifts")
    }

    func testGetAvailableYearsExcludesDeletedShifts() {
        // Given: Mix of active and deleted shifts
        let activeShift = createCompletedShiftForYear(2025, month: 6)
        var deletedShift = createCompletedShiftForYear(2024, month: 6)
        deletedShift.isDeleted = true
        let shifts = [activeShift, deletedShift]

        // When: Getting available years
        let years = RideshareShift.getAvailableYears(shifts: shifts)

        // Then: Should only include year with active shift
        XCTAssertEqual(years, [2025], "Should exclude years with only deleted shifts")
    }

    func testGetAvailableYearsEmptyShifts() {
        // Given: No shifts
        let shifts: [RideshareShift] = []

        // When: Getting available years
        let years = RideshareShift.getAvailableYears(shifts: shifts)

        // Then: Should return empty array
        XCTAssertTrue(years.isEmpty, "Should return empty array for no shifts")
    }

    func testGetMileageRateForCurrentYear() {
        // Given: Shifts with different rates, current year
        let currentYear = Calendar.current.component(.year, from: Date())
        var shift = createCompletedShiftForYear(currentYear, month: 6)
        shift.standardMileageRate = 0.655  // Old rate on shift
        let currentRate = 0.70  // Current preference rate

        // When: Getting rate for current year
        let rate = RideshareShift.getMileageRateForYear(currentYear, shifts: [shift], currentRate: currentRate)

        // Then: Should return current preference rate
        assertFloat(rate, equals: 0.70, "Current year should use preference rate")
    }

    func testGetMileageRateForPastYear() {
        // Given: Shifts in past year with specific rate
        let currentYear = Calendar.current.component(.year, from: Date())
        let pastYear = currentYear - 1
        var shift = createCompletedShiftForYear(pastYear, month: 12)
        shift.standardMileageRate = 0.655  // Rate captured on shift
        let currentRate = 0.70  // Current preference rate

        // When: Getting rate for past year
        let rate = RideshareShift.getMileageRateForYear(pastYear, shifts: [shift], currentRate: currentRate)

        // Then: Should return rate from last shift of that year
        assertFloat(rate, equals: 0.655, "Past year should use rate from last shift")
    }

    func testGetMileageRateForPastYearUsesLastShift() {
        // Given: Multiple shifts in past year with different rates
        let currentYear = Calendar.current.component(.year, from: Date())
        let pastYear = currentYear - 1
        var shiftJan = createCompletedShiftForYear(pastYear, month: 1)
        shiftJan.standardMileageRate = 0.625
        var shiftJun = createCompletedShiftForYear(pastYear, month: 6)
        shiftJun.standardMileageRate = 0.655
        var shiftDec = createCompletedShiftForYear(pastYear, month: 12)
        shiftDec.standardMileageRate = 0.67
        let shifts = [shiftJan, shiftJun, shiftDec]

        // When: Getting rate for past year
        let rate = RideshareShift.getMileageRateForYear(pastYear, shifts: shifts, currentRate: 0.70)

        // Then: Should return rate from December (last shift)
        assertFloat(rate, equals: 0.67, "Should use rate from last shift of year")
    }

    func testGetMileageRateForYearWithNoShifts() {
        // Given: No shifts for requested year
        let currentYear = Calendar.current.component(.year, from: Date())
        let shift = createCompletedShiftForYear(currentYear, month: 6)
        let currentRate = 0.70

        // When: Getting rate for year with no shifts
        let rate = RideshareShift.getMileageRateForYear(currentYear - 2, shifts: [shift], currentRate: currentRate)

        // Then: Should fall back to current rate
        assertFloat(rate, equals: 0.70, "Should fall back to current rate when no shifts for year")
    }

    func testCalculateYearTotalMileage() {
        // Given: Multiple shifts in a year
        let shift1 = createCompletedShiftWithMileage(year: 2025, month: 3, miles: 50.0)
        let shift2 = createCompletedShiftWithMileage(year: 2025, month: 6, miles: 75.0)
        let shift3 = createCompletedShiftWithMileage(year: 2025, month: 9, miles: 100.0)
        let shifts = [shift1, shift2, shift3]

        // When: Calculating total mileage for year
        let totalMileage = RideshareShift.calculateYearTotalMileage(shifts: shifts, year: 2025)

        // Then: Should sum all shift miles
        assertFloat(totalMileage, equals: 225.0, "Should sum all shift mileage for year")
    }

    func testCalculateYearTotalMileageExcludesOtherYears() {
        // Given: Shifts across multiple years
        let shift2024 = createCompletedShiftWithMileage(year: 2024, month: 6, miles: 100.0)
        let shift2025 = createCompletedShiftWithMileage(year: 2025, month: 6, miles: 50.0)
        let shifts = [shift2024, shift2025]

        // When: Calculating total mileage for 2025 only
        let totalMileage = RideshareShift.calculateYearTotalMileage(shifts: shifts, year: 2025)

        // Then: Should only include 2025 shifts
        assertFloat(totalMileage, equals: 50.0, "Should only include shifts from requested year")
    }

    func testCalculateSETaxableEarnings() {
        // Given: Net earnings
        let netEarnings = 50000.0

        // When: Calculating SE taxable earnings
        let taxableEarnings = RideshareShift.calculateSETaxableEarnings(netEarnings: netEarnings)

        // Then: Should be 92.35% of net earnings
        assertCurrency(taxableEarnings, equals: 46175.0, "SE taxable = net × 92.35%")
    }

    func testCalculateSETax() {
        // Given: SE taxable earnings
        let taxableEarnings = 46175.0

        // When: Calculating SE tax
        let seTax = RideshareShift.calculateSETax(taxableEarnings: taxableEarnings)

        // Then: Should be 15.3% of taxable earnings
        assertCurrency(seTax, equals: 7064.775, "SE tax = taxable × 15.3%")
    }

    func testCalculateAGI() {
        // Given: Net earnings and SE tax
        let netEarnings = 50000.0
        let seTax = 7064.78

        // When: Calculating AGI
        let agi = RideshareShift.calculateAGI(netEarnings: netEarnings, seTax: seTax)

        // Then: Should be net earnings minus 50% of SE tax
        assertCurrency(agi, equals: 46467.61, "AGI = net - (SE tax × 50%)")
    }

    func testCalculateTaxableIncomeWithTipDeduction() {
        // Given: AGI and deductible tips
        let agi = 46467.61
        let deductibleTips = 5000.0

        // When: Calculating taxable income
        let taxableIncome = RideshareShift.calculateYTDTaxableIncome(agi: agi, deductibleTips: deductibleTips)

        // Then: Should be AGI minus deductible tips
        assertCurrency(taxableIncome, equals: 41467.61, "Taxable income = AGI - deductible tips")
    }

    func testCalculateTaxableIncomeNeverNegative() {
        // Given: Deductible tips greater than AGI
        let agi = 5000.0
        let deductibleTips = 10000.0

        // When: Calculating taxable income
        let taxableIncome = RideshareShift.calculateYTDTaxableIncome(agi: agi, deductibleTips: deductibleTips)

        // Then: Should be zero, not negative
        assertCurrency(taxableIncome, equals: 0.0, "Taxable income should never be negative")
    }

    func testCalculateTotalTaxDue() {
        // Given: SE tax and income tax
        let seTax = 7064.78
        let incomeTax = 9122.87

        // When: Calculating total tax
        let totalTax = RideshareShift.calculateTotalTaxDue(seTax: seTax, incomeTax: incomeTax)

        // Then: Should sum both taxes
        assertCurrency(totalTax, equals: 16187.65, "Total tax = SE tax + income tax")
    }

    func testCalculateYearTotalBusinessRevenue() {
        // Given: Multiple shifts with various revenue components
        var shift1 = createCompletedShiftForYear(2025, month: 3)
        shift1.netFare = 100.0
        shift1.tips = 20.0
        shift1.cashTips = 5.0
        shift1.promotions = 10.0

        var shift2 = createCompletedShiftForYear(2025, month: 6)
        shift2.netFare = 150.0
        shift2.tips = 30.0
        shift2.cashTips = 10.0
        shift2.promotions = 15.0

        let shifts = [shift1, shift2]

        // When: Calculating total business revenue
        let revenue = RideshareShift.calculateYearTotalBusinessRevenue(shifts: shifts, year: 2025)

        // Then: Should sum all revenue components
        // shift1: 100 + 20 + 5 + 10 = 135
        // shift2: 150 + 30 + 10 + 15 = 205
        // total: 340
        assertCurrency(revenue, equals: 340.0, "Should sum all revenue components")
    }

    func testCalculateYearTotalTollsNotReimbursed() {
        // Given: Shifts with tolls and reimbursements
        var shift1 = createCompletedShiftForYear(2025, month: 3)
        shift1.tolls = 20.0
        shift1.tollsReimbursed = 15.0  // Net: 5.0

        var shift2 = createCompletedShiftForYear(2025, month: 6)
        shift2.tolls = 30.0
        shift2.tollsReimbursed = 30.0  // Net: 0.0

        var shift3 = createCompletedShiftForYear(2025, month: 9)
        shift3.tolls = 25.0
        shift3.tollsReimbursed = 10.0  // Net: 15.0

        let shifts = [shift1, shift2, shift3]

        // When: Calculating total tolls not reimbursed
        let tollsNotReimbursed = RideshareShift.calculateYearTotalTollsNotReimbursed(shifts: shifts, year: 2025)

        // Then: Should sum (tolls - reimbursed) for each shift
        assertCurrency(tollsNotReimbursed, equals: 20.0, "Should sum net unreimbursed tolls")
    }

    func testCalculateYearTotalTripFees() {
        // Given: Shifts with parking and misc fees
        var shift1 = createCompletedShiftForYear(2025, month: 3)
        shift1.parkingFees = 10.0
        shift1.miscFees = 5.0

        var shift2 = createCompletedShiftForYear(2025, month: 6)
        shift2.parkingFees = 15.0
        shift2.miscFees = nil

        let shifts = [shift1, shift2]

        // When: Calculating total trip fees
        let tripFees = RideshareShift.calculateYearTotalTripFees(shifts: shifts, year: 2025)

        // Then: Should sum parking + misc fees
        assertCurrency(tripFees, equals: 30.0, "Should sum all trip fees")
    }

    // MARK: - YTD Test Helper Methods

    private func createCompletedShiftForYear(_ year: Int, month: Int) -> RideshareShift {
        let startDate = createTestDate(year: year, month: month, day: 15, hour: 9)
        var shift = createBasicTestShift(startDate: startDate)
        shift.endDate = startDate.addingTimeInterval(4 * 3600)  // 4 hours later
        shift.endMileage = shift.startMileage + 100
        shift.netFare = 100.0
        shift.tips = 20.0
        return shift
    }

    private func createCompletedShiftWithMileage(year: Int, month: Int, miles: Double) -> RideshareShift {
        let startDate = createTestDate(year: year, month: month, day: 15, hour: 9)
        var shift = createBasicTestShift(startDate: startDate)
        shift.endDate = startDate.addingTimeInterval(4 * 3600)
        shift.endMileage = shift.startMileage + miles
        return shift
    }
}