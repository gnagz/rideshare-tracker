//
//  UberImportResultView.swift
//  Rideshare Tracker
//
//  Created by Claude AI on 11/9/25.
//

import SwiftUI

/// Displays results of Uber PDF import with summary images and missing shifts CSV export
struct UberImportResultView: View {
    @EnvironmentObject var dataManager: ShiftDataManager
    @Environment(\.presentationMode) var presentationMode

    let result: UberImportResult

    @State private var showingShareSheet = false
    @State private var shareItem: ShareItem?

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {

                    // Success Header
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)

                        Text("Import Complete")
                            .font(.title)
                            .fontWeight(.bold)

                        Text(result.statementPeriod)
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top)

                    // Statistics Cards
                    VStack(spacing: 12) {
                        StatCard(
                            title: "Total Transactions",
                            value: "\(result.totalTransactions)",
                            icon: "doc.text.fill",
                            color: .blue
                        )

                        StatCard(
                            title: "Matched to Shifts",
                            value: "\(result.matchedCount)",
                            icon: "checkmark.circle.fill",
                            color: .green
                        )

                        StatCard(
                            title: "Shifts Updated",
                            value: "\(result.updatedShifts.count)",
                            icon: "arrow.triangle.2.circlepath",
                            color: .orange
                        )

                        if result.unmatchedCount > 0 {
                            StatCard(
                                title: "Missing Shifts",
                                value: "\(result.unmatchedCount)",
                                icon: "exclamationmark.triangle.fill",
                                color: .red
                            )
                        }
                    }
                    .padding(.horizontal)

                    // Tip Summary Image
                    if let tipImage = generateTipSummaryImage() {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Tip Summary")
                                .font(.headline)
                                .padding(.horizontal)

                            Image(uiImage: tipImage)
                                .resizable()
                                .scaledToFit()
                                .cornerRadius(8)
                                .padding(.horizontal)

                            Button {
                                shareItem = .image(tipImage, "Uber Tips Summary")
                                showingShareSheet = true
                            } label: {
                                Label("Share Tip Summary", systemImage: "square.and.arrow.up")
                            }
                            .buttonStyle(.bordered)
                            .padding(.horizontal)
                        }
                    }

                    // Toll Summary Image
                    if let tollImage = generateTollSummaryImage() {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Toll Reimbursement Summary")
                                .font(.headline)
                                .padding(.horizontal)

                            Image(uiImage: tollImage)
                                .resizable()
                                .scaledToFit()
                                .cornerRadius(8)
                                .padding(.horizontal)

                            Button {
                                shareItem = .image(tollImage, "Uber Toll Reimbursements")
                                showingShareSheet = true
                            } label: {
                                Label("Share Toll Summary", systemImage: "square.and.arrow.up")
                            }
                            .buttonStyle(.bordered)
                            .padding(.horizontal)
                        }
                    }

                    // Missing Shifts CSV Export
                    if let csv = result.missingShiftsCSV {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("Missing Shifts Detected")
                                    .font(.headline)
                            }
                            .padding(.horizontal)

                            Text("Found \(result.unmatchedCount) transactions that don't match existing shifts. Export a CSV template to create these shifts manually.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)

                            Button {
                                shareItem = .csv(csv, "Missing Shifts - \(result.statementPeriod).csv")
                                showingShareSheet = true
                            } label: {
                                Label("Export Missing Shifts CSV", systemImage: "arrow.down.doc.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .padding(.horizontal)

                            VStack(alignment: .leading, spacing: 4) {
                                Label("What's in the CSV?", systemImage: "info.circle")
                                    .font(.caption)
                                    .fontWeight(.semibold)

                                Text("• Pre-filled Uber earnings data (tips, tolls, net fares)")
                                Text("• Start/end times from actual transactions")
                                Text("• Blank vehicle fields for you to fill in")
                                Text("• Ready to import back into Rideshare Tracker")
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding()
                            .background(Color(.systemGroupedBackground))
                            .cornerRadius(8)
                            .padding(.horizontal)
                        }
                        .padding(.vertical)
                    }

                    // Updated Shifts List
                    if !result.updatedShifts.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Updated Shifts")
                                .font(.headline)
                                .padding(.horizontal)

                            ForEach(result.updatedShifts) { shift in
                                ShiftUpdateCard(shift: shift)
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.bottom, 24)
            }
            .navigationTitle("Import Results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let item = shareItem {
                    ShareSheet(item: item)
                }
            }
        }
    }

    // MARK: - Helper Methods

    private func generateTipSummaryImage() -> UIImage? {
        let allTips = result.updatedShifts.flatMap { $0.uberTipTransactions }
        guard !allTips.isEmpty else { return nil }

        let totalTips = allTips.reduce(0.0) { $0 + $1.amount }

        return UberSummaryImageGenerator.generateTipSummaryImage(
            statementPeriod: result.statementPeriod,
            tipTransactions: allTips,
            matchedShifts: result.updatedShifts,
            totalAmount: totalTips
        )
    }

    private func generateTollSummaryImage() -> UIImage? {
        let allTolls = result.updatedShifts.flatMap { $0.uberTollTransactions }
        guard !allTolls.isEmpty else { return nil }

        let totalTolls = allTolls.reduce(0.0) { $0 + $1.amount }

        return UberSummaryImageGenerator.generateTollSummaryImage(
            statementPeriod: result.statementPeriod,
            tollTransactions: allTolls,
            matchedShifts: result.updatedShifts,
            totalAmount: totalTolls
        )
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
            }

            Spacer()
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .cornerRadius(12)
    }
}

struct ShiftUpdateCard: View {
    let shift: RideshareShift

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(shift.startDate, style: .date)
                    .font(.headline)
                Spacer()
                Text(shift.startDate, style: .time)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 16) {
                if !shift.uberTipTransactions.isEmpty {
                    Label("\(shift.uberTipTransactions.count) tips", systemImage: "dollarsign.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                }

                if !shift.uberTollTransactions.isEmpty {
                    Label("\(shift.uberTollTransactions.count) tolls", systemImage: "road.lanes.curved.left")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .cornerRadius(8)
    }
}

// MARK: - Share Sheet

enum ShareItem {
    case image(UIImage, String)
    case csv(String, String)
}

struct ShareSheet: UIViewControllerRepresentable {
    let item: ShareItem

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let items: [Any]

        switch item {
        case .image(let image, _):
            items = [image]
        case .csv(let content, let filename):
            // Create temporary file for CSV
            let tempDir = FileManager.default.temporaryDirectory
            let fileURL = tempDir.appendingPathComponent(filename)
            try? content.write(to: fileURL, atomically: true, encoding: .utf8)
            items = [fileURL]
        }

        let controller = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )

        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    let sampleResult = UberImportResult(
        statementPeriod: "Oct 13, 2025 - Oct 20, 2025",
        totalTransactions: 25,
        matchedCount: 20,
        unmatchedCount: 5,
        updatedShifts: [],
        tipSummaryImage: nil,
        tollSummaryImage: nil,
        missingShiftsCSV: "Sample CSV content"
    )

    return UberImportResultView(result: sampleResult)
        .environmentObject(ShiftDataManager.shared)
}
