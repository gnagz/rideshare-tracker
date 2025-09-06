//
//  DebugUtilities.swift
//  Rideshare Tracker
//
//  Created by George Knaggs with Claude AI assistance on 9/6/25.
//

import Foundation

/// Global debug printing utility - only outputs when debug flags are set
/// Can be used throughout the app by calling debugPrint("message")
func debugPrint(_ message: String, function: String = #function, file: String = #file) {
    let debugEnabled = ProcessInfo.processInfo.environment["DEBUG"] != nil ||
                      ProcessInfo.processInfo.arguments.contains("-debug")
    
    if debugEnabled {
        let fileName = (file as NSString).lastPathComponent
        print("DEBUG [\(fileName):\(function)]: \(message)")
    }
}

/// Visual verification pause - only pauses when visual debug flags are set
/// Useful for UI testing and debugging visual state changes
func visualDebugPause(_ seconds: UInt32 = 2) {
    let visualDebugEnabled = ProcessInfo.processInfo.environment["VISUAL_DEBUG"] != nil ||
                            ProcessInfo.processInfo.arguments.contains("-visual-debug")
    
    if visualDebugEnabled {
        sleep(seconds)
    }
}