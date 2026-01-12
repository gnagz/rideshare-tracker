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

    @State private var showingFilePicker = true  // Auto-show on appear
    @State private var hasSelectedFiles = false  // Track if user selected files
    @State private var isProcessing = false
    @State private var showingResults = false
    @State private var importResult: UberImportResult?
    @State private var errorMessage: String?
    @State private var showingError = false

    // State for processing and duplicate confirmation
    @State private var processingProgress: (current: Int, total: Int, filename: String)?
    @State private var pendingURLs: [URL] = []
    @State private var duplicatesWithCounts: [(period: String, matched: Int, orphan: Int)] = []
    @State private var showingReplaceConfirmation = false

    /// Dialog title adapts to single vs multiple duplicates
    private var replaceDialogTitle: String {
        duplicatesWithCounts.count == 1
            ? "Previously Imported Statement"
            : "Previously Imported Statements"
    }

    /// Dialog button text adapts to single vs multiple
    private var replaceButtonText: String {
        duplicatesWithCounts.count == 1 ? "Replace" : "Replace All"
    }

    /// Format the duplicate warning message with matched/orphan counts
    private var duplicateWarningMessage: String {
        if duplicatesWithCounts.count == 1 {
            let dup = duplicatesWithCounts[0]
            return "\(dup.period) has \(dup.matched) matched and \(dup.orphan) unmatched transactions.\n\nReplace will remove existing transactions and re-import from the PDF."
        } else {
            let lines = duplicatesWithCounts.map { dup in
                "\(dup.period): \(dup.matched) matched, \(dup.orphan) unmatched"
            }
            return "The following statements have previously matched transactions:\n\n\(lines.joined(separator: "\n"))\n\nReplace All will remove existing transactions and re-import from the PDFs."
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Spacer()

                // Processing indicator
                if isProcessing {
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.blue)

                        if let progress = processingProgress, progress.total > 1 {
                            ProgressView(value: Double(progress.current), total: Double(progress.total))
                                .padding(.horizontal, 40)
                            Text("Processing \(progress.current) of \(progress.total)")
                                .font(.headline)
                            Text(progress.filename)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else if let progress = processingProgress {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Processing")
                                .font(.headline)
                            Text(progress.filename)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Processing...")
                                .font(.headline)
                        }
                    }
                } else if !showingFilePicker && hasSelectedFiles {
                    // Waiting for results to show
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Preparing results...")
                            .font(.headline)
                    }
                }

                Spacer()
            }
            .navigationTitle("Uber Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .disabled(isProcessing)
                }
            }
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: true
            ) { result in
                handleFileSelection(result)
            }
            .onChange(of: showingFilePicker) { _, isShowing in
                // If file picker closed without selecting files, dismiss this view
                if !isShowing && !hasSelectedFiles && !isProcessing && !showingResults {
                    presentationMode.wrappedValue.dismiss()
                }
            }
            .sheet(isPresented: $showingResults, onDismiss: {
                // When result sheet closes, dismiss this view too
                presentationMode.wrappedValue.dismiss()
            }) {
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
            .alert(replaceDialogTitle, isPresented: $showingReplaceConfirmation) {
                Button(replaceButtonText, role: .destructive) {
                    processWithReplacement()
                }
                Button("Cancel", role: .cancel) {
                    pendingURLs = []
                    duplicatesWithCounts = []
                }
            } message: {
                Text(duplicateWarningMessage)
            }
        }
    }

    // MARK: - Import Logic

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard !urls.isEmpty else { return }
            hasSelectedFiles = true
            processBatch(urls: urls)
        case .failure(let error):
            errorMessage = "Failed to select file: \(error.localizedDescription)"
            showingError = true
        }
    }

    /// Process one or more PDF files (single file = batch of 1)
    private func processBatch(urls: [URL]) {
        // Pre-scan all files for duplicates with matched transactions
        isProcessing = true
        Task {
            await MainActor.run {
                processingProgress = (current: 0, total: urls.count, filename: "Checking for duplicates...")
            }

            let duplicates = await preScanForDuplicates(urls: urls)

            await MainActor.run {
                processingProgress = nil
                isProcessing = false

                if !duplicates.isEmpty {
                    // Show confirmation dialog - there are matched transactions that would be replaced
                    pendingURLs = urls
                    duplicatesWithCounts = duplicates
                    showingReplaceConfirmation = true
                } else {
                    // No matched duplicates - proceed directly
                    // (orphan-only periods will be silently replaced)
                    pendingURLs = urls
                    processWithReplacement()
                }
            }
        }
    }

    /// Pre-scan PDFs to find which statement periods have matched transactions that would be replaced
    /// Returns array of (period, matchedCount, orphanCount) for periods with matched transactions
    private func preScanForDuplicates(urls: [URL]) async -> [(period: String, matched: Int, orphan: Int)] {
        var duplicates: [(period: String, matched: Int, orphan: Int)] = []
        let transactionManager = UberTransactionManager.shared
        let parser = UberStatementManager.shared

        for url in urls {
            guard url.startAccessingSecurityScopedResource() else { continue }
            defer { url.stopAccessingSecurityScopedResource() }

            guard let pdfDocument = PDFDocument(url: url) else { continue }
            let pdfText = extractText(from: pdfDocument)

            if let statementInfo = try? parser.parseStatementPeriod(from: pdfText) {
                // Only flag as duplicate if there are MATCHED transactions
                // Orphan-only periods can be silently re-imported to try matching again
                if transactionManager.hasMatchedTransactions(forStatementPeriod: statementInfo.period) {
                    let counts = transactionManager.getTransactionCounts(forStatementPeriod: statementInfo.period)
                    duplicates.append((period: statementInfo.period, matched: counts.matched, orphan: counts.orphan))
                }
            }
        }

        return duplicates
    }

    /// Process files with replacement (called after user confirms or if no duplicates)
    private func processWithReplacement() {
        let urls = pendingURLs
        guard !urls.isEmpty else { return }

        isProcessing = true

        Task {
            var statementResults: [SingleStatementResult] = []
            var allUnmatchedTransactions: [UberTransaction] = []
            var affectedShiftIDs: Set<UUID> = []
            var allMatchedCount = 0
            var allUnmatchedCount = 0
            var allImportableCount = 0
            var allTransactionCount = 0
            var allVerificationCount = 0

            // Process each PDF sequentially
            for (index, url) in urls.enumerated() {
                // Update progress
                await MainActor.run {
                    processingProgress = (current: index + 1, total: urls.count, filename: url.lastPathComponent)
                }

                // Process this PDF
                let result = await processSinglePDF(
                    url: url,
                    affectedShiftIDs: &affectedShiftIDs,
                    allUnmatchedTransactions: &allUnmatchedTransactions,
                    allMatchedCount: &allMatchedCount,
                    allUnmatchedCount: &allUnmatchedCount,
                    allImportableCount: &allImportableCount,
                    allTransactionCount: &allTransactionCount,
                    allVerificationCount: &allVerificationCount
                )

                statementResults.append(result)
            }

            // Clear pending state
            await MainActor.run {
                pendingURLs = []
                duplicatesWithCounts = []
            }

            // All PDFs processed - update affected shifts once at the end
            let updatedShifts: [RideshareShift]
            do {
                updatedShifts = try await updateAffectedShifts(affectedShiftIDs)
            } catch {
                updatedShifts = []
            }

            // Force UI refresh
            await MainActor.run {
                dataManager.objectWillChange.send()
            }

            // Sort results by statement period date
            let sortedResults = statementResults.sorted { parseStartDate($0.statementPeriod) < parseStartDate($1.statementPeriod) }

            // Generate combined missing shifts CSV
            var missingShiftsCSV: String? = nil
            if !allUnmatchedTransactions.isEmpty {
                let csvGenerator = MissingShiftsCSVGenerator()
                let dateRange = calculateDateRange(from: sortedResults)

                missingShiftsCSV = try? csvGenerator.generateMissingShiftsCSV(
                    unmatchedTransactions: allUnmatchedTransactions,
                    statementPeriod: dateRange
                )
            }

            // Create combined result
            let combinedPeriod = calculateCombinedPeriod(from: sortedResults)
            let result = UberImportResult(
                statementPeriod: combinedPeriod,
                totalTransactions: allTransactionCount,
                importableCount: allImportableCount,
                matchedCount: allMatchedCount,
                unmatchedCount: allUnmatchedCount,
                transactionsNeedingVerification: allVerificationCount,
                updatedShifts: updatedShifts,
                missingShiftsCSV: missingShiftsCSV,
                statementResults: sortedResults
            )

            await MainActor.run {
                importResult = result
                processingProgress = nil
                isProcessing = false
                showingResults = true
            }
        }
    }

    /// Calculate combined period description from statement results
    private func calculateCombinedPeriod(from results: [SingleStatementResult]) -> String {
        let successful = results.filter { $0.success }
        guard !successful.isEmpty else { return "No statements processed" }

        if successful.count == 1 {
            return successful[0].statementPeriod
        }

        // Results are already sorted, show range from first start to last end
        return calculateDateRange(from: successful)
    }

    /// Calculate date range string from earliest start to latest end date
    /// Input: "Oct 13, 2025 - Oct 20, 2025", "Oct 20, 2025 - Oct 27, 2025"
    /// Output: "Oct 13, 2025 - Oct 27, 2025"
    private func calculateDateRange(from results: [SingleStatementResult]) -> String {
        let successful = results.filter { $0.success }
        guard !successful.isEmpty else { return "" }

        if successful.count == 1 {
            return successful[0].statementPeriod
        }

        // Extract earliest start date and latest end date
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"

        var earliestStart: Date?
        var latestEnd: Date?

        for result in successful {
            let parts = result.statementPeriod.components(separatedBy: " - ")
            if parts.count == 2 {
                if let startDate = formatter.date(from: parts[0].trimmingCharacters(in: .whitespaces)) {
                    if earliestStart == nil || startDate < earliestStart! {
                        earliestStart = startDate
                    }
                }
                if let endDate = formatter.date(from: parts[1].trimmingCharacters(in: .whitespaces)) {
                    if latestEnd == nil || endDate > latestEnd! {
                        latestEnd = endDate
                    }
                }
            }
        }

        if let start = earliestStart, let end = latestEnd {
            return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
        }

        // Fallback to first and last period strings
        return "\(successful.first!.statementPeriod) through \(successful.last!.statementPeriod)"
    }

    /// Parse start date from statement period string (e.g., "Oct 13, 2025 - Oct 20, 2025")
    private func parseStartDate(_ period: String) -> Date {
        let parts = period.components(separatedBy: " - ")
        guard !parts.isEmpty else { return Date.distantFuture }

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.date(from: parts[0].trimmingCharacters(in: .whitespaces)) ?? Date.distantFuture
    }

    /// Process a single PDF file
    private func processSinglePDF(
        url: URL,
        affectedShiftIDs: inout Set<UUID>,
        allUnmatchedTransactions: inout [UberTransaction],
        allMatchedCount: inout Int,
        allUnmatchedCount: inout Int,
        allImportableCount: inout Int,
        allTransactionCount: inout Int,
        allVerificationCount: inout Int
    ) async -> SingleStatementResult {

        // Start security-scoped resource access
        guard url.startAccessingSecurityScopedResource() else {
            return SingleStatementResult(
                filename: url.lastPathComponent,
                statementPeriod: "Unknown",
                success: false,
                errorMessage: "Cannot access file. Please try again.",
                matchedCount: 0,
                unmatchedCount: 0,
                importableCount: 0,
                ignoredCount: 0,
                wasSkippedAsDuplicate: false
            )
        }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            // Load PDF
            guard let pdfDocument = PDFDocument(url: url) else {
                throw UberImportError.invalidPDF
            }

            // Extract text and parse statement period
            let pdfText = extractText(from: pdfDocument)
            let parser = UberStatementManager.shared

            guard let statementInfo = try parser.parseStatementPeriod(from: pdfText) else {
                throw UberImportError.statementPeriodNotFound
            }

            // Check for existing statement period and replace if needed
            // (user already confirmed replacement via pre-scan, or it's orphan-only)
            let transactionManager = UberTransactionManager.shared
            if transactionManager.hasStatementPeriod(statementInfo.period) {
                // Remove old transactions first
                let affectedShiftIDsBefore = transactionManager.getAffectedShiftIDs(forStatementPeriod: statementInfo.period)
                transactionManager.deleteTransactions(forStatementPeriod: statementInfo.period)

                // Track affected shifts so they get updated at the end
                for shiftID in affectedShiftIDsBefore {
                    affectedShiftIDs.insert(shiftID)
                }
            }

            // Parse transactions
            var transactions = try parser.parseStatement(from: url)

            // Add metadata
            let importDate = Date()
            for i in 0..<transactions.count {
                transactions[i].statementPeriod = statementInfo.period
                transactions[i].importDate = importDate
                transactions[i].shiftID = nil
            }

            // Match to shifts
            let matcher = UberShiftMatcher()
            let (matched, unmatched, verificationCount) = matcher.matchTransactionsToShifts(
                transactions: transactions,
                existingShifts: await MainActor.run { dataManager.shifts }
            )

            // Save matched transactions
            for match in matched {
                var transaction = match.transaction
                transaction.shiftID = match.shift.id
                transactionManager.saveTransaction(transaction)
                affectedShiftIDs.insert(match.shift.id)
            }

            // Save unmatched as orphans
            for transaction in unmatched {
                transactionManager.saveTransaction(transaction)
            }

            // Accumulate for combined result
            allUnmatchedTransactions.append(contentsOf: unmatched)
            allMatchedCount += matched.count
            allUnmatchedCount += unmatched.count

            let importableCount = matched.count + unmatched.count
            let ignoredCount = transactions.count - importableCount

            allImportableCount += importableCount
            allTransactionCount += transactions.count
            allVerificationCount += verificationCount

            return SingleStatementResult(
                filename: url.lastPathComponent,
                statementPeriod: statementInfo.period,
                success: true,
                errorMessage: nil,
                matchedCount: matched.count,
                unmatchedCount: unmatched.count,
                importableCount: importableCount,
                ignoredCount: ignoredCount,
                wasSkippedAsDuplicate: false
            )

        } catch {
            return SingleStatementResult(
                filename: url.lastPathComponent,
                statementPeriod: "Unknown",
                success: false,
                errorMessage: error.localizedDescription,
                matchedCount: 0,
                unmatchedCount: 0,
                importableCount: 0,
                ignoredCount: 0,
                wasSkippedAsDuplicate: false
            )
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

                    // Save original manual values on first import (before overwriting)
                    if shift.originalTips == nil {
                        shift.originalTips = shift.tips
                    }
                    if shift.originalTollsReimbursed == nil {
                        shift.originalTollsReimbursed = shift.tollsReimbursed
                    }

                    // Update shift with aggregated data
                    shift.tips = totals.tips
                    shift.tollsReimbursed = totals.tollsReimbursed
                    shift.uberImportDate = Date()

                    // Reset verification flag on any import/re-import so user must re-verify
                    shift.uberDataUserVerified = false

                    // Generate and attach transaction detail image
                    if let image = UberTransactionImageGenerator.generate(
                        transactions: transactions,
                        shift: shift
                    ) {
                        do {
                            let attachment = try ImageManager.shared.saveImage(
                                image,
                                for: shift.id,
                                parentType: .shift,
                                type: .importedUberTxns,
                                description: "Uber Import - \(transactions.count) transactions"
                            )
                            shift.imageAttachments.append(attachment)
                            print("[UberImportView] Successfully saved Uber import image: \(attachment.filename)")
                        } catch {
                            print("[UberImportView] ERROR: Failed to save Uber import image: \(error.localizedDescription)")
                        }
                    } else {
                        print("[UberImportView] ERROR: Failed to generate Uber transaction image")
                    }
                }

                // Save updated shift - CRITICAL: use updateShift() to sync both
                // the shifts array AND shiftsById dictionary, and persist to UserDefaults
                dataManager.updateShift(shift)
                updatedShifts.append(shift)
            }
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

// MARK: - Preview

#Preview {
    UberImportView()
        .environmentObject(ShiftDataManager.shared)
}
