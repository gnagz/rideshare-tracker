//
//  TankLevelUtilities.swift
//  Rideshare Tracker
//
//  Created by George on 10/26/25.
//

import Foundation

class TankLevelUtilities {
    // MARK: - Helper Methods: Tank Level Utilities available for conversions
    
    public static func tankLevelToString(_ decimal: Double) -> String {
        var level = decimal as Double
        if decimal > 0.0 && decimal < 1.0 {
            // Convert from 0-1 scale to 0-8 scale and round to nearest 1/8
            let scaledValue = decimal * 8.0
            level = round(scaledValue)
        }
        switch level {
        case 0.0: return "E"
        case 1.0: return "1/8"
        case 2.0: return "1/4"
        case 3.0: return "3/8"
        case 4.0: return "1/2"
        case 5.0: return "5/8"
        case 6.0: return "3/4"
        case 7.0: return "7/8"
        case 8.0: return "F"
        default: return String(level)
        }
    }
    
    public static func tankLevelToDecimal(_ level: Double) -> Double {
        // Convert internal 0-8 scale to 0-1 decimal scale
        return level / 8.0
    }
    
    public static func tankLevelFromString(_ str: String) -> Double {
        switch str.uppercased() {
        case "E": return 0.0
        case "EMPTY": return 0.0
        case "1/8": return 1.0
        case "1/4": return 2.0
        case "3/8": return 3.0
        case "1/2": return 4.0
        case "5/8": return 5.0
        case "3/4": return 6.0
        case "7/8": return 7.0
        case "F": return 8.0
        case "FULL": return 8.0
        default:
            // Handle decimal values from CSV (0.0 to 1.0)
            if let decimal = Double(str) {
                if decimal <= 1.0 {
                    // Convert from 0-1 scale to 0-8 scale and round to nearest 1/8
                    let scaledValue = decimal * 8.0
                    return round(scaledValue)
                }
            }
            return Double(str) ?? 0.0
        }
    }
}
