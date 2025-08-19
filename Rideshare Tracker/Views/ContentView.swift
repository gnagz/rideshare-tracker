//
//  ContentView.swift
//  Rideshare Tracker
//
//  Created by George Knaggs with Claude AI assistance on 8/10/25.
//  Updated for macOS support on 8/13/25
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var dataManager: ShiftDataManager
    @EnvironmentObject var preferences: AppPreferences
    @State private var showingStartShift = false
    @State private var showingPreferences = false
    @State private var selectedDate = Date()
    @State private var showingDatePicker = false
    @State private var selectedShift: RideshareShift?
    
    var body: some View {
        #if os(macOS)
        macOSView
        #else
        iOSView
        #endif
    }
    
    #if os(macOS)
    var macOSView: some View {
        NavigationSplitView {
            // Sidebar
            VStack(spacing: 0) {
                // Date Navigation Header
                VStack(spacing: 8) {
                    HStack {
                        Button(action: { moveWeek(-1) }) {
                            Image(systemName: "chevron.left")
                                .font(.title2)
                        }
                        .buttonStyle(.borderless)
                        
                        Spacer()
                        
                        Button(action: { showingDatePicker.toggle() }) {
                            Text(weekHeaderText)
                                .font(.headline)
                        }
                        .buttonStyle(.borderless)
                        
                        Spacer()
                        
                        Button(action: { moveWeek(1) }) {
                            Image(systemName: "chevron.right")
                                .font(.title2)
                        }
                        .buttonStyle(.borderless)
                        .disabled(isCurrentWeek)
                    }
                    .padding(.horizontal)
                    
                    if showingDatePicker {
                        DatePicker("Select Week", selection: $selectedDate, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .frame(height: 200)
                            .padding(.horizontal)
                    }
                }
                .padding(.vertical)
                .background(Color(.controlBackgroundColor))
                
                Divider()
                
                // Summary Cards
                summaryCardsView
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                
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
                            Button("Start New Shift") {
                                showingStartShift = true
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding()
                    Spacer()
                } else {
                    List(selection: $selectedShift) {
                        ForEach(currentWeekShifts.sorted(by: { $0.startDate > $1.startDate })) { shift in
                            ShiftRowView(shift: shift)
                                .tag(shift)
                                .contextMenu {
                                    Button("Delete", role: .destructive) {
                                        dataManager.deleteShift(shift)
                                        if selectedShift?.id == shift.id {
                                            selectedShift = nil
                                        }
                                    }
                                }
                        }
                        .onDelete(perform: deleteShifts)
                    }
                    .listStyle(SidebarListStyle())
                }
            }
            .frame(minWidth: 300)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingStartShift = true }) {
                        Image(systemName: "plus")
                    }
                }
                
                if selectedShift != nil {
                    ToolbarItem(placement: .destructiveAction) {
                        Button(action: {
                            if let shift = selectedShift {
                                dataManager.deleteShift(shift)
                                selectedShift = nil
                            }
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
        } detail: {
            if let selectedShift = selectedShift {
                ShiftDetailView(shift: selectedShift)
                    .id(selectedShift.id) // Force view refresh when selection changes
            } else {
                // Summary View
                VStack(spacing: 20) {
                    Text("Rideshare Tracker")
                        .font(.largeTitle)
                        .bold()
                    
                    if !currentWeekShifts.isEmpty {
                        Text("Select a shift from the sidebar to view details")
                            .foregroundColor(.secondary)
                    } else {
                        Text("No shifts for this week")
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.textBackgroundColor))
            }
        }
        .navigationTitle("Rideshare Tracker")
        .sheet(isPresented: $showingStartShift) {
            StartShiftView(onShiftStarted: navigateToWeekContaining)
        }
        .sheet(isPresented: $showingPreferences) {
            PreferencesView()
                .environmentObject(dataManager)
                .environmentObject(preferences)
        }
    }
    #endif
    
    #if os(iOS)
    var iOSView: some View {
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
                .background(backgroundColorForOS)
                
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
                #if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingPreferences = true }) {
                        Image(systemName: "gear")
                    }
                }
                #endif
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
    #endif
    
    // Platform-specific background color
    private var backgroundColorForOS: Color {
        #if os(iOS)
        return Color(UIColor.systemGroupedBackground)
        #else
        return Color(.controlBackgroundColor)
        #endif
    }
    
    private var summaryCardsView: some View {
        HStack(spacing: 12) {
            SummaryCard(
                title: "Week Totals",
                paymentDue: weekTotals.paymentDue,
                trips: weekTotals.trips,
                miles: weekTotals.miles,
                hours: weekTotals.hours,
                grossProfit: calculateGrossProfit(for: currentWeekShifts),
                grossProfitPerHour: calculateGrossProfitPerHour(for: currentWeekShifts),
                color: .blue
            )
            
            SummaryCard(
                title: "Month Totals",
                paymentDue: monthTotals.paymentDue,
                trips: monthTotals.trips,
                miles: monthTotals.miles,
                hours: monthTotals.hours,
                grossProfit: calculateGrossProfit(for: dataManager.shifts.filter { Calendar.current.isDate($0.startDate, equalTo: selectedDate, toGranularity: .month) }),
                grossProfitPerHour: calculateGrossProfitPerHour(for: dataManager.shifts.filter { Calendar.current.isDate($0.startDate, equalTo: selectedDate, toGranularity: .month) }),
                color: .green
            )
            
            SummaryCard(
                title: "Year Totals",
                paymentDue: yearTotals.paymentDue,
                trips: yearTotals.trips,
                miles: yearTotals.miles,
                hours: yearTotals.hours,
                grossProfit: calculateGrossProfit(for: dataManager.shifts.filter { Calendar.current.isDate($0.startDate, equalTo: selectedDate, toGranularity: .year) }),
                grossProfitPerHour: calculateGrossProfitPerHour(for: dataManager.shifts.filter { Calendar.current.isDate($0.startDate, equalTo: selectedDate, toGranularity: .year) }),
                color: .purple
            )
        }
        .padding(.horizontal)
    }
    
    private var weekHeaderText: String {
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
    
    private var weekTotals: (paymentDue: Double, trips: Int, miles: Double, hours: Double) {
        calculateTotals(for: currentWeekShifts)
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
        
        let totalGrossProfit = completedShifts.reduce(0) { sum, shift in
            sum + shift.grossProfit(tankCapacity: preferences.tankCapacity, gasPrice: preferences.gasPrice)
        }
        
        let totalHours = completedShifts.reduce(0) { sum, shift in
            sum + (shift.shiftDuration / 3600.0)
        }
        
        return totalHours > 0 ? totalGrossProfit / totalHours : 0
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
        .background(backgroundColorForCard)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private var backgroundColorForCard: Color {
        #if os(macOS)
        return Color(.controlBackgroundColor)
        #else
        return Color(.systemBackground)
        #endif
    }
}
