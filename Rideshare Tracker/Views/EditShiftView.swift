//
//  EditShiftView.swift
//  Rideshare Tracker
//
//  Created by George Knaggs with Claude AI assistance on 8/10/25.
//

import SwiftUI
import PhotosUI

@MainActor
struct EditShiftView: View {
    @Binding var shift: RideshareShift
    @EnvironmentObject var dataManager: ShiftDataManager
    @EnvironmentObject var preferences: AppPreferences
    @Environment(\.presentationMode) var presentationMode
    
    // Start shift data
    @State private var startDate: Date
    @State private var startMileage: String
    @State private var startTankReading: Double
    @State private var showStartDatePicker = false
    @State private var showStartTimePicker = false
    @FocusState private var focusedField: FocusedField?
    
    enum FocusedField {
        case startMileage, endMileage, refuelGallons, refuelCost, totalTrips, netFare, tips, promotions, totalTolls, tollsReimbursed, parkingFees, miscFees, gasPrice, standardMileageRate
    }
    
    // End shift data
    @State private var endDate: Date
    @State private var endMileage: String
    @State private var didRefuel: Bool
    @State private var refuelGallons: String
    @State private var refuelCost: Double?
    @State private var endTankReading: Double
    @State private var totalTrips: String
    @State private var netFare: Double?
    @State private var tips: Double?
    @State private var promotions: Double?
    @State private var totalTolls: Double?
    @State private var tollsReimbursed: Double?
    @State private var parkingFees: Double?
    @State private var miscFees: Double?
    @State private var gasPrice: Double?
    @State private var standardMileageRate: Double?
    @State private var showEndDatePicker = false
    @State private var showEndTimePicker = false
    @State private var odometerError = ""

    // Photo attachment state
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var photoImages: [UIImage] = []
    @State private var existingAttachments: [ImageAttachment] = []
    
    init(shift: Binding<RideshareShift>) {
        self._shift = shift
        
        // Initialize start shift data
        self._startDate = State(initialValue: shift.wrappedValue.startDate)
        self._startMileage = State(initialValue: String(shift.wrappedValue.startMileage))
        self._startTankReading = State(initialValue: shift.wrappedValue.startTankReading)
        
        // Initialize end shift data
        self._endDate = State(initialValue: shift.wrappedValue.endDate ?? Date())
        self._endMileage = State(initialValue: shift.wrappedValue.endMileage?.description ?? "")
        self._didRefuel = State(initialValue: shift.wrappedValue.didRefuelAtEnd ?? false)
        self._refuelGallons = State(initialValue: shift.wrappedValue.refuelGallons?.description ?? "")
        self._refuelCost = State(initialValue: shift.wrappedValue.refuelCost)
        self._endTankReading = State(initialValue: shift.wrappedValue.endTankReading ?? 8.0)
        self._totalTrips = State(initialValue: shift.wrappedValue.trips?.description ?? "")
        self._netFare = State(initialValue: shift.wrappedValue.netFare)
        self._tips = State(initialValue: shift.wrappedValue.tips)
        self._promotions = State(initialValue: shift.wrappedValue.promotions)
        self._totalTolls = State(initialValue: shift.wrappedValue.tolls)
        self._tollsReimbursed = State(initialValue: shift.wrappedValue.tollsReimbursed)
        self._parkingFees = State(initialValue: shift.wrappedValue.parkingFees)
        self._miscFees = State(initialValue: shift.wrappedValue.miscFees)
        self._gasPrice = State(initialValue: shift.wrappedValue.gasPrice)
        self._standardMileageRate = State(initialValue: shift.wrappedValue.standardMileageRate)

        // Initialize photo attachments
        self._existingAttachments = State(initialValue: shift.wrappedValue.imageAttachments)
    }
    
    private var availableTankLevels: [(label: String, value: Double)] {
        let allLevels = [
            ("E", 0.0),
            ("1/8", 1.0),
            ("1/4", 2.0),
            ("3/8", 3.0),
            ("1/2", 4.0),
            ("5/8", 5.0),
            ("3/4", 6.0),
            ("7/8", 7.0),
            ("F", 8.0)
        ]
        return allLevels.filter { $0.1 <= startTankReading }
    }
    
    var body: some View {
        NavigationView {
            mainContent
                .navigationTitle("Edit Shift")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") {
                            hideKeyboard()
                        }
                    }
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") {
                            saveShift()
                        }
                        .disabled(startMileage.isEmpty || !odometerError.isEmpty)
                    }
                }
        }
    }
    
    private var mainContent: some View {
        Form {
            startSection
            
            if shift.endDate != nil {
                endSection
                earningsSection
                expensesSection
            }

            photosSection
        }
    }
    
    
    private var startSection: some View {
        Group {
            Section("Shift Start") {
                Button(action: { showStartDatePicker.toggle() }) {
                    HStack {
                        Text("Date")
                            .foregroundColor(.primary)
                        Spacer()
                        Text(preferences.formatDate(startDate))
                            .foregroundColor(.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                }
                
                if showStartDatePicker {
                    DatePicker("", selection: $startDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                }
                
                Button(action: { showStartTimePicker.toggle() }) {
                    HStack {
                        Text("Time")
                            .foregroundColor(.primary)
                        Spacer()
                        Text(preferences.formatTime(startDate))
                            .foregroundColor(.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                }
                
                if showStartTimePicker {
                    DatePicker("", selection: $startDate, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                }
            }
            
            Section("Vehicle Information") {
                HStack {
                    Text("Start Odometer Reading (miles)")
                    Spacer()
                    CalculatorTextField(placeholder: "Miles", value: Binding(
                        get: { Double(startMileage) ?? 0.0 },
                        set: { newValue in startMileage = newValue > 0 ? String(newValue) : "" }
                    ), formatter: .mileage, keyboardType: .decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)
                        .focused($focusedField, equals: .startMileage)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(focusedField == .startMileage ? Color.accentColor : Color.clear, lineWidth: 2)
                        )
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tank Level")
                        .font(.headline)
                    
                    Picker("Tank Reading", selection: $startTankReading) {
                        Text("E").tag(0.0)
                        Text("1/8").tag(1.0)
                        Text("1/4").tag(2.0)
                        Text("3/8").tag(3.0)
                        Text("1/2").tag(4.0)
                        Text("5/8").tag(5.0)
                        Text("3/4").tag(6.0)
                        Text("7/8").tag(7.0)
                        Text("F").tag(8.0)
                    }
                    .pickerStyle(.segmented)
                }
            }
        }
    }
    
    private var endSection: some View {
        Group {
            Section("Shift End") {
                Button(action: { showEndDatePicker.toggle() }) {
                    HStack {
                        Text("Date")
                            .foregroundColor(.primary)
                        Spacer()
                        Text(preferences.formatDate(endDate))
                            .foregroundColor(.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                }
                
                if showEndDatePicker {
                    DatePicker("", selection: $endDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                }
                
                Button(action: { showEndTimePicker.toggle() }) {
                    HStack {
                        Text("Time")
                            .foregroundColor(.primary)
                        Spacer()
                        Text(preferences.formatTime(endDate))
                            .foregroundColor(.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                }
                
                if showEndTimePicker {
                    DatePicker("", selection: $endDate, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                }
            }
            
            Section("Vehicle Information") {
                
                HStack {
                    Text("End Odometer Reading (miles)")
                    Spacer()
                    CalculatorTextField(placeholder: "Miles", value: Binding(
                        get: { Double(endMileage) ?? 0.0 },
                        set: { newValue in 
                            endMileage = newValue > 0 ? String(newValue) : ""
                            validateOdometerReading()
                        }
                    ), formatter: .mileage, keyboardType: .decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)
                        .focused($focusedField, equals: .endMileage)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(focusedField == .endMileage ? Color.accentColor : Color.clear, lineWidth: 2)
                        )
                }
                
                if !odometerError.isEmpty {
                    Text(odometerError)
                        .foregroundColor(.red)
                        .font(.caption)
                }
                
                HStack {
                    Text("Refueled Tank")
                    Spacer()
                    Toggle("", isOn: $didRefuel)
                }
                
                if didRefuel {
                    HStack {
                        Text("Gallons Filled")
                        Spacer()
                        CalculatorTextField(placeholder: "Gallons", value: Binding(
                            get: { Double(refuelGallons) ?? 0.0 },
                            set: { newValue in refuelGallons = newValue > 0 ? String(newValue) : "" }
                        ), formatter: .gallons, keyboardType: .decimalPad)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120)
                            .focused($focusedField, equals: .refuelGallons)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(focusedField == .refuelGallons ? Color.accentColor : Color.clear, lineWidth: 2)
                            )
                    }
                    HStack {
                        Text("Fuel Cost")
                        Spacer()
                        CurrencyTextField(placeholder: "$0.00", value: $refuelCost)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120)
                            .focused($focusedField, equals: .refuelCost)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(focusedField == .refuelCost ? Color.accentColor : Color.clear, lineWidth: 2)
                            )
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tank Level")
                            .font(.headline)
                        Picker("Tank Reading", selection: $endTankReading) {
                            ForEach(availableTankLevels, id: \.value) { level in
                                Text(level.label).tag(level.value)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
                
                Divider()
                
                HStack {
                    Text("Gas Price")
                    Spacer()
                    CurrencyTextField(placeholder: "$0.000", value: $gasPrice)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)
                        .focused($focusedField, equals: .gasPrice)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(focusedField == .gasPrice ? Color.accentColor : Color.clear, lineWidth: 2)
                        )
                }
                
                HStack {
                    Text("Mileage Rate")
                    Spacer()
                    CurrencyTextField(placeholder: "$0.000", value: $standardMileageRate)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)
                        .focused($focusedField, equals: .standardMileageRate)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(focusedField == .standardMileageRate ? Color.accentColor : Color.clear, lineWidth: 2)
                        )
                }
            }
        }
    }
    
    private var earningsSection: some View {
        Section("Trip & Earnings Data") {
            HStack {
                Text("# Trips")
                Spacer()
                CalculatorTextField(placeholder: "0", intValue: Binding(
                    get: { Int(totalTrips) },
                    set: { newValue in totalTrips = newValue != nil && newValue! > 0 ? String(newValue!) : "" }
                ), keyboardType: .numberPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    .focused($focusedField, equals: .totalTrips)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(focusedField == .totalTrips ? Color.accentColor : Color.clear, lineWidth: 2)
                    )
            }
            HStack {
                Text("Net Fare")
                Spacer()
                CurrencyTextField(placeholder: "$0.00", value: $netFare)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120)
                    .focused($focusedField, equals: .netFare)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(focusedField == .netFare ? Color.accentColor : Color.clear, lineWidth: 2)
                    )
            }
            HStack {
                Text("Promotions")
                Spacer()
                CurrencyTextField(placeholder: "$0.00", value: $promotions)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120)
                    .focused($focusedField, equals: .promotions)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(focusedField == .promotions ? Color.accentColor : Color.clear, lineWidth: 2)
                    )
            }
            HStack {
                Text("Tips")
                Spacer()
                CurrencyTextField(placeholder: "$0.00", value: $tips)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120)
                    .focused($focusedField, equals: .tips)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(focusedField == .tips ? Color.accentColor : Color.clear, lineWidth: 2)
                    )
            }
        }
    }
    
    private var expensesSection: some View {
        Section("Additional Expenses") {
            HStack {
                Text("Tolls")
                Spacer()
                CurrencyTextField(placeholder: "$0.00", value: $totalTolls)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120)
                    .focused($focusedField, equals: .totalTolls)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(focusedField == .totalTolls ? Color.accentColor : Color.clear, lineWidth: 2)
                    )
            }
            HStack {
                Text("Tolls Reimbursed")
                Spacer()
                CurrencyTextField(placeholder: "$0.00", value: $tollsReimbursed)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120)
                    .focused($focusedField, equals: .tollsReimbursed)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(focusedField == .tollsReimbursed ? Color.accentColor : Color.clear, lineWidth: 2)
                    )
            }
            HStack {
                Text("Parking Fees")
                Spacer()
                CurrencyTextField(placeholder: "$0.00", value: $parkingFees)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120)
                    .focused($focusedField, equals: .parkingFees)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(focusedField == .parkingFees ? Color.accentColor : Color.clear, lineWidth: 2)
                    )
            }
            HStack {
                Text("Misc Fees")
                Spacer()
                CurrencyTextField(placeholder: "$0.00", value: $miscFees)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120)
                    .focused($focusedField, equals: .miscFees)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(focusedField == .miscFees ? Color.accentColor : Color.clear, lineWidth: 2)
                    )
            }
        }
    }

    private var photosSection: some View {
        Section("Photos") {
            PhotosPicker(
                selection: $selectedPhotos,
                maxSelectionCount: 10,
                matching: .images
            ) {
                Label("Add Photos", systemImage: "camera.fill")
                    .foregroundColor(.accentColor)
            }
            .onChange(of: selectedPhotos) { oldItems, newItems in
                Task {
                    await loadSelectedPhotos(from: newItems)
                }
            }

            if !photoImages.isEmpty {
                Text("\(photoImages.count) photo\(photoImages.count == 1 ? "" : "s") selected")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Display existing photos
            if !existingAttachments.isEmpty {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                    ForEach(existingAttachments, id: \.id) { attachment in
                        AsyncImage(url: attachment.fileURL(for: shift.id, parentType: .shift)) { image in
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
                        .overlay(
                            Button(action: { removeExistingPhoto(attachment) }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                                    .background(Color.white, in: Circle())
                            }
                            .offset(x: 8, y: -8),
                            alignment: .topTrailing
                        )
                    }
                }
                .padding(.vertical, 4)
            }

            // Display new photos
            if !photoImages.isEmpty {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                    ForEach(Array(photoImages.enumerated()), id: \.offset) { index, image in
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 80, height: 80)
                            .clipped()
                            .cornerRadius(8)
                            .overlay(
                                Button(action: { removeNewPhoto(at: index) }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                        .background(Color.white, in: Circle())
                                }
                                .offset(x: 8, y: -8),
                                alignment: .topTrailing
                            )
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func validateOdometerReading() {
        guard let endMiles = Double(endMileage), endMiles > 0 else {
            odometerError = ""
            return
        }
        
        let startMiles = Double(startMileage) ?? 0
        if endMiles <= startMiles {
            odometerError = "End reading must be greater than start reading (\(startMiles.formattedMileage) miles)"
        } else {
            odometerError = ""
        }
    }
    
    private func saveShift() {
        // Update start shift data
        shift.startDate = startDate
        shift.startMileage = Double(startMileage) ?? shift.startMileage
        shift.hasFullTankAtStart = startTankReading == 8.0
        shift.startTankReading = startTankReading
        
        // Update end shift data if shift is completed
        if shift.endDate != nil {
            shift.endDate = endDate
            shift.endMileage = Double(endMileage)
            shift.didRefuelAtEnd = didRefuel
            
            if didRefuel {
                shift.refuelGallons = Double(refuelGallons)
                shift.refuelCost = refuelCost
                shift.endTankReading = 8.0 // Assume full after refuel
            } else {
                shift.endTankReading = endTankReading
            }
            
            shift.trips = Int(totalTrips)
            shift.netFare = netFare
            shift.tips = tips
            shift.promotions = promotions
            shift.tolls = totalTolls
            shift.tollsReimbursed = tollsReimbursed
            shift.parkingFees = parkingFees
            shift.miscFees = miscFees
            shift.gasPrice = gasPrice
            shift.standardMileageRate = standardMileageRate
        }

        // Handle photo changes
        // Remove deleted photos and update the shift's attachments
        shift.imageAttachments = existingAttachments

        // Save new photos and add them to the shift
        for (index, image) in photoImages.enumerated() {
            do {
                let attachment = try ImageManager.shared.saveImage(
                    image,
                    for: shift.id,
                    parentType: .shift,
                    type: .screenshot // Default to screenshot for now - could add type selection later
                )
                shift.imageAttachments.append(attachment)
            } catch {
                print("Failed to save shift photo \(index): \(error)")
                // Continue with other photos even if one fails
            }
        }

        dataManager.updateShift(shift)
        presentationMode.wrappedValue.dismiss()
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func loadSelectedPhotos(from items: [PhotosPickerItem]) async {
        await MainActor.run {
            photoImages.removeAll()
        }

        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run {
                    photoImages.append(image)
                }
            }
        }
    }

    private func removeExistingPhoto(_ attachment: ImageAttachment) {
        // Remove from existing attachments
        existingAttachments.removeAll { $0.id == attachment.id }

        // Also remove the physical file
        ImageManager.shared.deleteImage(attachment, for: shift.id, parentType: .shift)
    }

    private func removeNewPhoto(at index: Int) {
        photoImages.remove(at: index)
        selectedPhotos.remove(at: index)
    }
}
