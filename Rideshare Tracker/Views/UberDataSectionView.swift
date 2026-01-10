//
//  UberDataSectionView.swift
//  Rideshare Tracker
//
//  Created by Claude AI on 11/14/25.
//

import SwiftUI

/// Collapsible section displaying imported Uber statement data for a shift
struct UberDataSectionView: View {
    let shift: RideshareShift
    @State private var isExpanded = true
    @EnvironmentObject var preferencesManager: PreferencesManager
    @EnvironmentObject var dataManager: ShiftDataManager

    // Get the current shift from data manager for reactive updates (O(1) lookup)
    private var currentShift: RideshareShift {
        dataManager.shift(byId: shift.id) ?? shift
    }

    private var transactions: [UberTransaction] {
        currentShift.uberTransactions
    }

    private var tipTransactions: [UberTransaction] {
        transactions.filter { categorize($0) == .tip }
    }

    private var tollTransactions: [UberTransaction] {
        transactions.filter { $0.tollsReimbursed != nil && ($0.tollsReimbursed ?? 0) > 0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header with collapse toggle
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack {
                    Text("Uber Statement Data")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(PlainButtonStyle())

            if isExpanded {
                VStack(spacing: 8) {
                    // Statement info
                    if let period = currentShift.uberStatementPeriod {
                        DetailRow("Statement Period", period)
                    }

                    if let importDate = currentShift.uberImportDate {
                        DetailRow("Last Import", preferencesManager.formatDate(importDate) + " " + preferencesManager.formatTime(importDate))
                    }

                    // Tips section
                    if !tipTransactions.isEmpty {
                        Divider()
                            .padding(.vertical, 4)

                        HStack {
                            Text("Tips from Statement")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                            Spacer()
                            // Show original only if manual entry was HIGHER than imported
                            if let original = currentShift.originalTips,
                               let imported = currentShift.tips,
                               original > imported + 0.01 {
                                Text("was \(String(format: "$%.2f", original))")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }

                        ForEach(tipTransactions, id: \UberTransaction.id) { (txn: UberTransaction) in
                            HStack {
                                // Compact format: event date / post date
                                Text(formatCompactDates(event: txn.eventDate, post: txn.transactionDate))
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Spacer()

                                Text(String(format: "$%.2f", txn.amount))
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                        }

                        DetailRow("Total Uber Tips", String(format: "$%.2f", currentShift.totalUberTips), valueColor: .green)
                    }

                    // Tolls section
                    if !tollTransactions.isEmpty {
                        Divider()
                            .padding(.vertical, 4)

                        HStack {
                            Text("Toll Reimbursements")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                            Spacer()
                            // Show original only if manual entry was HIGHER than imported
                            if let original = currentShift.originalTollsReimbursed,
                               let imported = currentShift.tollsReimbursed,
                               original > imported + 0.01 {
                                Text("was \(String(format: "$%.2f", original))")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }

                        ForEach(tollTransactions, id: \UberTransaction.id) { (txn: UberTransaction) in
                            HStack {
                                // Compact format: event date / post date + ride type
                                Text(formatCompactDates(event: txn.eventDate, post: txn.transactionDate))
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Text(txn.eventType)
                                    .font(.caption)
                                    .lineLimit(1)

                                Spacer()

                                Text(String(format: "$%.2f", txn.tollsReimbursed ?? 0))
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                        }

                        DetailRow("Total Reimbursed", String(format: "$%.2f", currentShift.totalUberTollReimbursements), valueColor: .green)
                    }

                    // Reconciliation section - UPDATED with interactive UI
                    if currentShift.hasAnyUberDiscrepancy {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("Manual Entry Higher Than Import")
                                    .font(.headline)
                            }
                            .padding(.horizontal)

                            Text("Manual entry exceeds imported value. This may indicate a manual entry error or import parsing issue.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)

                            Divider()
                                .padding(.vertical, 4)

                            if currentShift.hasUberTipDiscrepancy {
                                verificationRow(
                                    label: "Tips",
                                    manualValue: currentShift.originalTips ?? 0,
                                    importedValue: currentShift.tips ?? 0
                                )
                            }

                            if currentShift.hasUberTollDiscrepancy {
                                verificationRow(
                                    label: "Tolls Reimbursed",
                                    manualValue: currentShift.originalTollsReimbursed ?? 0,
                                    importedValue: currentShift.tollsReimbursed ?? 0
                                )
                            }

                            HStack(spacing: 12) {
                                Button("Keep Manual") {
                                    keepManualEntry()
                                }
                                .buttonStyle(.bordered)

                                Button("Use Imported") {
                                    useImportedData()
                                }
                                .buttonStyle(.borderedProminent)
                            }
                            .padding(.horizontal)
                        }
                        .padding(.vertical)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
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

    private func formatTransactionDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d h:mm a"
        return formatter.string(from: date)
    }

    /// Format event and post dates in compact form: "12/6 11:17 PM / 12/13 12:09 AM"
    private func formatCompactDates(event: Date?, post: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d h:mm a"

        let postStr = formatter.string(from: post)

        if let eventDate = event {
            let eventStr = formatter.string(from: eventDate)
            return "\(eventStr) / \(postStr)"
        } else {
            return postStr
        }
    }

    private func verificationRow(label: String, manualValue: Double, importedValue: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Manual \(label)")
                    .font(.caption)
                Spacer()
                Text(String(format: "$%.2f", manualValue))
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            HStack {
                Text("Imported \(label)")
                    .font(.caption)
                Spacer()
                Text(String(format: "$%.2f", importedValue))
                    .font(.caption)
            }
            HStack {
                Text("Difference")
                    .font(.caption)
                    .foregroundColor(.orange)
                Spacer()
                Text(String(format: "+$%.2f", manualValue - importedValue))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)
            }
        }
        .padding(.horizontal)
    }

    private func keepManualEntry() {
        guard var updatedShift = dataManager.shift(byId: shift.id) else { return }

        // Revert to manual values
        updatedShift.tips = updatedShift.originalTips
        updatedShift.tollsReimbursed = updatedShift.originalTollsReimbursed
        updatedShift.uberDataUserVerified = true

        // Use updateShift to sync array, dictionary, and persist
        dataManager.updateShift(updatedShift)
    }

    private func useImportedData() {
        guard var updatedShift = dataManager.shift(byId: shift.id) else { return }

        // Keep imported values (already set), just mark as verified
        updatedShift.uberDataUserVerified = true

        // Use updateShift to sync array, dictionary, and persist
        dataManager.updateShift(updatedShift)
    }
}

#Preview {
    let shift = RideshareShift(
        startDate: Date(),
        startMileage: 50000,
        startTankReading: 6,
        hasFullTankAtStart: false,
        gasPrice: 3.50,
        standardMileageRate: 0.67
    )

    return ScrollView {
        UberDataSectionView(shift: shift)
            .padding()
    }
    .environmentObject(PreferencesManager.shared)
}
