//
//  ShiftDataManager.swift
//  Rideshare Tracker
//
//  Created by George on 8/10/25.
//


import Foundation

class ShiftDataManager: ObservableObject {
    @Published var shifts: [RideshareShift] = []
    
    init() {
        loadShifts()
    }
    
    private func loadShifts() {
        if let data = UserDefaults.standard.data(forKey: "shifts") {
            if let decodedShifts = try? JSONDecoder().decode([RideshareShift].self, from: data) {
                shifts = decodedShifts
            }
        }
    }
    
    func saveShifts() {
        if let encodedData = try? JSONEncoder().encode(shifts) {
            UserDefaults.standard.set(encodedData, forKey: "shifts")
        }
    }
    
    func addShift(_ shift: RideshareShift) {
        shifts.append(shift)
        saveShifts()
    }
    
    func updateShift(_ shift: RideshareShift) {
        if let index = shifts.firstIndex(where: { $0.id == shift.id }) {
            shifts[index] = shift
            saveShifts()
        }
    }
    
    func deleteShift(_ shift: RideshareShift) {
        shifts.removeAll { $0.id == shift.id }
        saveShifts()
    }
}