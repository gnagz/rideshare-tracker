//
//  ShiftDetailView.swift
//  Rideshare Tracker
//
//  Created by George Knaggs with Claude AI assistance on 8/10/25.
//  Optimized for iOS Universal (iPhone, iPad, Mac) on 8/19/25
//

import SwiftUI

struct ShiftDetailView: View {
    @State var shift: RideshareShift
    @EnvironmentObject var dataManager: ShiftDataManager
    @EnvironmentObject var expenseManager: ExpenseDataManager
    @EnvironmentObject var preferencesManager: PreferencesManager
    @State private var showingEndShift = false
    @State private var showingEditShift = false
    @State private var showingImageViewer = false
    @State private var selectedImageIndex = 0
    @State private var loadedImages: [UIImage] = []
    @State private var isLoadingImages = false
    @State private var viewerImages: [UIImage] = []
    @Environment(\.dismiss) private var dismiss

    private var preferences: AppPreferences { preferencesManager.preferences }

    // Get the current shift from data manager for reactive updates (O(1) lookup)
    private var currentShift: RideshareShift {
        dataManager.shift(byId: shift.id) ?? shift
    }

    private func formatDateTime(_ date: Date) -> String {
        return "\(preferencesManager.formatDate(date)) \(preferencesManager.formatTime(date))"
    }
    
    // MARK: - Shift Navigation Helpers

    /// Get the previous shift in chronological order
    private var previousShift: RideshareShift? {
        // Get all shifts before this one, sorted by date descending
        return dataManager.shifts
            .filter { $0.startDate < shift.startDate }
            .sorted { $0.startDate > $1.startDate }
            .first
    }

    /// Get the next shift in chronological order
    private var nextShift: RideshareShift? {
        // Get all shifts after this one, sorted by date ascending
        return dataManager.shifts
            .filter { $0.startDate > shift.startDate }
            .sorted { $0.startDate < $1.startDate }
            .first
    }

    /// Navigate to the previous shift
    private func navigateToPreviousShift() {
        if let previous = previousShift {
            shift = previous
        }
    }

    /// Navigate to the next shift
    private func navigateToNextShift() {
        if let next = nextShift {
            shift = next
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            let isWideScreen = geometry.size.width > 600
            
            ScrollView {
                VStack(spacing: 20) {
                    // Header with date and navigation buttons
                    VStack(spacing: 8) {
                        HStack {
                            // Previous shift button
                            Button(action: navigateToPreviousShift) {
                                Image(systemName: "chevron.left")
                                    .font(.title2)
                                    .foregroundColor(previousShift == nil ? .gray.opacity(0.3) : .blue)
                            }
                            .disabled(previousShift == nil)
                            .accessibilityLabel("Previous Shift")

                            Spacer()

                            Text(formatDateTime(shift.startDate))
                                .font(.title2)
                                .foregroundColor(.secondary)

                            Spacer()

                            // Next shift button (hidden if viewing most recent shift)
                            if nextShift != nil {
                                Button(action: navigateToNextShift) {
                                    Image(systemName: "chevron.right")
                                        .font(.title2)
                                        .foregroundColor(.blue)
                                }
                                .accessibilityLabel("Next Shift")
                            } else {
                                // Invisible placeholder to keep layout balanced
                                Image(systemName: "chevron.right")
                                    .font(.title2)
                                    .opacity(0)
                            }
                        }
                    }
                    .padding()
                    
                    if isWideScreen {
                        // Two-column layout for larger screens
                        HStack(alignment: .top, spacing: 20) {
                            // Left Column
                            VStack(spacing: 20) {
                                shiftOverviewSection
                                if shift.endDate != nil {
                                    tripDataSection
                                }
                                if shift.hasUberData {
                                    UberDataSectionView(shift: shift)
                                }
                                if !shift.imageAttachments.isEmpty {
                                    photosSection
                                }
                            }

                            // Right Column
                            VStack(spacing: 20) {
                                if shift.endDate != nil {
                                    expensesSection
                                    cashFlowSummarySection
                                }
                            }
                        }
                        .padding(.horizontal)
                    } else {
                        // Single column layout for smaller screens
                        VStack(spacing: 20) {
                            shiftOverviewSection
                            if shift.endDate != nil {
                                tripDataSection
                            }
                            if shift.hasUberData {
                                UberDataSectionView(shift: shift)
                            }
                            if shift.endDate != nil {
                                expensesSection
                                cashFlowSummarySection
                            }
                            if !shift.imageAttachments.isEmpty {
                                photosSection
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Shift Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                if shift.endDate == nil {
                    Button("End Shift") {
                        showingEndShift = true
                    }
                }
                
                Button("Edit") {
                    showingEditShift = true
                }
            }
        }
        .sheet(isPresented: $showingEndShift) {
            EndShiftView(shift: $shift)
        }
        .sheet(isPresented: $showingEditShift) {
            EditShiftView(shift: $shift)
        }
        .sheet(isPresented: $showingImageViewer) {
            ImageViewerView(
                images: $viewerImages,
                startingIndex: selectedImageIndex,
                isPresented: $showingImageViewer,
                attachments: shift.imageAttachments  // Pass attachments to show metadata
            )
            .onAppear {
                if viewerImages.isEmpty {
                    viewerImages = loadShiftImages()
                }
            }
        }
    }
    
    private var shiftOverviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Shift Overview")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 8) {
                DetailRow("Start Date & Time", formatDateTime(shift.startDate))
                
                if let endDate = shift.endDate {
                    DetailRow("End Date & Time", formatDateTime(endDate))
                    DetailRow("Duration", "\(shift.shiftHours)h \(shift.shiftMinutes)m")
                }
                
                DetailRow("Start Odometer Reading", "\(shift.startMileage.formattedMileage) mi")
                
                if shift.endDate == nil {
                    DetailRow("Tank Level", tankLevelText(shift.startTankReading))
                }
                
                if let endMileage = shift.endMileage {
                    DetailRow("End Odometer Reading", "\(endMileage.formattedMileage) mi")
                    DetailRow("Shift Mileage", "\(shift.shiftMileage.formattedMileage) mi")
                    DetailRow("Mileage Rate", String(format: "$%.3f/mi", shift.standardMileageRate))
                    DetailRow("Mileage Deduction", String(format: "$%.2f", shift.deductibleExpenses(mileageRate: shift.standardMileageRate)))
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

    private var tripDataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Trip Data")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 8) {
                DetailRow("# Trips", "\(currentShift.trips ?? 0)")
                DetailRow("Net Fare", String(format: "$%.2f", currentShift.netFare ?? 0))
                if let promotions = currentShift.promotions, promotions > 0 {
                    DetailRow("Promotions", String(format: "$%.2f", promotions))
                }
                DetailRow("Tips", String(format: "$%.2f", currentShift.tips ?? 0))
                if let cashTips = currentShift.cashTips, cashTips > 0 {
                    DetailRow("Cash Tips", String(format: "$%.2f", cashTips))
                }
                DetailRow("Revenue", String(format: "$%.2f", currentShift.revenue), valueColor: .green)
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
    
    private var expensesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Expenses")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 8) {
                DetailRow("Gas Cost", String(format: "$%.2f", currentShift.shiftGasCost(tankCapacity: preferences.tankCapacity)))
                DetailRow("Gas Used", String(format: "%.1f gal", currentShift.shiftGasUsage(tankCapacity: preferences.tankCapacity)))
                DetailRow("MPG", String(format: "%.1f", currentShift.shiftMPG(tankCapacity: preferences.tankCapacity)))

                // Show gas price used for this shift
                DetailRow("Gas Price Used", String(format: "$%.3f/gal", currentShift.gasPrice))

                if let tolls = currentShift.tolls, tolls > 0 {
                    DetailRow("Tolls", String(format: "$%.2f", tolls))
                    DetailRow("Tolls Reimbursed", String(format: "$%.2f", currentShift.tollsReimbursed ?? 0))
                }
                if let parking = currentShift.parkingFees, parking > 0 {
                    DetailRow("Parking Fees", String(format: "$%.2f", parking))
                }
                if let miscFees = currentShift.miscFees, miscFees > 0 {
                    DetailRow("Misc Fees", String(format: "$%.2f", miscFees))
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
    
    private var cashFlowSummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cash Flow Summary")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 8) {
                DetailRow("Expected Payout", String(format: "$%.2f", shift.expectedPayout), valueColor: .blue)
                if let cashTips = currentShift.cashTips, cashTips > 0 {
                    DetailRow("Cash Tips", String(format: "$%.2f", cashTips), valueColor: .green)
                }
                DetailRow("Out of Pocket Costs", String(format: "$%.2f", shift.outOfPocketCosts(tankCapacity: preferences.tankCapacity)))
                
                let profit = shift.cashFlowProfit(tankCapacity: preferences.tankCapacity)
                let profitPerHour = shift.profitPerHour(tankCapacity: preferences.tankCapacity)
                
                DetailRow("Cash Flow Profit", String(format: "$%.2f", profit), valueColor: profit >= 0 ? .green : .red)
                DetailRow("Profit/hr", String(format: "$%.2f", profitPerHour), valueColor: profitPerHour >= 0 ? .green : .red)
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

    private var photosSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Photos")
                .font(.headline)
                .foregroundColor(.primary)

            if shift.imageAttachments.isEmpty {
                Text("No photos attached")
                    .foregroundColor(.secondary)
                    .font(.body)
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray, lineWidth: 1.0)
                    )
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                    ForEach(Array(shift.imageAttachments.enumerated()), id: \.element.id) { index, attachment in
                        AsyncImage(url: ImageManager.shared.imageURL(for: shift.id, parentType: .shift, filename: attachment.filename)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray, lineWidth: 1.0)
                                )
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.systemGray5))
                                .frame(width: 80, height: 80)
                                .overlay(
                                    ProgressView()
                                        .scaleEffect(0.7)
                                )
                        }
                        .onTapGesture {
                            // Prevent multiple taps while sheet is already showing
                            guard !showingImageViewer else { return }

                            if let attachmentIndex = shift.imageAttachments.firstIndex(of: attachment) {
                                showImage(at: attachmentIndex)
                            }
                        }
                        .accessibilityIdentifier("photo_thumbnail_\(index)")
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
        .accessibilityIdentifier("PhotosSection")
    }

    @MainActor
    private func loadShiftImages() -> [UIImage] {
        print("[ShiftDetailView] loadShiftImages: shift.imageAttachments.count = \(shift.imageAttachments.count)")

        var images: [UIImage] = []

        for (index, attachment) in shift.imageAttachments.enumerated() {
            let imageURL = ImageManager.shared.imageURL(for: shift.id, parentType: .shift, filename: attachment.filename)
            let fileExists = FileManager.default.fileExists(atPath: imageURL.path)
            print("[ShiftDetailView] loadShiftImages: index=\(index), filename=\(attachment.filename), fileExists=\(fileExists)")

            if let image = ImageManager.shared.loadImage(
                for: shift.id,
                parentType: .shift,
                filename: attachment.filename
            ) {
                images.append(image)
                print("[ShiftDetailView] loadShiftImages: Successfully loaded image at index \(index)")
            } else {
                print("[ShiftDetailView] loadShiftImages: FAILED to load image at index \(index) - file exists: \(fileExists)")
            }
        }

        print("[ShiftDetailView] loadShiftImages: Returning \(images.count) images")
        return images
    }

    private func tankLevelText(_ reading: Double) -> String {
        switch reading {
        case 0.0: return "E"
        case 1.0: return "1/8"
        case 2.0: return "1/4"
        case 3.0: return "3/8"
        case 4.0: return "1/2"
        case 5.0: return "5/8"
        case 6.0: return "3/4"
        case 7.0: return "7/8"
        case 8.0: return "F"
        default: return "\(Int(reading))/8"
        }
    }

    private func showImage(at index: Int) {
        let shiftImages = loadShiftImages()
        ImageViewingUtilities.showImageViewer(
            images: shiftImages,
            startIndex: index,
            viewerImages: $viewerImages,
            viewerStartIndex: $selectedImageIndex,
            showingImageViewer: $showingImageViewer
        )
    }
}

// Helper view for detail rows
struct DetailRow: View {
    let label: String
    let value: String
    let valueColor: Color?
    
    init(_ label: String, _ value: String, valueColor: Color? = nil) {
        self.label = label
        self.value = value
        self.valueColor = valueColor
    }
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.primary)
            Spacer()
            Text(value)
                .foregroundColor(valueColor ?? .secondary)
                .fontWeight(valueColor != nil ? .semibold : .regular)
        }
        .font(.body)
    }
}
