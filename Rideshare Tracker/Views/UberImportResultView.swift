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

    // File exporter state - unified for both CSV and PDF
    @State private var showingFileExporter = false
    @State private var exportDocument: ExportDocument?
    @State private var exportFilename = ""
    @State private var exportContentType: UTType = .data
    @State private var showingExportAlert = false
    @State private var exportMessage = ""
    @State private var csvWasExported = false
    @State private var showingDismissWarning = false

    // Header display properties
    private var headerIcon: String {
        if result.failedStatementCount == 0 && result.skippedStatementCount == 0 {
            return "checkmark.circle.fill"
        } else if result.successfulStatementCount == 0 {
            return "xmark.circle.fill"
        } else {
            return "exclamationmark.circle.fill"
        }
    }

    private var headerColor: Color {
        if result.failedStatementCount == 0 && result.skippedStatementCount == 0 {
            return .green
        } else if result.successfulStatementCount == 0 {
            return .red
        } else {
            return .orange
        }
    }

    private var headerTitle: String {
        if result.failedStatementCount == 0 && result.skippedStatementCount == 0 {
            return "Import Complete"
        } else if result.successfulStatementCount == 0 {
            return "Import Failed"
        } else {
            return "Import Partially Complete"
        }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {

                    // Dynamic Header based on success/partial/failed
                    VStack(spacing: 12) {
                        Image(systemName: headerIcon)
                            .font(.system(size: 60))
                            .foregroundColor(headerColor)

                        Text(headerTitle)
                            .font(.title)
                            .fontWeight(.bold)

                        Text(result.statementPeriod)
                            .font(.headline)
                            .foregroundColor(.secondary)

                        // Show file count for multi-file imports
                        if result.hasMultipleStatements {
                            Text("\(result.statementResults.count) files processed")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top)

                    // Statistics Cards
                    VStack(spacing: 4) {
                        // Show importable transactions (tips, tolls), not total
                        StatCard(
                            title: "Tips & Tolls Found",
                            value: "\(result.importableCount)",
                            icon: "doc.text.fill",
                            color: result.importableCount > 0 ? .blue : .gray
                        )

                        // Show skipped transactions note if any were ignored
                        if result.ignoredCount > 0 {
                            HStack {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.secondary)
                                Text("\(result.ignoredCount) transaction\(result.ignoredCount == 1 ? "" : "s") skipped (bank transfers, etc.)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(.horizontal)
                        }

                        if result.importableCount > 0 {
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

                            if result.transactionsNeedingVerification > 0 {
                                StatCard(
                                    title: "Need Verification",
                                    value: "\(result.transactionsNeedingVerification)",
                                    icon: "exclamationmark.circle.fill",
                                    color: .orange
                                )
                            }
                        }

                        // Special message when no importable transactions
                        if result.hasNoImportableTransactions {
                            VStack(spacing: 8) {
                                Image(systemName: "tray")
                                    .font(.title)
                                    .foregroundColor(.secondary)
                                Text("No Tips or Toll Reimbursements")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                Text("This statement contained only bank transfers or other non-importable transactions.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color(.systemGroupedBackground))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)

                    // Warnings for failed files
                    if result.failedStatementCount > 0 {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("\(result.failedStatementCount) file\(result.failedStatementCount == 1 ? "" : "s") failed to process")
                                    .font(.subheadline)
                            }
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal)
                    }

                    // Data Quality Warning
                    if result.transactionsNeedingVerification > 0 {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("Data Quality Issue")
                                    .font(.headline)
                            }
                            .padding(.horizontal)

                            Text("\(result.transactionsNeedingVerification) transaction(s) are missing event dates (trip time). These transactions use the processed date instead, which may cause matching issues for tips that are processed hours after the actual trip.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)

                            Text("This is usually caused by PDF parsing issues. The import will proceed, but you should verify the affected transactions manually.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .italic()
                                .padding(.horizontal)
                        }
                        .padding(.vertical)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal)
                    }

                    // Uber Import Summary PDF Export
                    if hasTransactionsToSummarize {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "doc.text.fill")
                                    .foregroundColor(.blue)
                                Text("Uber Import Summary")
                                    .font(.headline)
                            }
                            .padding(.horizontal)

                            Text("Export a detailed PDF report of all imported transactions grouped by shift.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)

                            Button {
                                exportTransactionSummaryPDF()
                            } label: {
                                Label("Export Uber Import Summary", systemImage: "arrow.down.doc.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.blue)
                            .padding(.horizontal)
                        }
                        .padding(.vertical)
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
                                csvWasExported = true  // Mark as exported when user initiates download
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
                                Text("• Ready to update and then import back into Rideshare Tracker.")
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
                }
                .padding(.bottom, 24)
            }
            .navigationTitle("Import Results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        handleDoneButtonTap()
                    }
                }
            }
            .fileExporter(
                isPresented: $showingFileExporter,
                document: exportDocument,
                contentType: exportContentType,
                defaultFilename: exportFilename
            ) { result in
                switch result {
                case .success(let url):
                    if exportContentType == .commaSeparatedText {
                        csvWasExported = true
                    }
                    exportMessage = "File saved to: \(url.lastPathComponent)"
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
            .alert("Missing Shifts CSV Not Downloaded", isPresented: $showingDismissWarning) {
                Button("Download CSV", role: .cancel) {
                    if let csv = result.missingShiftsCSV {
                        csvWasExported = true  // Mark as exported when user initiates download
                        prepareCSVExport(csv: csv, filename: "Missing Shifts - \(result.statementPeriod).csv")
                    }
                }
                Button("Close Anyway", role: .destructive) {
                    presentationMode.wrappedValue.dismiss()
                }
            } message: {
                Text("You haven't downloaded the Missing Shifts CSV yet. Would you like to download it before closing?")
            }
        }
    }

    // MARK: - Helper Methods

    /// Check if there are transactions to include in summary
    private var hasTransactionsToSummarize: Bool {
        result.statementResults.contains { $0.success && ($0.matchedCount > 0 || $0.unmatchedCount > 0) }
    }

    private func handleDoneButtonTap() {
        // Check if there's a missing shifts CSV that hasn't been downloaded
        if result.missingShiftsCSV != nil && !csvWasExported {
            showingDismissWarning = true
        } else {
            presentationMode.wrappedValue.dismiss()
        }
    }

    private func prepareCSVExport(csv: String, filename: String) {
        exportDocument = ExportDocument(data: csv.data(using: .utf8) ?? Data())
        exportFilename = filename
        exportContentType = .commaSeparatedText
        // Delay to ensure document state is processed before showing exporter
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            showingFileExporter = true
        }
    }

    private func exportTransactionSummaryPDF() {
        // Generate comprehensive import report PDF
        guard let pdfData = UberTransactionImageGenerator.generateImportReport(
            statementResults: result.statementResults,
            updatedShifts: result.updatedShifts,
            title: "Uber Import Summary - \(result.statementPeriod)"
        ) else { return }

        // Prepare for export
        exportDocument = ExportDocument(data: pdfData)
        exportFilename = "Uber Import Summary - \(result.statementPeriod).pdf"
        exportContentType = .pdf
        // Delay to ensure document state is processed before showing exporter
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            showingFileExporter = true
        }
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

// MARK: - Unified Export Document

/// A unified document type that can export any data as any content type
struct ExportDocument: FileDocument {
    // Support multiple content types for reading (not used, but required)
    static var readableContentTypes: [UTType] { [.data] }

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - Preview

#Preview {
    let sampleResult = UberImportResult(
        statementPeriod: "Oct 13, 2025 - Oct 20, 2025",
        totalTransactions: 27,        // 25 importable + 2 bank transfers
        importableCount: 25,          // Tips + tolls
        matchedCount: 20,
        unmatchedCount: 5,
        transactionsNeedingVerification: 3,
        updatedShifts: [],
        missingShiftsCSV: "Sample CSV content",
        statementResults: [
            SingleStatementResult(
                filename: "uber_statement.pdf",
                statementPeriod: "Oct 13, 2025 - Oct 20, 2025",
                success: true,
                errorMessage: nil,
                matchedCount: 20,
                unmatchedCount: 5,
                importableCount: 25,
                ignoredCount: 2,
                wasSkippedAsDuplicate: false
            )
        ]
    )

    return UberImportResultView(result: sampleResult)
        .environmentObject(ShiftDataManager.shared)
}
