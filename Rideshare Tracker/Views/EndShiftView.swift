//
//  EndShiftView.swift
//  Rideshare Tracker
//
//  Created by George Knaggs with Claude AI assistance on 8/10/25.
//

import SwiftUI
import PhotosUI

@MainActor
struct EndShiftView: View {
    @Binding var shift: RideshareShift
    @EnvironmentObject var dataManager: ShiftDataManager
    @EnvironmentObject var preferencesManager: PreferencesManager
    @Environment(\.presentationMode) var presentationMode

    private var preferences: AppPreferences { preferencesManager.preferences }
    
    @State private var endDate = Date()
    @State private var endMileage = ""
    @State private var didRefuel = false
    @State private var refuelGallons = ""
    @State private var refuelCost: Double? = nil
    @State private var tankReading: Double
    @State private var totalTrips = ""
    @State private var netFare: Double? = nil
    @State private var tips: Double? = nil
    @State private var promotions: Double? = nil
    @State private var totalTolls: Double? = nil
    @State private var tollsReimbursed: Double? = nil
    @State private var parkingFees: Double? = nil
    @State private var miscFees: Double? = nil
    @State private var odometerError = ""
    @State private var showEndDatePicker = false
    @State private var showEndTimePicker = false
    @State private var showEndDateTextInput = false
    @State private var endDateText = ""
    @State private var showEndTimeTextInput = false
    @State private var endTimeText = ""
    @State private var showTankTextInput = false
    @State private var tankText = ""
    @FocusState private var focusedField: FocusedField?

    // Photo attachment state
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var photoImages: [UIImage] = []

    // UIImagePickerController state
    @State private var showingCameraPicker = false
    @State private var showingPhotoLibraryPicker = false
    @State private var showingImageSourceActionSheet = false

    // Image viewer state
    @State private var showingImageViewer = false
    @State private var viewerImages: [UIImage] = []
    @State private var viewerStartIndex: Int = 0

    enum FocusedField {
        case endMileage, refuelGallons, refuelCost, trips, netFare, tips, promotions, totalTolls, tollsReimbursed, parkingFees, miscFees
    }
    
    init(shift: Binding<RideshareShift>) {
        self._shift = shift
        self._tankReading = State(initialValue: shift.wrappedValue.startTankReading)
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
        return allLevels.filter { $0.1 <= shift.startTankReading }
    }
    
    var body: some View {
        NavigationView {
            formContent
        }
        .sheet(isPresented: $showingImageViewer) {
            ImageViewerView(
                images: $viewerImages,
                startingIndex: viewerStartIndex,
                isPresented: $showingImageViewer
            )
        }
        .imagePickerSheets(
            showingCameraPicker: $showingCameraPicker,
            showingPhotoLibraryPicker: $showingPhotoLibraryPicker,
            onImageSelected: { image in
                photoImages.append(image)
            }
        )
    }
    
    private var mainContent: some View {
        formContent
    }
    
    private var formContent: some View {
        Form {
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
                        Text("End Odometer Reading")
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
                            .accessibilityIdentifier("end_mileage_input")
                    }
                    
                    if !odometerError.isEmpty {
                        Text(odometerError)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                    
                    Toggle("Refueled Tank", isOn: $didRefuel)
                        .accessibilityIdentifier("refueled_tank_toggle")
                    
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
                                .accessibilityIdentifier("gallons_filled_input")
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
                                .accessibilityIdentifier("fuel_cost_input")
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Tank Level")
                                    .font(.headline)
                                Spacer()
                                Button(action: {
                                    tankText = String(format: "%.0f", tankReading)
                                    showTankTextInput = true
                                }) {
                                    Image(systemName: "keyboard")
                                        .font(.title3)
                                        .foregroundColor(.blue)
                                }
                                .accessibilityIdentifier("end_tank_text_input_button")
                                .accessibilityLabel("Enter tank level as number")
                                .padding(.trailing, 8)
                            }

                            Picker("Tank Reading", selection: $tankReading) {
                                ForEach(availableTankLevels, id: \.value) { level in
                                    Text(level.label).tag(level.value)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                }
                
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
                            .focused($focusedField, equals: .trips)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(focusedField == .trips ? Color.accentColor : Color.clear, lineWidth: 2)
                            )
                            .accessibilityIdentifier("trip_count_input")
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
                            .accessibilityIdentifier("net_fare_input")
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
                            .accessibilityIdentifier("promotions_input")
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
                            .accessibilityIdentifier("tips_input")
                    }
                }
                
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
                            .accessibilityIdentifier("tolls_input")
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
                            .accessibilityIdentifier("tolls_reimbursed_input")
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
                            .accessibilityIdentifier("parking_fees_input")
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
                            .accessibilityIdentifier("misc_fees_input")
                    }
                }

                PhotosSection(
                    photoImages: $photoImages,
                    showingImageSourceActionSheet: $showingImageSourceActionSheet,
                    showingCameraPicker: $showingCameraPicker,
                    showingPhotoLibraryPicker: $showingPhotoLibraryPicker,
                    showingImageViewer: $showingImageViewer,
                    viewerImages: $viewerImages,
                    viewerStartIndex: $viewerStartIndex
                )
            }
            .navigationTitle("End Shift")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar(content: {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        hideKeyboard()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        endShift()
                    }
                    .disabled(endMileage.isEmpty || totalTrips.isEmpty || !odometerError.isEmpty)
                    .accessibilityIdentifier("confirm_save_shift_button")
                }
            })
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
        .alert("Enter Tank Level", isPresented: $showTankTextInput) {
            TextField("0 to 8", text: $tankText)
                .keyboardType(.decimalPad)
            Button("Set Level") {
                setTankFromText()
            }
            Button("Cancel", role: .cancel) {
                tankText = ""
            }
        } message: {
            Text("Enter: 0 (Empty) to 8 (Full)")
        }
    }
    
    
    private func validateOdometerReading() {
        guard let endMiles = Double(endMileage), endMiles > 0 else {
            odometerError = ""
            return
        }
        
        let startMiles = shift.startMileage
        if endMiles <= startMiles {
            odometerError = "End reading must be greater than start reading (\(String(format: "%.1f", startMiles)) miles)"
        } else {
            odometerError = ""
        }
    }
    
    private func endShift() {
        shift.endDate = endDate
        shift.endMileage = Double(endMileage)
        shift.didRefuelAtEnd = didRefuel
        
        if didRefuel {
            shift.refuelGallons = Double(refuelGallons)
            shift.refuelCost = refuelCost
            shift.endTankReading = 8.0 // Assume full after refuel
        } else {
            shift.endTankReading = tankReading
        }
        
        shift.trips = Int(totalTrips)
        shift.netFare = netFare
        shift.tips = tips
        shift.promotions = promotions
        shift.tolls = totalTolls
        shift.tollsReimbursed = tollsReimbursed
        shift.parkingFees = parkingFees
        shift.miscFees = miscFees
        
        // Always capture current preference values when ending shift (when calculations become meaningful)
        if didRefuel, let cost = refuelCost, let gallons = Double(refuelGallons), gallons > 0 {
            shift.gasPrice = cost / gallons  // Calculate from actual refuel data
        } else {
            shift.gasPrice = preferences.gasPrice  // Use preference as fallback
        }
        shift.standardMileageRate = preferences.standardMileageRate

        // Save photos and create attachments
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

    private func setEndDateFromText() {
        let formatter = DateFormatter()
        formatter.dateFormat = preferences.dateFormat

        if let date = formatter.date(from: endDateText) {
            print("✅ [EndShiftView] Date parsed successfully: '\(endDateText)' using format '\(preferences.dateFormat)'")
            // Preserve the time from current endDate, only update the date part
            let calendar = Calendar.current
            let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
            let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: endDate)

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
            debugMessage("Failed to parse date: '\(endDateText)' - expected format '\(preferences.dateFormat)' (example: '\(preferencesManager.formatDate(Date()))')")
        }
    }

    private func setEndTimeFromText() {
        let formatter = DateFormatter()
        formatter.dateFormat = preferences.timeFormat

        if let time = formatter.date(from: endTimeText) {
            print("✅ [EndShiftView] Time parsed successfully: '\(endTimeText)' using format '\(preferences.timeFormat)'")
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
            debugMessage("Failed to parse time: '\(endTimeText)' - expected format '\(preferences.timeFormat)' (example: '\(preferencesManager.formatTime(Date()))')")
        }
    }

    private func setTankFromText() {
        if let tankValue = Double(tankText), tankValue >= 0 && tankValue <= 8 {
            tankReading = tankValue
            tankText = ""
        }
    }
}
