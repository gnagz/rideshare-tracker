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
    @FocusState private var focusedField: FocusedField?

    // Photo attachment state
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var photoImages: [UIImage] = []
    
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
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(focusedField == .date ? Color.accentColor : Color.clear, lineWidth: 2)
                )
                
                if showDatePicker {
                    DatePicker("", selection: $startDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .labelsHidden()
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
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(focusedField == .time ? Color.accentColor : Color.clear, lineWidth: 2)
                )
                
                if showTimePicker {
                    DatePicker("", selection: $startDate, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
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
                    Text("Tank Level")
                        .font(.headline)
                    
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

                if !photoImages.isEmpty {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                        ForEach(Array(photoImages.enumerated()), id: \.offset) { index, image in
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 80, height: 80)
                                .clipped()
                                .cornerRadius(8)
                                .onTapGesture {
                                    // Remove photo on tap
                                    photoImages.remove(at: index)
                                    selectedPhotos.remove(at: index)
                                }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
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
}

