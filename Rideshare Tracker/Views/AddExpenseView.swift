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
    @EnvironmentObject var preferences: AppPreferences
    @Environment(\.presentationMode) var presentationMode
    
    @State private var selectedDate = Date()
    @State private var selectedCategory = ExpenseCategory.vehicle
    @State private var description = ""
    @State private var amount: Double = 0.0
    @FocusState private var focusedField: FocusedField?
    
    // Photo attachment state
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var attachedImages: [UIImage] = []
    @State private var showingPhotoTypePicker = false
    @State private var pendingPhotoType: AttachmentType = .receipt

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
                images: $attachedImages,
                startingIndex: viewerStartIndex,
                isPresented: $showingImageViewer
            )
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
            
            Section("Photos") {
                PhotosPicker(
                    selection: $selectedPhotoItems,
                    maxSelectionCount: 5,
                    matching: .images
                ) {
                    Label("Add Receipt Photo", systemImage: "camera.fill")
                        .foregroundColor(.blue)
                }
                .accessibilityIdentifier("add_receipt_button")
                .onChange(of: selectedPhotoItems) { oldItems, items in
                    Task {
                        await loadSelectedPhotos(from: items)
                    }
                }
                
                if !attachedImages.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 12) {
                            ForEach(0..<attachedImages.count, id: \.self) { index in
                                ZStack(alignment: .topTrailing) {
                                    Button(action: { showImage(at: index) }) {
                                        Image(uiImage: attachedImages[index])
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
                
                if attachedImages.count > 0 {
                    Text("\(attachedImages.count) photo\(attachedImages.count == 1 ? "" : "s") attached")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .accessibilityIdentifier("Photos")
        }
    }
    
    private func saveExpense() {
        var expense = ExpenseItem(
            date: selectedDate,
            category: selectedCategory,
            description: description,
            amount: amount
        )
        
        // Save attached images
        for image in attachedImages {
            do {
                let attachment = try ImageManager.shared.saveImage(
                    image,
                    for: expense.id,
                    parentType: .expense,
                    type: .receipt,
                    description: nil
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
    
    private func loadSelectedPhotos(from items: [PhotosPickerItem]) async {
        attachedImages.removeAll()
        
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run {
                    attachedImages.append(image)
                }
            }
        }
    }
    
    private func removeImage(at index: Int) {
        attachedImages.remove(at: index)
        selectedPhotoItems.remove(at: index)
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func showImage(at index: Int) {
        guard !showingImageViewer else { return }

        ImageViewingUtilities.showImageViewer(
            images: attachedImages,
            startIndex: index,
            viewerImages: $viewerImages,
            viewerStartIndex: $viewerStartIndex,
            showingImageViewer: $showingImageViewer
        )
    }
}
