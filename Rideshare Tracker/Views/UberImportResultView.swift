//
//  UberImportResultView.swift
//  Rideshare Tracker
//
//  Created by Claude AI on 11/9/25.
//

import SwiftUI
import UniformTypeIdentifiers

/// Displays results of Uber PDF import with summary images and missing shifts CSV export
struct UberImportResultView: View {
    @EnvironmentObject var dataManager: ShiftDataManager
    @Environment(\.presentationMode) var presentationMode

    let result: UberImportResult

    // File exporter state
    @State private var showingCSVExporter = false
    @State private var csvDocument: CSVDocument?
    @State private var csvFilename = "missing_shifts.csv"
    @State private var showingExportAlert = false
    @State private var exportMessage = ""

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

                    // Transaction Summary Image (combines tips, tolls, and all transactions)
                    if let summaryImage = generateTransactionSummaryImage() {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Transaction Summary")
                                .font(.headline)
                                .padding(.horizontal)

                            Image(uiImage: summaryImage)
                                .resizable()
                                .scaledToFit()
                                .cornerRadius(8)
                                .padding(.horizontal)

                            Button {
                                presentShareSheet(for: summaryImage)
                            } label: {
                                Label("Share Transaction Summary", systemImage: "square.and.arrow.up")
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
                                prepareCSVExport(csv: csv, filename: "Missing Shifts - \(result.statementPeriod).csv")
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
            .fileExporter(
                isPresented: $showingCSVExporter,
                document: csvDocument,
                contentType: .commaSeparatedText,
                defaultFilename: csvFilename
            ) { result in
                switch result {
                case .success(let url):
                    exportMessage = "CSV saved to: \(url.lastPathComponent)"
                    showingExportAlert = true
                case .failure(let error):
                    exportMessage = "Export failed: \(error.localizedDescription)"
                    showingExportAlert = true
                }
            }
            .alert("Export Result", isPresented: $showingExportAlert) {
                Button("OK") { }
            } message: {
                Text(exportMessage)
            }
        }
    }

    // MARK: - Helper Methods

    private func prepareCSVExport(csv: String, filename: String) {
        csvDocument = CSVDocument(content: csv)
        csvFilename = filename
        showingCSVExporter = true
    }

    private func presentShareSheet(for image: UIImage) {
        let controller = UIActivityViewController(
            activityItems: [image],
            applicationActivities: nil
        )

        // Present directly via UIKit - find the topmost presented view controller
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            // Find the topmost presented view controller
            var topController = rootViewController
            while let presented = topController.presentedViewController {
                topController = presented
            }

            // Handle iPad popover presentation
            if let popover = controller.popoverPresentationController {
                popover.sourceView = topController.view
                popover.sourceRect = CGRect(x: topController.view.bounds.midX, y: topController.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }

            topController.present(controller, animated: true)
        }
    }

    private func generateTransactionSummaryImage() -> UIImage? {
        // Get all transactions for updated shifts
        let allTransactions = result.updatedShifts.flatMap { shift in
            UberTransactionManager.shared.getTransactions(forShift: shift.id)
        }
        guard !allTransactions.isEmpty else { return nil }

        // Create a dummy shift for the summary (uses statement period dates)
        // This is just for display purposes in the results view
        guard let firstShift = result.updatedShifts.first else { return nil }

        return UberTransactionImageGenerator.generate(
            transactions: allTransactions,
            shift: firstShift
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

    private var shiftTransactions: [UberTransaction] {
        UberTransactionManager.shared.getTransactions(forShift: shift.id)
    }

    private var tipCount: Int {
        shiftTransactions.filter { categorize($0) == .tip }.count
    }

    private var tollCount: Int {
        shiftTransactions.filter { $0.tollsReimbursed != nil && $0.tollsReimbursed! > 0 }.count
    }

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
                if tipCount > 0 {
                    Label("\(tipCount) tips", systemImage: "dollarsign.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                }

                if tollCount > 0 {
                    Label("\(tollCount) tolls", systemImage: "road.lanes.curved.left")
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

// MARK: - CSV Document for File Export

struct CSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }

    let content: String

    init(content: String) {
        self.content = content
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let string = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        content = string
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = content.data(using: .utf8) ?? Data()
        return FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - Preview

#Preview {
    let sampleResult = UberImportResult(
        statementPeriod: "Oct 13, 2025 - Oct 20, 2025",
        totalTransactions: 25,
        matchedCount: 20,
        unmatchedCount: 5,
        updatedShifts: [],
        missingShiftsCSV: "Sample CSV content"
    )

    return UberImportResultView(result: sampleResult)
        .environmentObject(ShiftDataManager.shared)
}
