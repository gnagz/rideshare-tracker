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

    private var transactions: [UberTransaction] {
        shift.uberTransactions
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
                    if let period = shift.uberStatementPeriod {
                        DetailRow("Statement Period", period)
                    }

                    if let importDate = shift.uberImportDate {
                        DetailRow("Last Import", preferencesManager.formatDate(importDate) + " " + preferencesManager.formatTime(importDate))
                    }

                    // Tips section
                    if !tipTransactions.isEmpty {
                        Divider()
                            .padding(.vertical, 4)

                        Text("Tips from Statement")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)

                        ForEach(tipTransactions, id: \UberTransaction.id) { (txn: UberTransaction) in
                            HStack {
                                Text(formatTransactionDate(txn.transactionDate))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(width: 100, alignment: .leading)

                                Text("Tip")
                                    .font(.caption)

                                Spacer()

                                Text(String(format: "$%.2f", txn.amount))
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                        }

                        DetailRow("Total Uber Tips", String(format: "$%.2f", shift.totalUberTips), valueColor: .green)
                    }

                    // Tolls section
                    if !tollTransactions.isEmpty {
                        Divider()
                            .padding(.vertical, 4)

                        Text("Toll Reimbursements")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)

                        ForEach(tollTransactions, id: \UberTransaction.id) { (txn: UberTransaction) in
                            HStack {
                                Text(formatTransactionDate(txn.transactionDate))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(width: 100, alignment: .leading)

                                Text(txn.eventType)
                                    .font(.caption)

                                Spacer()

                                Text(String(format: "$%.2f", txn.tollsReimbursed ?? 0))
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                        }

                        DetailRow("Total Reimbursed", String(format: "$%.2f", shift.totalUberTollReimbursements), valueColor: .green)
                    }

                    // Reconciliation section
                    if shift.hasAnyUberDiscrepancy {
                        Divider()
                            .padding(.vertical, 4)

                        Text("Reconciliation")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)

                        if shift.hasUberTipDiscrepancy {
                            reconciliationRow(
                                label: "Tips",
                                manualValue: shift.tips ?? 0,
                                uberValue: shift.totalUberTips
                            )
                        }

                        if shift.hasUberTollDiscrepancy {
                            reconciliationRow(
                                label: "Tolls Reimbursed",
                                manualValue: shift.tollsReimbursed ?? 0,
                                uberValue: shift.totalUberTollReimbursements
                            )
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

    private func formatTransactionDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d h:mm a"
        return formatter.string(from: date)
    }

    private func reconciliationRow(label: String, manualValue: Double, uberValue: Double) -> some View {
        let difference = manualValue - uberValue
        let hasDiscrepancy = abs(difference) > 0.01

        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Manual \(label)")
                    .font(.caption)
                Spacer()
                Text(String(format: "$%.2f", manualValue))
                    .font(.caption)
            }
            HStack {
                Text("Uber Statement")
                    .font(.caption)
                Spacer()
                Text(String(format: "$%.2f", uberValue))
                    .font(.caption)
            }
            HStack {
                Text("Difference")
                    .font(.caption)
                    .fontWeight(.semibold)
                Spacer()
                HStack(spacing: 4) {
                    if hasDiscrepancy {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                    }
                    Text(String(format: "%@$%.2f", difference >= 0 ? "+" : "", abs(difference)))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(hasDiscrepancy ? .orange : .green)
                }
            }
        }
        .padding(.vertical, 4)
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
