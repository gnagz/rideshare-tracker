//
//  KeyboardInputUtility.swift
//  Rideshare Tracker
//
//  Created by George Knaggs with Claude AI assistance on 10/4/25.
//

import SwiftUI

struct KeyboardInputUtility {

    /// Shows a keyboard input button for alternative text entry
    /// - Parameters:
    ///   - currentValue: The current value formatted as display string
    ///   - showingAlert: Binding to control alert presentation
    ///   - inputText: Binding to the text input field
    ///   - accessibilityId: Accessibility identifier for the button
    ///   - accessibilityLabel: Accessibility label for the button
    static func keyboardInputButton(
        currentValue: String,
        showingAlert: Binding<Bool>,
        inputText: Binding<String>,
        accessibilityId: String,
        accessibilityLabel: String
    ) -> some View {
        HStack {
            Spacer()
            Button(action: {
                inputText.wrappedValue = currentValue
                showingAlert.wrappedValue = true
            }) {
                Image(systemName: "keyboard")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            .accessibilityIdentifier(accessibilityId)
            .accessibilityLabel(accessibilityLabel)
        }
        .padding(.bottom, 8)
    }

    /// Creates an alert for text input with validation
    /// - Parameters:
    ///   - title: Alert title
    ///   - isPresented: Binding to control alert presentation
    ///   - inputText: Binding to the text input field
    ///   - placeholder: Placeholder text for the input field
    ///   - keyboardType: Keyboard type for input
    ///   - actionTitle: Title for the confirm button
    ///   - formatMessage: Format instruction message
    ///   - onConfirm: Action to perform when confirmed
    static func inputAlert(
        title: String,
        isPresented: Binding<Bool>,
        inputText: Binding<String>,
        placeholder: String,
        keyboardType: UIKeyboardType = .numbersAndPunctuation,
        actionTitle: String,
        formatMessage: String,
        onConfirm: @escaping () -> Void
    ) -> Alert {
        Alert(
            title: Text(title),
            message: Text("Format: \(formatMessage)"),
            primaryButton: .default(Text(actionTitle)) {
                onConfirm()
            },
            secondaryButton: .cancel {
                inputText.wrappedValue = ""
            }
        )
    }
}