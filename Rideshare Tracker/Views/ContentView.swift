//
//  ContentView.swift
//  Rideshare Tracker
//
//  Created by George Knaggs with Claude AI assistance on 8/10/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var dataManager: ShiftDataManager
    @EnvironmentObject var preferences: AppPreferences
    @State private var showingStartShift = false
    @State private var showingPreferences = false
    @State private var selectedDate = Date()
    @State private var showingDatePicker = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Date Navigation Header
                VStack(spacing: 8) {
                    HStack {
                        Button(action: { moveWeek(-1) }) {
                            Image(systemName: "chevron.left")
                                .font(.title2)
                        }
                        
                        Spacer()
                        
                        Button(action: { showingDatePicker.toggle() }) {
                            Text(weekHeaderText)
                                .font(.headline)
                        }
                        
                        Spacer()
                        
                        Button(action: { moveWeek(1) }) {
                            Image(systemName: "chevron.right")
                                .font(.title2)
                        }
                        .disabled(isCurrentWeek)
                    }
                    .padding(.horizontal)
                    
                    if showingDatePicker {
                        DatePicker("Select Week", selection: $selectedDate, displayedComponents: .date)
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .frame(height: 120)
                            .padding(.horizontal)
                    }
                    
                    // Summary Cards
                    summaryCardsView
                }
                .padding(.vertical)
                .background(Color(.systemGroupedBackground))
                
                Divider()
                
                // Shifts List
                if currentWeekShifts.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "car.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.blue)
                        Text("No shifts for this week")
                            .font(.headline)
                        if Calendar.current.isDate(selectedDate, equalTo: Date(), toGranularity: .weekOfYear) {
                            Text("Tap the + button to start a shift")
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    Spacer()
                } else {
                    List {
                        ForEach(currentWeekShifts.sorted(by: { $0.startDate > $1.startDate })) { shift in
                            NavigationLink(destination: ShiftDetailView(shift: shift)) {
                                ShiftRowView(shift: shift)
                            }
                        }
                        .onDelete(perform: deleteShifts)
                    }
                    .listStyle(PlainListStyle())
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
    
    private var summaryCardsView: some View {
        HStack(spacing: 12) {
            SummaryCard(
                title: "Week Totals",
                earnings: weekTotals.earnings,
                trips: weekTotals.trips,
                miles: weekTotals.miles,
                color: .blue
            )
            
            SummaryCard(
                title: "Month Totals",
                earnings: monthTotals.earnings,
                trips: monthTotals.trips,
                miles: monthTotals.miles,
                color: .green
            )
            
            SummaryCard(
                title: "Year Totals",
                earnings: yearTotals.earnings,
                trips: yearTotals.trips,
                miles: yearTotals.miles,
                color: .purple
            )
        }
        .padding(.horizontal)
    }
    
    private var weekHeaderText: String {
        let calendar = Calendar.current
        
        // Get the week interval based on the user's preferred week start day
        let weekInterval = getWeekInterval(for: selectedDate)
        let weekStart = weekInterval.start
        let weekEnd = Calendar.current.date(byAdding: .day, value: -1, to: weekInterval.end) ?? weekInterval.end
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        
        let startStr = formatter.string(from: weekStart)
        let endStr = formatter.string(from: weekEnd)
        
        let yearFormatter = DateFormatter()
        yearFormatter.dateFormat = "yyyy"
        
        return "\(startStr) - \(endStr), \(yearFormatter.string(from: weekStart))"
    }
    
    private var isCurrentWeek: Bool {
        let currentWeekInterval = getWeekInterval(for: Date())
        let selectedWeekInterval = getWeekInterval(for: selectedDate)
        return currentWeekInterval.start == selectedWeekInterval.start
    }
    
    private var currentWeekShifts: [RideshareShift] {
        let weekInterval = getWeekInterval(for: selectedDate)
        
        return dataManager.shifts.filter { shift in
            weekInterval.contains(shift.startDate)
        }
    }
    
    private func getWeekInterval(for date: Date) -> DateInterval {
        let calendar = Calendar.current
        
        // Get the weekday of the given date
        let weekday = calendar.component(.weekday, from: date)
        
        // Calculate days to subtract to get to the week start day
        let daysFromWeekStart = (weekday - preferences.weekStartDay + 7) % 7
        
        // Get the start of the week
        let weekStart = calendar.date(byAdding: .day, value: -daysFromWeekStart, to: date) ?? date
        let startOfWeekStart = calendar.startOfDay(for: weekStart)
        
        // Get the end of the week (7 days later)
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: startOfWeekStart) ?? startOfWeekStart
        
        return DateInterval(start: startOfWeekStart, end: weekEnd)
    }
    
    private func moveWeek(_ direction: Int) {
        let calendar = Calendar.current
        if let newDate = calendar.date(byAdding: .weekOfYear, value: direction, to: selectedDate) {
            selectedDate = newDate
        }
    }
    
    private var weekTotals: (earnings: Double, trips: Int, miles: Double) {
        calculateTotals(for: currentWeekShifts)
    }
    
    private var monthTotals: (earnings: Double, trips: Int, miles: Double) {
        let calendar = Calendar.current
        let monthShifts = dataManager.shifts.filter { shift in
            calendar.isDate(shift.startDate, equalTo: selectedDate, toGranularity: .month)
        }
        return calculateTotals(for: monthShifts)
    }
    
    private var yearTotals: (earnings: Double, trips: Int, miles: Double) {
        let calendar = Calendar.current
        let yearShifts = dataManager.shifts.filter { shift in
            calendar.isDate(shift.startDate, equalTo: selectedDate, toGranularity: .year)
        }
        return calculateTotals(for: yearShifts)
    }
    
    private func calculateTotals(for shifts: [RideshareShift]) -> (earnings: Double, trips: Int, miles: Double) {
        let completedShifts = shifts.filter { $0.endDate != nil }
        
        let totalEarnings = completedShifts.reduce(0) { sum, shift in
            sum + shift.totalEarnings
        }
        
        let totalTrips = completedShifts.reduce(0) { sum, shift in
            sum + (shift.totalTrips ?? 0)
        }
        
        let totalMiles = completedShifts.reduce(0) { sum, shift in
            sum + shift.shiftMileage
        }
        
        return (totalEarnings, totalTrips, totalMiles)
    }
    
    func deleteShifts(offsets: IndexSet) {
        let sortedShifts = currentWeekShifts.sorted(by: { $0.startDate > $1.startDate })
        for index in offsets {
            dataManager.deleteShift(sortedShifts[index])
        }
    }
}

struct SummaryCard: View {
    let title: String
    let earnings: Double
    let trips: Int
    let miles: Double
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("$\(earnings, specifier: "%.0f")")
                .font(.headline)
                .foregroundColor(color)
            
            Text("\(trips) trips")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("\(miles, specifier: "%.0f") mi")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}
