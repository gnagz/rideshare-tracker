//
//  AddExpenseView.swift
//  Rideshare Tracker
//
//  Created by George Knaggs with Claude AI assistance on 8/23/25.
//

import SwiftUI
import PhotosUI

struct AddExpenseView: View {
    @EnvironmentObject var expenseManager: ExpenseDataManager
    @EnvironmentObject var preferencesManager: PreferencesManager
    @Environment(\.presentationMode) var presentationMode

    private var preferences: AppPreferences { preferencesManager.preferences }
    
    @State private var selectedDate = Date()
    @State private var selectedCategory = ExpenseCategory.vehicle
    @State private var description = ""
    @State private var amount: Double = 0.0
    @FocusState private var focusedField: FocusedField?
    
    // Photo attachment state
    @State private var photoImages: [UIImage] = []
    // Store the full ImageAttachment objects to preserve UUIDs across viewer sessions
    @State private var pendingAttachments: [ImageAttachment] = []

    // UIImagePickerController state
    @State private var showingCameraPicker = false
    @State private var showingPhotoLibraryPicker = false
    @State private var showingImageSourceActionSheet = false

    // Image viewer state
    @State private var showingImageViewer = false
    @State private var viewerImages: [UIImage] = []
    @State private var viewerStartIndex: Int = 0
    
    enum FocusedField {
        case description, amount
    }
    @State private var showingDatePicker = false
    
    private var isFormValid: Bool {
        !description.isEmpty && amount > 0
    }
    
    var body: some View {
        NavigationView {
            formContent
                .navigationTitle("Add Expense")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") {
                            saveExpense()
                        }
                        .disabled(!isFormValid)
                        .accessibilityIdentifier("save_expense_button")
                    }
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") {
                            hideKeyboard()
                        }
                    }
                }
        }
        .sheet(isPresented: $showingImageViewer) {
            ImageViewerView(
                images: $viewerImages,
                startingIndex: viewerStartIndex,
                isPresented: $showingImageViewer,
                attachments: pendingAttachments,
                isEditMode: true,  // Enable metadata editing in AddExpenseView
                onSaveAttachment: { index, editedAttachment in
                    // Update the persisted attachment (preserves UUID across viewer sessions)
                    if index < pendingAttachments.count {
                        pendingAttachments[index] = editedAttachment
                    }
                }
            )
        }
        .imagePickerSheets(
            showingCameraPicker: $showingCameraPicker,
            showingPhotoLibraryPicker: $showingPhotoLibraryPicker,
            onImageSelected: { image in
                photoImages.append(image)
                // Create a corresponding ImageAttachment with default metadata
                let attachment = ImageAttachment(
                    filename: "pending_\(pendingAttachments.count + 1).jpg",
                    type: .receipt,  // Default to receipt for expenses
                    description: nil,
                    dateAttached: Date()
                )
                pendingAttachments.append(attachment)
            }
        )
    }

    private var formContent: some View {
        Form {
            Section("Date") {
                Button(action: { showingDatePicker.toggle() }) {
                    HStack {
                        Text("Date")
                            .foregroundColor(.primary)
                        Spacer()
                        Text(preferencesManager.formatDate(selectedDate))
                            .foregroundColor(.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                }
                
                if showingDatePicker {
                    DatePicker("", selection: $selectedDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                }
            }
            
            Section("Category") {
                Picker("Category", selection: $selectedCategory) {
                    ForEach(ExpenseCategory.allCases, id: \.self) { category in
                        HStack {
                            Image(systemName: category.systemImage)
                            Text(category.rawValue)
                        }
                        .tag(category)
                    }
                }
                .pickerStyle(.menu)
                .frame(minWidth: 200)
            }
            
            Section("Details") {
                HStack {
                    Text("Description")
                    Spacer()
                    TextField("Enter description", text: $description)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.trailing)
                        .frame(minWidth: 150)
                        .focused($focusedField, equals: .description)
                        .accessibilityIdentifier("expense_description_input")
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(focusedField == .description ? Color.accentColor : Color.clear, lineWidth: 2)
                        )
                }

                HStack {
                    Text("Amount")
                    Spacer()
                    CurrencyTextField(placeholder: "$0.00", value: $amount)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)
                        .focused($focusedField, equals: .amount)
                        .accessibilityIdentifier("expense_amount_input")
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(focusedField == .amount ? Color.accentColor : Color.clear, lineWidth: 2)
                        )
                }
            }
            
            PhotosSection(
                photoImages: $photoImages,
                showingImageSourceActionSheet: $showingImageSourceActionSheet,
                showingCameraPicker: $showingCameraPicker,
                showingPhotoLibraryPicker: $showingPhotoLibraryPicker,
                showingImageViewer: $showingImageViewer,
                viewerImages: $viewerImages,
                viewerStartIndex: $viewerStartIndex
            )
        }
    }
    
    private func saveExpense() {
        var expense = ExpenseItem(
            date: selectedDate,
            category: selectedCategory,
            description: description,
            amount: amount
        )
        
        // Save attached images with user-edited metadata
        for (index, image) in photoImages.enumerated() {
            guard index < pendingAttachments.count else { continue }

            do {
                let pendingAttachment = pendingAttachments[index]

                // Save image to disk with metadata from pendingAttachment
                let attachment = try ImageManager.shared.saveImage(
                    image,
                    for: expense.id,
                    parentType: .expense,
                    type: pendingAttachment.type,
                    description: pendingAttachment.description
                )
                expense.imageAttachments.append(attachment)
            } catch {
                print("Failed to save image: \(error)")
                // Continue saving expense even if image fails
            }
        }
        
        expenseManager.addExpense(expense)
        presentationMode.wrappedValue.dismiss()
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
