import SwiftUI

struct ContentView: View {
    @EnvironmentObject var dataManager: ShiftDataManager
    @State private var showingStartShift = false
    @State private var showingPreferences = false
    
    var body: some View {
        NavigationView {
            VStack {
                if dataManager.shifts.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "car.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        Text("No shifts tracked yet")
                            .font(.headline)
                        Text("Tap the + button to start your first shift")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(dataManager.shifts.sorted(by: { $0.startDate > $1.startDate })) { shift in
                            NavigationLink(destination: ShiftDetailView(shift: shift)) {
                                ShiftRowView(shift: shift)
                            }
                        }
                        .onDelete(perform: deleteShifts)
                    }
                }
            }
            .navigationTitle("Rideshare Tracker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingStartShift = true }) {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingPreferences = true }) {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $showingStartShift) {
                StartShiftView()
            }
            .sheet(isPresented: $showingPreferences) {
                PreferencesView()
            }
        }
    }
    
    func deleteShifts(offsets: IndexSet) {
        let sortedShifts = dataManager.shifts.sorted(by: { $0.startDate > $1.startDate })
        for index in offsets {
            dataManager.deleteShift(sortedShifts[index])
        }
    }
}
