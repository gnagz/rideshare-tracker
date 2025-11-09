//
//  UberImportView.swift
//  Rideshare Tracker
//
//  Created by Claude AI on 11/9/25.
//

import SwiftUI
import PDFKit
import UniformTypeIdentifiers

/// View for importing Uber weekly statement PDFs
/// Matches tips and tolls to existing shifts, generates missing shifts CSV
struct UberImportView: View {
    @EnvironmentObject var dataManager: ShiftDataManager
    @Environment(\.presentationMode) var presentationMode

    @State private var showingFilePicker = false
    @State private var isProcessing = false
    @State private var showingResults = false
    @State private var importResult: UberImportResult?
    @State private var errorMessage: String?
    @State private var showingError = false

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {

                // Header Section
                VStack(spacing: 16) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)

                    Text("Import Uber Weekly Statement")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Upload your Uber weekly statement PDF to automatically match tips and toll reimbursements to your shifts.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Button {
                        showingFilePicker = true
                    } label: {
                        Label("Select PDF File", systemImage: "doc.badge.plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(isProcessing)
                    .padding(.horizontal)
                }
                .padding(.top)

                Spacer()

                // Information Section
                VStack(alignment: .leading, spacing: 8) {
                    Label("What Happens", systemImage: "info.circle")
                        .font(.headline)

                    Text("• Extracts tips and toll reimbursements from PDF")
                    Text("• Matches transactions to existing shifts using 4 AM boundaries")
                    Text("• Updates shifts with Uber tip and toll data")
                    Text("• Generates summary images for matched data")
                    Text("• Creates CSV for unmatched transactions (missing shifts)")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.systemGroupedBackground))
                .cornerRadius(8)
                .padding(.horizontal)

                if isProcessing {
                    ProgressView("Processing PDF...")
                        .padding()
                }
            }
            .navigationTitle("Uber Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: false
            ) { result in
                handleFileSelection(result)
            }
            .sheet(isPresented: $showingResults) {
                if let result = importResult {
                    UberImportResultView(result: result)
                        .environmentObject(dataManager)
                }
            }
            .alert("Import Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage ?? "An unknown error occurred")
            }
        }
    }

    // MARK: - Import Logic

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            processPDF(at: url)
        case .failure(let error):
            errorMessage = "Failed to select file: \(error.localizedDescription)"
            showingError = true
        }
    }

    private func processPDF(at url: URL) {
        isProcessing = true

        Task {
            do {
                // Load PDF
                guard url.startAccessingSecurityScopedResource() else {
                    throw UberImportError.fileAccessDenied
                }
                defer { url.stopAccessingSecurityScopedResource() }

                guard let pdfDocument = PDFDocument(url: url) else {
                    throw UberImportError.invalidPDF
                }

                // Extract text from PDF
                let pdfText = extractText(from: pdfDocument)

                // Parse statement period
                let parser = UberPDFParser()
                guard let statementInfo = try parser.parseStatementPeriod(from: pdfText) else {
                    throw UberImportError.statementPeriodNotFound
                }

                // Detect column layout
                let layout = parser.detectColumnLayout(from: pdfText)

                // Parse transactions
                let transactions = try parser.parseTransactions(
                    from: pdfText,
                    layout: layout,
                    statementEndDate: statementInfo.endDate
                )

                // Match transactions to shifts
                let matcher = UberShiftMatcher()
                let (matched, unmatched) = matcher.matchTransactionsToShifts(
                    transactions: transactions,
                    existingShifts: dataManager.shifts
                )

                // Process matched transactions
                let processedShifts = try await processMatchedTransactions(matched, statementPeriod: statementInfo.period)

                // Generate missing shifts CSV
                let csvGenerator = MissingShiftsCSVGenerator()
                let missingShiftsCSV = try csvGenerator.generateMissingShiftsCSV(
                    unmatchedTransactions: unmatched,
                    statementPeriod: statementInfo.period
                )

                // Create result
                let result = UberImportResult(
                    statementPeriod: statementInfo.period,
                    totalTransactions: transactions.count,
                    matchedCount: matched.count,
                    unmatchedCount: unmatched.count,
                    updatedShifts: processedShifts,
                    tipSummaryImage: nil,  // Will be generated
                    tollSummaryImage: nil, // Will be generated
                    missingShiftsCSV: missingShiftsCSV.isEmpty ? nil : missingShiftsCSV
                )

                await MainActor.run {
                    importResult = result
                    isProcessing = false
                    showingResults = true
                }

            } catch {
                await MainActor.run {
                    isProcessing = false
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }

    private func extractText(from pdfDocument: PDFDocument) -> String {
        var text = ""
        for pageIndex in 0..<pdfDocument.pageCount {
            if let page = pdfDocument.page(at: pageIndex) {
                text += page.string ?? ""
                text += "\n"
            }
        }
        return text
    }

    private func processMatchedTransactions(
        _ matches: [ShiftMatch],
        statementPeriod: String
    ) async throws -> [RideshareShift] {
        // Group matches by shift
        var shiftUpdates: [UUID: (shift: RideshareShift, tips: [UberTipTransaction], tolls: [UberTollReimbursementTransaction])] = [:]

        let parser = UberPDFParser()

        for match in matches {
            let category = parser.categorize(transaction: match.transaction)

            var entry = shiftUpdates[match.shift.id] ?? (match.shift, [], [])

            switch category {
            case .tip:
                let tipTransaction = UberTipTransaction(
                    transactionDate: match.transaction.transactionDate,
                    amount: match.transaction.amount,
                    eventType: match.transaction.eventType,
                    isDelayedTip: false  // TODO: Implement delayed tip detection
                )
                entry.tips.append(tipTransaction)

            case .netFare, .promotion:
                // Handle toll reimbursements embedded in rides
                if let tollAmount = match.transaction.tollReimbursement, tollAmount > 0 {
                    let tollTransaction = UberTollReimbursementTransaction(
                        transactionDate: match.transaction.transactionDate,
                        amount: tollAmount,
                        eventType: match.transaction.eventType
                    )
                    entry.tolls.append(tollTransaction)
                }

            case .ignore:
                continue
            }

            shiftUpdates[match.shift.id] = entry
        }

        // Update shifts
        var updatedShifts: [RideshareShift] = []

        for (shiftId, (shift, tips, tolls)) in shiftUpdates {
            var updatedShift = shift
            updatedShift.uberTipTransactions = tips
            updatedShift.uberTollTransactions = tolls
            updatedShift.uberImportDate = Date()
            updatedShift.uberStatementPeriod = statementPeriod

            // Update in data manager
            await MainActor.run {
                if let index = dataManager.shifts.firstIndex(where: { $0.id == shiftId }) {
                    dataManager.shifts[index] = updatedShift
                }
            }

            updatedShifts.append(updatedShift)
        }

        return updatedShifts
    }
}

// MARK: - Supporting Types

enum UberImportError: LocalizedError {
    case fileAccessDenied
    case invalidPDF
    case statementPeriodNotFound
    case parsingFailed

    var errorDescription: String? {
        switch self {
        case .fileAccessDenied:
            return "Cannot access the selected file. Please try again."
        case .invalidPDF:
            return "The selected file is not a valid PDF document."
        case .statementPeriodNotFound:
            return "Could not find statement period in PDF. Please ensure this is an Uber weekly statement."
        case .parsingFailed:
            return "Failed to parse PDF content. The file may be corrupted or in an unexpected format."
        }
    }
}

struct UberImportResult {
    let statementPeriod: String
    let totalTransactions: Int
    let matchedCount: Int
    let unmatchedCount: Int
    let updatedShifts: [RideshareShift]
    let tipSummaryImage: UIImage?
    let tollSummaryImage: UIImage?
    let missingShiftsCSV: String?
}

// MARK: - Preview

#Preview {
    UberImportView()
        .environmentObject(ShiftDataManager.shared)
}
