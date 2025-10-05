//
//  StartShiftView.swift
//  Rideshare Tracker
//
//  Created by George Knaggs with Claude AI assistance on 8/10/25.
//

import SwiftUI
import PhotosUI

@MainActor
struct StartShiftView: View {
    @EnvironmentObject var dataManager: ShiftDataManager
    @EnvironmentObject var preferences: AppPreferences
    @Environment(\.presentationMode) var presentationMode
    
    var onShiftStarted: ((Date) -> Void)? = nil
    
    @State private var startDate = Date()
    @State private var startMileage: Double?
    @State private var tankReading = 8.0 // Default to full tank (8/8)
    @State private var showDatePicker = false
    @State private var showTimePicker = false
    @State private var showDateTextInput = false
    @State private var dateText = ""
    @State private var showTimeTextInput = false
    @State private var timeText = ""
    @State private var showTankTextInput = false
    @State private var tankText = ""
    @FocusState private var focusedField: FocusedField?

    // Photo attachment state
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var photoImages: [UIImage] = []

    // UIImagePickerController state (NEW IMPLEMENTATION)
    @State private var showingCameraPicker = false
    @State private var showingPhotoLibraryPicker = false
    @State private var showingImageSourceActionSheet = false

    // Image viewer state
    @State private var showingImageViewer = false
    @State private var viewerImages: [UIImage] = []
    @State private var viewerStartIndex: Int = 0
    
    enum FocusedField {
        case mileage, date, time
    }
    
    var body: some View {
        NavigationView {
            formContent
                .navigationTitle("Start Shift")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Start") {
                            startShift()
                        }
                        .disabled(startMileage == nil)
                        .accessibilityIdentifier("confirm_start_shift_button")
                    }
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") {
                            hideKeyboard()
                        }
                    }
                }
        }
        .sheet(isPresented: $showingImageViewer) {
            ImageViewerView(
                images: photoImages,
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
        .alert("Enter Date", isPresented: $showDateTextInput) {
            TextField(preferences.formatDate(Date()), text: $dateText)
                .keyboardType(.numbersAndPunctuation)
            Button("Set Date") {
                setDateFromText()
            }
            Button("Cancel", role: .cancel) {
                dateText = ""
            }
        } message: {
            Text("Format: \(preferences.formatDate(Date()))")
        }
        .alert("Enter Time", isPresented: $showTimeTextInput) {
            TextField(preferences.formatTime(Date()), text: $timeText)
                .keyboardType(.numbersAndPunctuation)
            Button("Set Time") {
                setTimeFromText()
            }
            Button("Cancel", role: .cancel) {
                timeText = ""
            }
        } message: {
            Text("Format: \(preferences.formatTime(Date()))")
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
    
    private var formContent: some View {
        Form {
            Section("Shift Start Time") {
                Button(action: {
                    focusedField = .date
                    showDatePicker.toggle()
                }) {
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
                .accessibilityIdentifier("start_date_button")
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(focusedField == .date ? Color.accentColor : Color.clear, lineWidth: 2)
                )
                
                if showDatePicker {
                    VStack {
                        DatePicker("", selection: $startDate, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .labelsHidden()

                        KeyboardInputUtility.keyboardInputButton(
                            currentValue: preferences.formatDate(startDate),
                            showingAlert: $showDateTextInput,
                            inputText: $dateText,
                            accessibilityId: "start_date_text_input_button",
                            accessibilityLabel: "Enter start date as text"
                        )
                    }
                }
                
                Button(action: {
                    focusedField = .time
                    showTimePicker.toggle()
                }) {
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
                .accessibilityIdentifier("start_time_button")
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(focusedField == .time ? Color.accentColor : Color.clear, lineWidth: 2)
                )
                
                if showTimePicker {
                    VStack {
                        DatePicker("", selection: $startDate, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.wheel)
                            .labelsHidden()

                        KeyboardInputUtility.keyboardInputButton(
                            currentValue: preferences.formatTime(startDate),
                            showingAlert: $showTimeTextInput,
                            inputText: $timeText,
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
                    CalculatorTextField(placeholder: "Miles", value: $startMileage, formatter: .mileage)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)
                        .focused($focusedField, equals: .mileage)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(focusedField == .mileage ? Color.accentColor : Color.clear, lineWidth: 2)
                        )
                        .accessibilityIdentifier("start_mileage_input")
                }
                
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
                        .accessibilityIdentifier("start_tank_text_input_button")
                        .accessibilityLabel("Enter tank level as number")
                        .padding(.trailing, 8)
                    }

                    Picker("Tank Reading", selection: $tankReading) {
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
    }
    
    private func startShift() {
        guard let mileage = startMileage else { return }

        var shift = RideshareShift(
            startDate: startDate,
            startMileage: mileage,
            startTankReading: tankReading,
            hasFullTankAtStart: tankReading == 8.0,
            gasPrice: preferences.gasPrice,
            standardMileageRate: preferences.standardMileageRate
        )

        // Save photos and create attachments
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

        dataManager.addShift(shift)
        onShiftStarted?(startDate)
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

    private func setDateFromText() {
        let formatter = DateFormatter()
        formatter.dateFormat = preferences.dateFormat

        if let date = formatter.date(from: dateText) {
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
                showDatePicker = false // Close the date picker after setting
                dateText = "" // Clear the text field
            }
        } else {
            // Could add an error alert here, but for now just keep the picker open
            // so user can try again or use the graphical picker
        }
    }

    private func setTimeFromText() {
        let formatter = DateFormatter()
        formatter.dateFormat = preferences.timeFormat

        if let time = formatter.date(from: timeText) {
            // Combine the date part from startDate with the time part from the input
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
                showTimePicker = false // Close the time picker after setting
                timeText = "" // Clear the text field
            }
        } else {
            // Could add an error alert here, but for now just keep the picker open
            // so user can try again or use the graphical picker
        }
    }

    private func setTankFromText() {
        if let tankValue = Double(tankText), tankValue >= 0 && tankValue <= 8 {
            tankReading = tankValue
            tankText = "" // Clear the text field
        } else {
            // Could add an error alert here, but for now just keep the input open
            // so user can try again
        }
    }
}

