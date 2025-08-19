//
//  ContentView.swift
//  Rideshare Tracker
//
//  Created by George Knaggs with Claude AI assistance on 8/10/25.
//  Optimized for iOS Universal (iPhone, iPad, Mac) on 8/19/25
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
                            Text(DateFormatter.weekRange.string(from: selectedDate))
                                .font(.headline)
                        }
                        .popover(isPresented: $showingDatePicker) {
                            DatePicker("Select Date", 
                                     selection: $selectedDate, 
                                     displayedComponents: .date)
                                .datePickerStyle(GraphicalDatePickerStyle())
                                .padding()
                                .onChange(of: selectedDate) { _ in
                                    showingDatePicker = false
                                }
                        }
                        
                        Spacer()
                        
                        Button(action: { moveWeek(1) }) {
                            Image(systemName: "chevron.right")
                                .font(.title2)
                        }
                        .disabled(isCurrentWeek)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    // Summary Cards
                    summaryCardsView
                }
                .background(Color(UIColor.systemGroupedBackground))
                
                // Content Area
                if currentWeekShifts.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "car.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text("No shifts for this week")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        
                        Text("Tap the + button to start a shift")
                            .font(.body)
                            .foregroundColor(.secondary)
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingPreferences = true }) {
                        Image(systemName: "gearshape")
                    }
                }
                
                ToolbarItem(placement: .principal) {
                    Text("Rideshare Tracker")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingStartShift = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingStartShift) {
                StartShiftView(onShiftStarted: navigateToWeekContaining)
            }
            .sheet(isPresented: $showingPreferences) {
                PreferencesView()
                    .environmentObject(dataManager)
                    .environmentObject(preferences)
            }
        }
    }
    
    private var summaryCardsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                let weekTotals = self.weekTotals
                let monthTotals = self.monthTotals 
                let yearTotals = self.yearTotals
                
                SummaryCard(
                    title: "Week Totals",
                    paymentDue: weekTotals.paymentDue,
                    trips: weekTotals.trips,
                    miles: weekTotals.miles,
                    hours: weekTotals.hours,
                    grossProfit: calculateGrossProfit(for: weekShifts),
                    grossProfitPerHour: calculateGrossProfitPerHour(for: weekShifts),
                    color: .blue
                )
                
                SummaryCard(
                    title: "Month Totals", 
                    paymentDue: monthTotals.paymentDue,
                    trips: monthTotals.trips,
                    miles: monthTotals.miles,
                    hours: monthTotals.hours,
                    grossProfit: calculateGrossProfit(for: monthShifts),
                    grossProfitPerHour: calculateGrossProfitPerHour(for: monthShifts),
                    color: .green
                )
                
                SummaryCard(
                    title: "Year Totals",
                    paymentDue: yearTotals.paymentDue,
                    trips: yearTotals.trips,
                    miles: yearTotals.miles,
                    hours: yearTotals.hours,
                    grossProfit: calculateGrossProfit(for: yearShifts),
                    grossProfitPerHour: calculateGrossProfitPerHour(for: yearShifts),
                    color: .orange
                )
            }
            .padding(.horizontal)
        }
    }
    
    private var isCurrentWeek: Bool {
        let calendar = Calendar.current
        return calendar.isDate(selectedDate, equalTo: Date(), toGranularity: .weekOfYear)
    }
    
    private var currentWeekShifts: [RideshareShift] {
        let weekInterval = getWeekInterval(for: selectedDate)
        return dataManager.shifts.filter { shift in
            weekInterval.contains(shift.startDate)
        }
    }
    
    private func getWeekInterval(for date: Date) -> DateInterval {
        let calendar = Calendar.current
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
        
        // Find the user's preferred week start day
        let preferredWeekStart = preferences.weekStartDay == 1 ? 1 : 2 // 1 = Sunday, 2 = Monday
        let currentWeekStart = calendar.component(.weekday, from: startOfWeek)
        
        var adjustedStart = startOfWeek
        if currentWeekStart != preferredWeekStart {
            let dayDifference = preferredWeekStart - currentWeekStart
            adjustedStart = calendar.date(byAdding: .day, value: dayDifference, to: startOfWeek) ?? startOfWeek
            
            // If the adjustment puts us in the future, go back a week
            if adjustedStart > date {
                adjustedStart = calendar.date(byAdding: .weekOfYear, value: -1, to: adjustedStart) ?? adjustedStart
            }
        }
        
        let endOfWeek = calendar.date(byAdding: .day, value: 6, to: adjustedStart) ?? adjustedStart
        return DateInterval(start: adjustedStart, end: endOfWeek)
    }
    
    private func moveWeek(_ direction: Int) {
        if let newDate = Calendar.current.date(byAdding: .weekOfYear, value: direction, to: selectedDate) {
            selectedDate = newDate
        }
    }
    
    private var weekTotals: (paymentDue: Double, trips: Int, miles: Double, hours: Double) {
        return calculateTotals(for: currentWeekShifts)
    }
    
    private var monthTotals: (paymentDue: Double, trips: Int, miles: Double, hours: Double) {
        let calendar = Calendar.current
        let monthShifts = dataManager.shifts.filter { shift in
            calendar.isDate(shift.startDate, equalTo: selectedDate, toGranularity: .month)
        }
        return calculateTotals(for: monthShifts)
    }
    
    private var yearTotals: (paymentDue: Double, trips: Int, miles: Double, hours: Double) {
        let calendar = Calendar.current
        let yearShifts = dataManager.shifts.filter { shift in
            calendar.isDate(shift.startDate, equalTo: selectedDate, toGranularity: .year)
        }
        return calculateTotals(for: yearShifts)
    }
    
    private var weekShifts: [RideshareShift] {
        return currentWeekShifts
    }
    
    private var monthShifts: [RideshareShift] {
        let calendar = Calendar.current
        return dataManager.shifts.filter { shift in
            calendar.isDate(shift.startDate, equalTo: selectedDate, toGranularity: .month)
        }
    }
    
    private var yearShifts: [RideshareShift] {
        let calendar = Calendar.current
        return dataManager.shifts.filter { shift in
            calendar.isDate(shift.startDate, equalTo: selectedDate, toGranularity: .year)
        }
    }
    
    private func calculateTotals(for shifts: [RideshareShift]) -> (paymentDue: Double, trips: Int, miles: Double, hours: Double) {
        let completedShifts = shifts.filter { $0.endDate != nil }
        
        let totalPaymentDue = completedShifts.reduce(0) { sum, shift in
            sum + shift.totalPaymentDue
        }
        
        let totalTrips = completedShifts.reduce(0) { sum, shift in
            sum + (shift.totalTrips ?? 0)
        }
        
        let totalMiles = completedShifts.reduce(0) { sum, shift in
            sum + shift.shiftMileage
        }
        
        let totalHours = completedShifts.reduce(0) { sum, shift in
            sum + (shift.shiftDuration / 3600.0)
        }
        
        return (totalPaymentDue, totalTrips, totalMiles, totalHours)
    }
    
    private func calculateGrossProfit(for shifts: [RideshareShift]) -> Double {
        let completedShifts = shifts.filter { $0.endDate != nil }
        return completedShifts.reduce(0) { sum, shift in
            sum + shift.grossProfit(tankCapacity: preferences.tankCapacity, gasPrice: preferences.gasPrice)
        }
    }
    
    private func calculateGrossProfitPerHour(for shifts: [RideshareShift]) -> Double {
        let completedShifts = shifts.filter { $0.endDate != nil }
        let totalProfit = calculateGrossProfit(for: completedShifts)
        let totalHours = completedShifts.reduce(0) { sum, shift in
            sum + (shift.shiftDuration / 3600.0)
        }
        
        return totalHours > 0 ? totalProfit / totalHours : 0
    }
    
    func deleteShifts(offsets: IndexSet) {
        let sortedShifts = currentWeekShifts.sorted(by: { $0.startDate > $1.startDate })
        for index in offsets {
            dataManager.deleteShift(sortedShifts[index])
        }
    }
    
    private func navigateToWeekContaining(_ date: Date) {
        selectedDate = date
    }
}

struct SummaryCard: View {
    let title: String
    let paymentDue: Double
    let trips: Int
    let miles: Double
    let hours: Double
    let grossProfit: Double
    let grossProfitPerHour: Double
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("$\(paymentDue, specifier: "%.0f")")
                .font(.headline)
                .foregroundColor(color)
            
            Text("\(trips) trips")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("\(miles.formattedMileageInteger) mi")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("\(Int(hours))h \(Int((hours.truncatingRemainder(dividingBy: 1)) * 60))m")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("$\(grossProfit, specifier: "%.0f")")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("$\(grossProfitPerHour, specifier: "%.2f")/hr")
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