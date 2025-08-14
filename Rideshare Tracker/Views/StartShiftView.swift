//
//  StartShiftView.swift
//  Rideshare Tracker
//
//  Created by George Knaggs with Claude AI assistance on 8/10/25.
//

import SwiftUI

struct StartShiftView: View {
    @EnvironmentObject var dataManager: ShiftDataManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var startDate = Date()
    @State private var startMileage = ""
    @State private var hasFullTank = false
    @State private var tankReading = 8.0 // Default to full tank (8/8)
    
    var body: some View {
        NavigationView {
            Form {
                Section("Shift Start Time") {
                    DatePicker("", selection: $startDate)
                        .datePickerStyle(.compact)
                }
                
                Section("Vehicle Information") {
                    HStack {
                        Text("Current Odometer Reading")
                        Spacer()
                        TextField("Miles", text: $startMileage)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                    }
                    
                    Toggle("Full Tank of Gas", isOn: $hasFullTank)
                    
                    if !hasFullTank {
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
                            .pickerStyle(SegmentedPickerStyle())
                        }
                    }
                }
            }
            .navigationTitle("Start Shift")
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
                    Button("Start") {
                        startShift()
                    }
                    .disabled(startMileage.isEmpty)
                }
            }
        }
    }
    
    private func startShift() {
        guard let mileage = Double(startMileage) else { return }
        
        let shift = RideshareShift(
            startDate: startDate,
            startMileage: mileage,
            startTankReading: hasFullTank ? 8.0 : tankReading,
            hasFullTankAtStart: hasFullTank
        )
        
        dataManager.addShift(shift)
        presentationMode.wrappedValue.dismiss()
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
