//
//  ShiftRowView.swift
//  Rideshare Tracker
//
//  Created by George Knaggs with Claude AI assistance on 8/10/25.
//

import SwiftUI

struct ShiftRowView: View {
    let shift: RideshareShift
    @EnvironmentObject var preferences: AppPreferences
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(DateFormatter.shortDateTime.string(from: shift.startDate))
                    .font(.headline)
                Spacer()
                if shift.endDate != nil {
                    Text("$\(shift.totalPaymentDue, specifier: "%.2f")")
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
                    Text("\(shift.totalTrips ?? 0) trips")
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
