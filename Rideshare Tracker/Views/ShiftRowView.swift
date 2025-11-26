//
//  ShiftRowView.swift
//  Rideshare Tracker
//
//  Created by George Knaggs with Claude AI assistance on 8/10/25.
//

import SwiftUI

struct ShiftRowView: View {
    let shift: RideshareShift
    @EnvironmentObject var preferencesManager: PreferencesManager

    private var preferences: AppPreferences { preferencesManager.preferences }

    private func formatDateTime(_ date: Date) -> String {
        return "\(preferencesManager.formatDate(date)) \(preferencesManager.formatTime(date))"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(formatDateTime(shift.startDate))
                    .font(.headline)

                // Uber import status badges
                if shift.hasUberData {
                    Image(systemName: "chart.bar.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .accessibilityLabel("Has Uber data")
                }

                if shift.hasAnyUberDiscrepancy {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .accessibilityLabel("Uber data discrepancy")
                }

                Spacer()
                if shift.endDate != nil {
                    Text("$\(shift.expectedPayout, specifier: "%.2f")")
                        .font(.headline)
                        .foregroundColor(.green)
                } else {
                    Text("Active")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
            }
            
            if shift.endDate != nil {
                HStack {
                    Text("\(shift.trips ?? 0) trips")
                    Text("•")
                    Text("\(shift.shiftMileage.formattedMileage) mi")
                    Text("•")
                    Text("\(shift.shiftHours)h \(shift.shiftMinutes)m")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
