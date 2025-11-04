// filepath: /Users/gnagz/Documents/codespace/Rideshare Tracker/Rideshare Tracker/Utilities/ErrorHandlingUtilities.swift
//
//  ErrorHandlingUtilities.swift
//  Rideshare Tracker
//
//  Created by George Knaggs with Claude AI assistance on 10/18/25.
//

import SwiftUI

/// Error wrapper for SwiftUI Alert compatibility
struct ErrorWrapper: Identifiable {
    let id = UUID()
    let error: Error
    
    var title: String {
        if let localizedError = error as? LocalizedError {
            return localizedError.errorDescription ?? "Error"
        }
        return "Error"
    }
    
    var message: String {
        if let localizedError = error as? LocalizedError,
           let failureReason = localizedError.failureReason {
            return failureReason
        }
        return error.localizedDescription
    }
}

/// View modifier for displaying error alerts
struct ErrorAlertModifier: ViewModifier {
    @Binding var error: Error?
    
    func body(content: Content) -> some View {
        content
            .alert(item: Binding(
                get: { error.map { ErrorWrapper(error: $0) } },
                set: { error = $0?.error }
            )) { errorWrapper in
                Alert(
                    title: Text(errorWrapper.title),
                    message: Text(errorWrapper.message),
                    dismissButton: .default(Text("OK")) {
                        error = nil
                    }
                )
            }
    }
}

/// Extension to easily apply error alert modifier
extension View {
    func errorAlert(error: Binding<Error?>) -> some View {
        modifier(ErrorAlertModifier(error: error))
    }

    /// Convenience function for specific error types that conform to Error
    func errorAlert<E: Error>(error: Binding<E?>) -> some View {
        let erasedBinding = Binding<Error?>(
            get: { error.wrappedValue },
            set: { error.wrappedValue = $0 as? E }
        )
        return modifier(ErrorAlertModifier(error: erasedBinding))
    }
}