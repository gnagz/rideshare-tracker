//
//  DateFormatter+Extensions.swift
//  Rideshare Tracker
//
//  Created by George on 8/10/25.
//


import Foundation

extension DateFormatter {
    static let shortDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d/yy h:mm a"
        return formatter
    }()
}
