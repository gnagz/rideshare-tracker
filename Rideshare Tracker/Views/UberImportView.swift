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

    // State for re-import confirmation dialog
    @State private var showingReplaceConfirmation = false
    @State private var pendingStatementPeriod: String = ""
    @State private var pendingTransactions: [UberTransaction] = []
    @State private var existingTransactionCount: Int = 0

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
            .alert("Statement Period Already Imported", isPresented: $showingReplaceConfirmation) {
                Button("Replace", role: .destructive) {
                    performStatementPeriodReplacement()
                }
                Button("Cancel", role: .cancel) {
                    pendingTransactions = []
                    pendingStatementPeriod = ""
                    existingTransactionCount = 0
                }
            } message: {
                Text("This statement period (\(pendingStatementPeriod)) has already been imported with \(existingTransactionCount) transactions.\n\nReplacing will remove all existing transactions for this period and import the new ones.")
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
                let parser = UberStatementManager.shared
                guard let statementInfo = try parser.parseStatementPeriod(from: pdfText) else {
                    throw UberImportError.statementPeriodNotFound
                }

                // Parse transactions from PDF (using coordinate-based parsing)
                var transactions = try await parser.parseStatement(from: url)

                // Add metadata to all transactions
                let importDate = Date()
                for i in 0..<transactions.count {
                    transactions[i].statementPeriod = statementInfo.period
                    transactions[i].importDate = importDate
                    transactions[i].shiftID = nil  // Start as orphaned
                }

                // Check if statement period already exists
                let transactionManager = UberTransactionManager.shared
                if transactionManager.hasStatementPeriod(statementInfo.period) {
                    // Statement period exists - ask user for confirmation
                    let existingCount = transactionManager.getTransactions(forStatementPeriod: statementInfo.period).count

                    await MainActor.run {
                        pendingStatementPeriod = statementInfo.period
                        pendingTransactions = transactions
                        existingTransactionCount = existingCount
                        isProcessing = false
                        showingReplaceConfirmation = true
                    }
                    return
                }

                // New statement period - proceed with import
                await performImport(transactions: transactions, statementPeriod: statementInfo.period)

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

    private func updateAffectedShifts(_ shiftIDs: Set<UUID>) async throws -> [RideshareShift] {
        var updatedShifts: [RideshareShift] = []

        for shiftID in shiftIDs {
            await MainActor.run {
                guard let index = dataManager.shifts.firstIndex(where: { $0.id == shiftID }) else { return }
                var shift = dataManager.shifts[index]

                // Get all transactions for this shift
                let transactions = UberTransactionManager.shared.getTransactions(forShift: shiftID)

                // Remove existing Uber transaction images before adding new one
                let existingUberAttachments = shift.imageAttachments.filter { $0.type == .importedUberTxns }
                for attachment in existingUberAttachments {
                    ImageManager.shared.deleteImage(attachment, for: shift.id, parentType: .shift)
                }
                shift.imageAttachments.removeAll { $0.type == .importedUberTxns }

                if transactions.isEmpty {
                    // Shift lost all transactions - clear Uber data
                    shift.tips = nil
                    shift.tollsReimbursed = nil
                    shift.uberImportDate = nil
                } else {
                    let totals = transactions.totals()

                    // Update shift with aggregated data
                    shift.tips = totals.tips
                    shift.tollsReimbursed = totals.tollsReimbursed
                    shift.uberImportDate = Date()

                    // Generate and attach transaction detail image
                    if let image = UberTransactionImageGenerator.generate(
                        transactions: transactions,
                        shift: shift
                    ) {
                        if let attachment = try? ImageManager.shared.saveImage(
                            image,
                            for: shift.id,
                            parentType: .shift,
                            type: .importedUberTxns,
                            description: "Uber Import - \(transactions.count) transactions"
                        ) {
                            shift.imageAttachments.append(attachment)
                        }
                    }
                }

                // Save updated shift
                dataManager.shifts[index] = shift
                updatedShifts.append(shift)
            }
        }

        return updatedShifts
    }

    /// Performs the actual import of transactions (used for both new imports and replacements)
    private func performImport(transactions: [UberTransaction], statementPeriod: String) async {
        do {
            // Match transactions to shifts
            let matcher = UberShiftMatcher()
            let (matched, unmatched) = matcher.matchTransactionsToShifts(
                transactions: transactions,
                existingShifts: dataManager.shifts
            )

            // Process matched - assign shiftID and save to manager
            var affectedShiftIDs: Set<UUID> = []
            for match in matched {
                var transaction = match.transaction
                transaction.shiftID = match.shift.id
                UberTransactionManager.shared.saveTransaction(transaction)
                affectedShiftIDs.insert(match.shift.id)
            }

            // Save unmatched transactions as orphans (shiftID = nil)
            for transaction in unmatched {
                UberTransactionManager.shared.saveTransaction(transaction)
            }

            // Recalculate all affected shifts
            let updatedShifts = try await updateAffectedShifts(affectedShiftIDs)

            // Generate missing shifts CSV
            let csvGenerator = MissingShiftsCSVGenerator()
            let missingShiftsCSV = try csvGenerator.generateMissingShiftsCSV(
                unmatchedTransactions: unmatched,
                statementPeriod: statementPeriod
            )

            // Create result
            let result = UberImportResult(
                statementPeriod: statementPeriod,
                totalTransactions: transactions.count,
                matchedCount: matched.count,
                unmatchedCount: unmatched.count,
                updatedShifts: updatedShifts,
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

    /// Performs statement period replacement when user confirms
    private func performStatementPeriodReplacement() {
        isProcessing = true

        Task {
            // Get affected shifts BEFORE replacement (shifts that have transactions from this period)
            let transactionManager = UberTransactionManager.shared
            let affectedShiftIDsBefore = transactionManager.getAffectedShiftIDs(forStatementPeriod: pendingStatementPeriod)

            // Perform atomic replacement
            transactionManager.replaceStatementPeriod(pendingStatementPeriod, with: pendingTransactions)

            // Now perform the import to match and update
            await performImport(transactions: pendingTransactions, statementPeriod: pendingStatementPeriod)

            // Also update shifts that lost ALL their transactions from this period
            // (they may not be in the new matched set but need their data cleared)
            let newAffectedShiftIDs = transactionManager.getAffectedShiftIDs(forStatementPeriod: pendingStatementPeriod)
            let shiftsToCleanup = affectedShiftIDsBefore.subtracting(newAffectedShiftIDs)

            if !shiftsToCleanup.isEmpty {
                _ = try? await updateAffectedShifts(shiftsToCleanup)
            }

            // Clear pending state
            await MainActor.run {
                pendingTransactions = []
                pendingStatementPeriod = ""
                existingTransactionCount = 0
            }
        }
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
    let missingShiftsCSV: String?
}

// MARK: - Preview

#Preview {
    UberImportView()
        .environmentObject(ShiftDataManager.shared)
}
