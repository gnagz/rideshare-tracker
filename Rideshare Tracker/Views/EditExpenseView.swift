//
//  EditExpenseView.swift
//  Rideshare Tracker
//
//  Created by George Knaggs with Claude AI assistance on 8/23/25.
//

import SwiftUI
import PhotosUI

struct EditExpenseView: View {
    @EnvironmentObject var expenseManager: ExpenseDataManager
    @EnvironmentObject var preferences: AppPreferences
    @Environment(\.presentationMode) var presentationMode
    
    let expense: ExpenseItem
    let isSheet: Bool
    
    @State private var selectedDate: Date
    @State private var selectedCategory: ExpenseCategory
    @State private var description: String
    @State private var amount: Double
    @State private var showingDatePicker = false
    @FocusState private var focusedField: FocusedField?
    
    // Photo attachment state
    @State private var existingAttachments: [ImageAttachment] = []
    @State private var existingImages: [UIImage] = []
    @State private var newImages: [UIImage] = []

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

    init(expense: ExpenseItem, isSheet: Bool = true) {
        self.expense = expense
        self.isSheet = isSheet
        _selectedDate = State(initialValue: expense.date)
        _selectedCategory = State(initialValue: expense.category)
        _description = State(initialValue: expense.description)
        _amount = State(initialValue: expense.amount)
        _existingAttachments = State(initialValue: expense.imageAttachments)
    }
    
    private var isFormValid: Bool {
        !description.isEmpty && amount > 0
    }
    
    var body: some View {
        if isSheet {
            NavigationView {
                formContent
                    .navigationTitle("Edit Expense")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Cancel") {
                                presentationMode.wrappedValue.dismiss()
                            }
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Save") {
                                saveChanges()
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
        } else {
            formContent
                .navigationTitle("Edit Expense")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") {
                            saveChanges()
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
    }
    
    private var formContent: some View {
        Form {
            Section("Date") {
                Button(action: { showingDatePicker.toggle() }) {
                    HStack {
                        Text("Date")
                            .foregroundColor(.primary)
                        Spacer()
                        Text(preferences.formatDate(selectedDate))
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
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(focusedField == .amount ? Color.accentColor : Color.clear, lineWidth: 2)
                        )
                }
            }
            
            PhotosSection(
                photoImages: $newImages,
                existingImages: $existingImages,
                onDeleteExisting: { index in
                    // Remove from working copy arrays (changes saved on Save button)
                    let attachment = existingAttachments[index]
                    existingAttachments.remove(at: index)
                    existingImages.remove(at: index)

                    // Delete the physical file
                    ImageManager.shared.deleteImage(attachment, for: expense.id, parentType: .expense)
                },
                showingImageSourceActionSheet: $showingImageSourceActionSheet,
                showingCameraPicker: $showingCameraPicker,
                showingPhotoLibraryPicker: $showingPhotoLibraryPicker,
                showingImageViewer: $showingImageViewer,
                viewerImages: $viewerImages,
                viewerStartIndex: $viewerStartIndex
            )
        }
        .onAppear {
            loadExistingImages()
        }
        .sheet(isPresented: $showingImageViewer) {
            Group {
                if !viewerImages.isEmpty {
                    ImageViewerView(
                        images: viewerImages,
                        startingIndex: viewerStartIndex,
                        isPresented: $showingImageViewer
                    )
                    .onAppear {
                        debugMessage("EditExpenseView sheet: ImageViewerView appeared with \(viewerImages.count) images, startIndex=\(viewerStartIndex)")
                    }
                } else {
                    Text("No images for expense viewer")
                        .foregroundColor(.white)
                        .onAppear {
                            debugMessage("EditExpenseView sheet: Empty state - viewerImages.count=\(viewerImages.count)")
                        }
                }
            }
            .onAppear {
                debugMessage("EditExpenseView sheet: Sheet opened - showingImageViewer=\(showingImageViewer), viewerImages.count=\(viewerImages.count)")
            }
        }
        .imagePickerSheets(
            showingCameraPicker: $showingCameraPicker,
            showingPhotoLibraryPicker: $showingPhotoLibraryPicker,
            onImageSelected: { image in
                newImages.append(image)
            }
        )
    }
    
    private func saveChanges() {
        var updatedExpense = expense
        updatedExpense.date = selectedDate
        updatedExpense.category = selectedCategory
        updatedExpense.description = description
        updatedExpense.amount = amount

        // Handle photo changes - sync working copy back to expense
        updatedExpense.imageAttachments = existingAttachments

        // Save new attached images
        for image in newImages {
            do {
                let attachment = try ImageManager.shared.saveImage(
                    image,
                    for: expense.id,
                    parentType: .expense,
                    type: .receipt,
                    description: nil
                )
                updatedExpense.imageAttachments.append(attachment)
            } catch {
                print("Failed to save image: \(error)")
                // Continue saving expense even if image fails
            }
        }

        expenseManager.updateExpense(updatedExpense)
        presentationMode.wrappedValue.dismiss()
    }
    
    private func loadExistingImages() {
        debugMessage("EditExpenseView loadExistingImages: Starting with \(existingAttachments.count) attachments")
        existingImages.removeAll()

        for (index, attachment) in existingAttachments.enumerated() {
            debugMessage("EditExpenseView loadExistingImages: Loading attachment \(index): \(attachment.filename)")
            if let image = ImageManager.shared.loadImage(
                for: expense.id,
                parentType: .expense,
                filename: attachment.filename
            ) {
                existingImages.append(image)
                debugMessage("EditExpenseView loadExistingImages: Successfully loaded \(attachment.filename)")
            } else {
                debugMessage("EditExpenseView loadExistingImages: Failed to load \(attachment.filename)")
            }
        }

        debugMessage("EditExpenseView loadExistingImages: Final existingImages.count=\(existingImages.count)")
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}