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
    @EnvironmentObject var preferencesManager: PreferencesManager
    @Environment(\.presentationMode) var presentationMode

    private var preferences: AppPreferences { preferencesManager.preferences }

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
    @State private var attachmentsMarkedForDeletion: [ImageAttachment] = []
    // Metadata editing state (dual storage pattern)
    @State private var attachmentMetadataEdits: [UUID: ImageAttachment] = [:]  // Track metadata edits for EXISTING photos
    @State private var pendingAttachments: [ImageAttachment] = []  // Track full ImageAttachment objects for NEW photos (preserves UUIDs)

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

    // Computed property that merges existing attachments with metadata edits and new attachments
    private var currentAttachments: [ImageAttachment] {
        var attachments: [ImageAttachment] = []

        // Add existing attachments with metadata edits applied
        for attachment in existingAttachments {
            if let editedAttachment = attachmentMetadataEdits[attachment.id] {
                attachments.append(editedAttachment)
            } else {
                attachments.append(attachment)
            }
        }

        // Add pending attachments for new photos (not yet saved to disk)
        // Use the persisted ImageAttachment objects to preserve UUIDs across viewer sessions
        for (index, _) in newImages.enumerated() {
            if index < pendingAttachments.count {
                attachments.append(pendingAttachments[index])
            }
        }

        return attachments
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
                photoImages: $newImages,
                existingImages: $existingImages,
                onDeleteExisting: { index in
                    // Mark attachment for deletion (don't delete file yet)
                    let attachment = existingAttachments[index]
                    attachmentsMarkedForDeletion.append(attachment)

                    // Remove from display arrays
                    existingAttachments.remove(at: index)
                    existingImages.remove(at: index)

                    // DO NOT delete the physical file here - wait for Save
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
            ImageViewerView(
                images: $viewerImages,
                startingIndex: viewerStartIndex,
                isPresented: $showingImageViewer,
                attachments: currentAttachments,
                isEditMode: true,  // Enable metadata editing in EditExpenseView
                onSaveAttachment: { index, editedAttachment in
                    // Determine if this is an existing attachment or a new photo
                    if index < existingAttachments.count {
                        // Editing existing attachment - store in attachmentMetadataEdits
                        attachmentMetadataEdits[editedAttachment.id] = editedAttachment
                    } else {
                        // Editing new photo - update the persisted attachment (preserves UUID across viewer sessions)
                        let newPhotoIndex = index - existingAttachments.count
                        if newPhotoIndex < pendingAttachments.count {
                            pendingAttachments[newPhotoIndex] = editedAttachment
                        }
                    }
                }
            )
        }
        .onChange(of: showingImageViewer) { oldValue, newValue in
            // Reload images every time viewer opens to ensure newly added photos are included
            if newValue {
                viewerImages = loadAllImages()
            }
        }
        .imagePickerSheets(
            showingCameraPicker: $showingCameraPicker,
            showingPhotoLibraryPicker: $showingPhotoLibraryPicker,
            onImageSelected: { image in
                newImages.append(image)
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
    
    private func saveChanges() {
        var updatedExpense = expense
        updatedExpense.date = selectedDate
        updatedExpense.category = selectedCategory
        updatedExpense.description = description
        updatedExpense.amount = amount

        // Step 1a: Apply metadata edits to existing attachments
        var updatedAttachments: [ImageAttachment] = []
        for attachment in existingAttachments {
            if let editedAttachment = attachmentMetadataEdits[attachment.id] {
                // Use edited version with updated metadata
                updatedAttachments.append(editedAttachment)
            } else {
                // Keep original attachment
                updatedAttachments.append(attachment)
            }
        }

        // Step 1b: Update attachments array (with edited metadata, remove deleted, keep existing)
        updatedExpense.imageAttachments = updatedAttachments

        // Save new attached images with user-edited metadata
        for (index, image) in newImages.enumerated() {
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
                updatedExpense.imageAttachments.append(attachment)
            } catch {
                print("Failed to save image: \(error)")
                // Continue saving expense even if image fails
            }
        }

        // Step 2: Save expense to disk (commits all changes)
        expenseManager.updateExpense(updatedExpense)

        // Step 3: ONLY AFTER successful save, physically delete marked files
        for attachment in attachmentsMarkedForDeletion {
            ImageManager.shared.deleteImage(attachment, for: expense.id, parentType: .expense)
        }

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

    private func loadAllImages() -> [UIImage] {
        var allImages: [UIImage] = []

        // Load existing attachments
        for existingAttachment in existingAttachments {
            if let image = ImageManager.shared.loadImage(
                for: expense.id,
                parentType: .expense,
                filename: existingAttachment.filename
            ) {
                allImages.append(image)
            }
        }

        // Add new images
        allImages.append(contentsOf: newImages)

        return allImages
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
