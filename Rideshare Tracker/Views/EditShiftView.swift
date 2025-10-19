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
    @EnvironmentObject var preferencesManager: PreferencesManager
    @Environment(\.presentationMode) var presentationMode

    private var preferences: AppPreferences { preferencesManager.preferences }
    
    // Start shift data
    @State private var startDate: Date
    @State private var startMileage: String
    @State private var startTankReading: Double
    @State private var showStartDatePicker = false
    @State private var showStartTimePicker = false
    @State private var showStartDateTextInput = false
    @State private var startDateText = ""
    @State private var showStartTimeTextInput = false
    @State private var startTimeText = ""
    @State private var showStartTankTextInput = false
    @State private var startTankText = ""
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
    @State private var showEndDateTextInput = false
    @State private var endDateText = ""
    @State private var showEndTimeTextInput = false
    @State private var endTimeText = ""
    @State private var showEndTankTextInput = false
    @State private var endTankText = ""
    @State private var odometerError = ""

    // Photo attachment state
    @State private var photoImages: [UIImage] = []
    @State private var existingAttachments: [ImageAttachment] = []
    @State private var existingImages: [UIImage] = []
    @State private var attachmentsMarkedForDeletion: [ImageAttachment] = []

    // UIImagePickerController state
    @State private var showingCameraPicker = false
    @State private var showingPhotoLibraryPicker = false
    @State private var showingImageSourceActionSheet = false

    // Image viewer state
    @State private var showingImageViewer = false
    @State private var viewerImages: [UIImage] = []
    @State private var viewerStartIndex: Int = 0
    
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
        .sheet(isPresented: $showingImageViewer) {
            ImageViewerView(
                images: $viewerImages,
                startingIndex: viewerStartIndex,
                isPresented: $showingImageViewer
            )
            .onAppear {
                if viewerImages.isEmpty {
                    viewerImages = loadAllImages()
                }
            }
        }
        .imagePickerSheets(
            showingCameraPicker: $showingCameraPicker,
            showingPhotoLibraryPicker: $showingPhotoLibraryPicker,
            onImageSelected: { image in
                photoImages.append(image)
            }
        )
        .alert("Enter Start Date", isPresented: $showStartDateTextInput) {
            TextField(preferencesManager.formatDate(Date()), text: $startDateText)
                .keyboardType(.numbersAndPunctuation)
            Button("Set Date") {
                setStartDateFromText()
            }
            Button("Cancel", role: .cancel) {
                startDateText = ""
            }
        } message: {
            Text("Format: \(preferencesManager.formatDate(Date()))")
        }
        .alert("Enter Start Time", isPresented: $showStartTimeTextInput) {
            TextField(preferencesManager.formatTime(Date()), text: $startTimeText)
                .keyboardType(.numbersAndPunctuation)
            Button("Set Time") {
                setStartTimeFromText()
            }
            Button("Cancel", role: .cancel) {
                startTimeText = ""
            }
        } message: {
            Text("Format: \(preferencesManager.formatTime(Date()))")
        }
        .alert("Enter Start Tank Level", isPresented: $showStartTankTextInput) {
            TextField("0 to 8", text: $startTankText)
                .keyboardType(.decimalPad)
            Button("Set Level") {
                setStartTankFromText()
            }
            Button("Cancel", role: .cancel) {
                startTankText = ""
            }
        } message: {
            Text("Enter: 0 (Empty) to 8 (Full)")
        }
        .alert("Enter End Date", isPresented: $showEndDateTextInput) {
            TextField(preferencesManager.formatDate(Date()), text: $endDateText)
                .keyboardType(.numbersAndPunctuation)
            Button("Set Date") {
                setEndDateFromText()
            }
            Button("Cancel", role: .cancel) {
                endDateText = ""
            }
        } message: {
            Text("Format: \(preferencesManager.formatDate(Date()))")
        }
        .alert("Enter End Time", isPresented: $showEndTimeTextInput) {
            TextField(preferencesManager.formatTime(Date()), text: $endTimeText)
                .keyboardType(.numbersAndPunctuation)
            Button("Set Time") {
                setEndTimeFromText()
            }
            Button("Cancel", role: .cancel) {
                endTimeText = ""
            }
        } message: {
            Text("Format: \(preferencesManager.formatTime(Date()))")
        }
        .alert("Enter End Tank Level", isPresented: $showEndTankTextInput) {
            TextField("0 to 8", text: $endTankText)
                .keyboardType(.decimalPad)
            Button("Set Level") {
                setEndTankFromText()
            }
            Button("Cancel", role: .cancel) {
                endTankText = ""
            }
        } message: {
            Text("Enter: 0 (Empty) to 8 (Full)")
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
        .onAppear {
            loadExistingImages()
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
                        Text(preferencesManager.formatDate(startDate))
                            .foregroundColor(.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                }
                .accessibilityIdentifier("start_date_button")
                
                if showStartDatePicker {
                    VStack {
                        DatePicker("", selection: $startDate, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .labelsHidden()

                        KeyboardInputUtility.keyboardInputButton(
                            currentValue: preferencesManager.formatDate(startDate),
                            showingAlert: $showStartDateTextInput,
                            inputText: $startDateText,
                            accessibilityId: "start_date_text_input_button",
                            accessibilityLabel: "Enter start date as text"
                        )
                    }
                }
                
                Button(action: { showStartTimePicker.toggle() }) {
                    HStack {
                        Text("Time")
                            .foregroundColor(.primary)
                        Spacer()
                        Text(preferencesManager.formatTime(startDate))
                            .foregroundColor(.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                }
                .accessibilityIdentifier("start_time_button")
                
                if showStartTimePicker {
                    VStack {
                        DatePicker("", selection: $startDate, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.wheel)
                            .labelsHidden()

                        KeyboardInputUtility.keyboardInputButton(
                            currentValue: preferencesManager.formatTime(startDate),
                            showingAlert: $showStartTimeTextInput,
                            inputText: $startTimeText,
                            accessibilityId: "start_time_text_input_button",
                            accessibilityLabel: "Enter start time as text"
                        )
                    }
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
                    HStack {
                        Text("Tank Level")
                            .font(.headline)
                        Spacer()
                        Button(action: {
                            startTankText = String(format: "%.0f", startTankReading)
                            showStartTankTextInput = true
                        }) {
                            Image(systemName: "keyboard")
                                .font(.title3)
                                .foregroundColor(.blue)
                        }
                        .accessibilityIdentifier("start_tank_text_input_button")
                        .accessibilityLabel("Enter start tank level as number")
                        .padding(.trailing, 8)
                    }

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
                        Text(preferencesManager.formatDate(endDate))
                            .foregroundColor(.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                }
                .accessibilityIdentifier("end_date_button")
                
                if showEndDatePicker {
                    VStack {
                        DatePicker("", selection: $endDate, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .labelsHidden()

                        KeyboardInputUtility.keyboardInputButton(
                            currentValue: preferencesManager.formatDate(endDate),
                            showingAlert: $showEndDateTextInput,
                            inputText: $endDateText,
                            accessibilityId: "end_date_text_input_button",
                            accessibilityLabel: "Enter end date as text"
                        )
                    }
                }
                
                Button(action: { showEndTimePicker.toggle() }) {
                    HStack {
                        Text("Time")
                            .foregroundColor(.primary)
                        Spacer()
                        Text(preferencesManager.formatTime(endDate))
                            .foregroundColor(.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                }
                .accessibilityIdentifier("end_time_button")
                
                if showEndTimePicker {
                    VStack {
                        DatePicker("", selection: $endDate, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.wheel)
                            .labelsHidden()

                        KeyboardInputUtility.keyboardInputButton(
                            currentValue: preferencesManager.formatTime(endDate),
                            showingAlert: $showEndTimeTextInput,
                            inputText: $endTimeText,
                            accessibilityId: "end_time_text_input_button",
                            accessibilityLabel: "Enter end time as text"
                        )
                    }
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
                        HStack {
                            Text("Tank Level")
                                .font(.headline)
                            Spacer()
                            Button(action: {
                                endTankText = String(format: "%.0f", endTankReading)
                                showEndTankTextInput = true
                            }) {
                                Image(systemName: "keyboard")
                                    .font(.title3)
                                    .foregroundColor(.blue)
                            }
                            .accessibilityIdentifier("end_tank_text_input_button")
                            .accessibilityLabel("Enter end tank level as number")
                            .padding(.trailing, 8)
                        }

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
        PhotosSection(
            photoImages: $photoImages,
            existingImages: $existingImages,
            onDeleteExisting: { index in
                // Mark attachment for deletion (don't delete file yet)
                let attachment = existingAttachments[index]
                attachmentsMarkedForDeletion.append(attachment)

                // Remove from display arrays
                existingAttachments.remove(at: index)
                existingImages.remove(at: index)

                // DO NOT delete the physical file here - wait for Save
            },
            showingImageSourceActionSheet: $showingImageSourceActionSheet,
            showingCameraPicker: $showingCameraPicker,
            showingPhotoLibraryPicker: $showingPhotoLibraryPicker,
            showingImageViewer: $showingImageViewer,
            viewerImages: $viewerImages,
            viewerStartIndex: $viewerStartIndex
        )
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
            shift.gasPrice = gasPrice ?? preferences.gasPrice
            shift.standardMileageRate = standardMileageRate ?? preferences.standardMileageRate
        }

        // Handle photo changes
        // Step 1: Update attachments array (remove deleted, keep existing)
        shift.imageAttachments = existingAttachments

        // Save new photos and add them to the shift
        for (index, image) in photoImages.enumerated() {
            do {
                let attachment = try ImageManager.shared.saveImage(
                    image,
                    for: shift.id,
                    parentType: .shift,
                    type: .other // Default type for user-added photos
                )
                shift.imageAttachments.append(attachment)
            } catch {
                debugMessage("Failed to save shift photo \(index): \(error)")
                // Continue with other photos even if one fails
            }
        }

        // Step 2: Save shift to disk (commits all changes)
        dataManager.updateShift(shift)

        // Step 3: ONLY AFTER successful save, physically delete marked files
        for attachment in attachmentsMarkedForDeletion {
            ImageManager.shared.deleteImage(attachment, for: shift.id, parentType: .shift)
        }

        presentationMode.wrappedValue.dismiss()
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func loadExistingImages() {
        debugMessage("EditShiftView loadExistingImages: Starting with \(existingAttachments.count) attachments")
        existingImages.removeAll()

        for (index, attachment) in existingAttachments.enumerated() {
            debugMessage("EditShiftView loadExistingImages: Loading attachment \(index): \(attachment.filename)")
            if let image = ImageManager.shared.loadImage(
                for: shift.id,
                parentType: .shift,
                filename: attachment.filename
            ) {
                existingImages.append(image)
                debugMessage("EditShiftView loadExistingImages: Successfully loaded \(attachment.filename)")
            } else {
                debugMessage("EditShiftView loadExistingImages: Failed to load \(attachment.filename)")
            }
        }

        debugMessage("EditShiftView loadExistingImages: Final existingImages.count=\(existingImages.count)")
    }

    private func loadAllImages() -> [UIImage] {
        var allImages: [UIImage] = []

        // Load existing attachments
        for existingAttachment in existingAttachments {
            if let image = ImageManager.shared.loadImage(
                for: shift.id,
                parentType: .shift,
                filename: existingAttachment.filename
            ) {
                allImages.append(image)
            }
        }

        // Add new images
        allImages.append(contentsOf: photoImages)

        return allImages
    }

    private func showImage(at index: Int) {
        guard !showingImageViewer else { return }

        let allImages = loadAllImages()
        ImageViewingUtilities.showImageViewer(
            images: allImages,
            startIndex: index,
            viewerImages: $viewerImages,
            viewerStartIndex: $viewerStartIndex,
            showingImageViewer: $showingImageViewer
        )
    }

    private func setStartDateFromText() {
        let formatter = DateFormatter()
        formatter.dateFormat = preferences.dateFormat

        if let date = formatter.date(from: startDateText) {
            debugMessage("Start date parsed successfully: '\(startDateText)' using format '\(preferences.dateFormat)'")
            // Preserve the time from current startDate, only update the date part
            let calendar = Calendar.current
            let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
            let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: startDate)

            var combinedComponents = DateComponents()
            combinedComponents.year = dateComponents.year
            combinedComponents.month = dateComponents.month
            combinedComponents.day = dateComponents.day
            combinedComponents.hour = timeComponents.hour
            combinedComponents.minute = timeComponents.minute
            combinedComponents.second = timeComponents.second

            if let combinedDate = calendar.date(from: combinedComponents) {
                startDate = combinedDate
                showStartDatePicker = false
                startDateText = ""
            }
        } else {
            debugMessage("Failed to parse start date: '\(startDateText)' - expected format '\(preferences.dateFormat)' (example: '\(preferencesManager.formatDate(Date()))')")
        }
    }

    private func setStartTimeFromText() {
        let formatter = DateFormatter()
        formatter.dateFormat = preferences.timeFormat

        if let time = formatter.date(from: startTimeText) {
            debugMessage("Start time parsed successfully: '\(startTimeText)' using format '\(preferences.timeFormat)'")
            let calendar = Calendar.current
            let dateComponents = calendar.dateComponents([.year, .month, .day], from: startDate)
            let timeComponents = calendar.dateComponents([.hour, .minute], from: time)

            var combinedComponents = DateComponents()
            combinedComponents.year = dateComponents.year
            combinedComponents.month = dateComponents.month
            combinedComponents.day = dateComponents.day
            combinedComponents.hour = timeComponents.hour
            combinedComponents.minute = timeComponents.minute

            if let combinedDate = calendar.date(from: combinedComponents) {
                startDate = combinedDate
                showStartTimePicker = false
                startTimeText = ""
            }
        } else {
            debugMessage("Failed to parse start time: '\(startTimeText)' - expected format '\(preferences.timeFormat)' (example: '\(preferencesManager.formatTime(Date()))')")
        }
    }

    private func setStartTankFromText() {
        if let tankValue = Double(startTankText), tankValue >= 0 && tankValue <= 8 {
            startTankReading = tankValue
            startTankText = ""
        }
    }

    private func setEndDateFromText() {
        let formatter = DateFormatter()
        formatter.dateFormat = preferences.dateFormat

        if let date = formatter.date(from: endDateText) {
            debugMessage("End date parsed successfully: '\(endDateText)' using format '\(preferences.dateFormat)'")
            // Preserve the time from current endDate, only update the date part
            let calendar = Calendar.current
            let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
            let timeComponents = calendar.dateComponents([.year, .month, .day], from: endDate)

            var combinedComponents = DateComponents()
            combinedComponents.year = dateComponents.year
            combinedComponents.month = dateComponents.month
            combinedComponents.day = dateComponents.day
            combinedComponents.hour = timeComponents.hour
            combinedComponents.minute = timeComponents.minute
            combinedComponents.second = timeComponents.second

            if let combinedDate = calendar.date(from: combinedComponents) {
                endDate = combinedDate
                showEndDatePicker = false
                endDateText = ""
            }
        } else {
            debugMessage("Failed to parse end date: '\(endDateText)' - expected format '\(preferences.dateFormat)' (example: '\(preferencesManager.formatDate(Date()))')")
        }
    }

    private func setEndTimeFromText() {
        let formatter = DateFormatter()
        formatter.dateFormat = preferences.timeFormat

        if let time = formatter.date(from: endTimeText) {
            debugMessage("End time parsed successfully: '\(endTimeText)' using format '\(preferences.timeFormat)'")
            let calendar = Calendar.current
            let dateComponents = calendar.dateComponents([.year, .month, .day], from: endDate)
            let timeComponents = calendar.dateComponents([.hour, .minute], from: time)

            var combinedComponents = DateComponents()
            combinedComponents.year = dateComponents.year
            combinedComponents.month = dateComponents.month
            combinedComponents.day = dateComponents.day
            combinedComponents.hour = timeComponents.hour
            combinedComponents.minute = timeComponents.minute

            if let combinedDate = calendar.date(from: combinedComponents) {
                endDate = combinedDate
                showEndTimePicker = false
                endTimeText = ""
            }
        } else {
            debugMessage("Failed to parse end time: '\(endTimeText)' - expected format '\(preferences.timeFormat)' (example: '\(preferencesManager.formatTime(Date()))')")
        }
    }

    private func setEndTankFromText() {
        if let tankValue = Double(endTankText), tankValue >= 0 && tankValue <= 8 {
            endTankReading = tankValue
            endTankText = ""
        }
    }
}
