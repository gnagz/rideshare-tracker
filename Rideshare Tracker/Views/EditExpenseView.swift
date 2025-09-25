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
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var existingImages: [UIImage] = []
    @State private var newImages: [UIImage] = []
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
            
            Section("Photos") {
                PhotosPicker(
                    selection: $selectedPhotoItems,
                    maxSelectionCount: 5,
                    matching: .images
                ) {
                    Label("Add More Photos", systemImage: "camera.fill")
                        .foregroundColor(.blue)
                }
                .onChange(of: selectedPhotoItems) { oldItems, items in
                    Task {
                        await loadNewPhotos(from: items)
                    }
                }
                
                if !existingImages.isEmpty || !newImages.isEmpty {
                    let allImages = existingImages + newImages
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 12) {
                            ForEach(0..<allImages.count, id: \.self) { index in
                                ZStack(alignment: .topTrailing) {
                                    Button(action: { showImage(at: index) }) {
                                        Image(uiImage: allImages[index])
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 80, height: 80)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(Color(.systemGray4), lineWidth: 1)
                                            )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    
                                    Button(action: { removeImage(at: index) }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.red)
                                            .background(Color.white, in: Circle())
                                    }
                                    .offset(x: 8, y: -8)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                let totalImages = existingImages.count + newImages.count
                if totalImages > 0 {
                    Text("\(totalImages) photo\(totalImages == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .onAppear {
            loadExistingImages()
        }
        .sheet(isPresented: $showingImageViewer) {
            if !viewerImages.isEmpty {
                ImageViewerView(
                    images: viewerImages,
                    startingIndex: viewerStartIndex,
                    isPresented: $showingImageViewer
                )
            }
        }
    }
    
    private func saveChanges() {
        var updatedExpense = expense
        updatedExpense.date = selectedDate
        updatedExpense.category = selectedCategory
        updatedExpense.description = description
        updatedExpense.amount = amount
        
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
        existingImages.removeAll()
        
        for attachment in expense.imageAttachments {
            if let image = ImageManager.shared.loadImage(
                for: expense.id,
                parentType: .expense,
                filename: attachment.filename
            ) {
                existingImages.append(image)
            }
        }
    }
    
    private func loadNewPhotos(from items: [PhotosPickerItem]) async {
        newImages.removeAll()
        
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run {
                    newImages.append(image)
                }
            }
        }
    }
    
    private func showImage(at index: Int) {
        let allImages = existingImages + newImages
        viewerImages = allImages
        viewerStartIndex = index
        showingImageViewer = true
    }
    
    private func removeImage(at index: Int) {
        let existingCount = existingImages.count
        
        if index < existingCount {
            // Removing existing image - need to delete from expense and disk
            let attachment = expense.imageAttachments[index]
            ImageManager.shared.deleteImage(attachment, for: expense.id, parentType: .expense)
            
            // Update the expense in the data manager
            var updatedExpense = expense
            updatedExpense.imageAttachments.remove(at: index)
            expenseManager.updateExpense(updatedExpense)
            
            existingImages.remove(at: index)
        } else {
            // Removing new image - just remove from array
            let newImageIndex = index - existingCount
            newImages.remove(at: newImageIndex)
            if newImageIndex < selectedPhotoItems.count {
                selectedPhotoItems.remove(at: newImageIndex)
            }
        }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}