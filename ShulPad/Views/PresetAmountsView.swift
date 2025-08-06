import SwiftUI

struct PresetAmountsView: View {
    @EnvironmentObject private var kioskStore: KioskStore
    @EnvironmentObject private var squareAuthService: SquareAuthService
    @EnvironmentObject private var catalogService: SquareCatalogService
    
    @State private var allowCustomAmount: Bool = true
    @State private var minAmount: String = "1"
    @State private var maxAmount: String = "100000"
    @State private var showingAddAmountSheet = false
    @State private var newAmountString = ""
    
    // Auto-save timer
    @State private var autoSaveTimer: Timer?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header without save button
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Donation Amounts")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Set preset amounts for quick selection")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)
            
            ScrollView {
                LazyVStack(spacing: 24) {
                    // Preset Amounts Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Quick Select Amounts")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        // Simple grid of amounts
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                            ForEach(Array(kioskStore.presetDonations.enumerated()), id: \.offset) { index, donation in
                                SimplePresetCard(
                                    amount: donation.amount,
                                    onAmountChange: { newAmount in
                                        kioskStore.updatePresetDonation(at: index, amount: newAmount)
                                        scheduleAutoSave()
                                    },
                                    onRemove: {
                                        kioskStore.removePresetDonation(at: index)
                                        autoSaveSettings()
                                    },
                                    canRemove: kioskStore.presetDonations.count > 1
                                )
                            }
                            
                            // Add button
                            if kioskStore.presetDonations.count < 6 {
                                AddAmountButton {
                                    showingAddAmountSheet = true
                                }
                            }
                        }
                        
                        Text("Tap any amount to edit it. You can have up to 6 preset amounts.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 24)
                    
                    // Custom Amount Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Custom Amount Option")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        VStack(spacing: 16) {
                            // Toggle
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Allow donors to enter custom amounts")
                                        .font(.subheadline)
                                    
                                    Text("Donors can type their own amount instead of using presets")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                Toggle("", isOn: $allowCustomAmount)
                                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                                    .onChange(of: allowCustomAmount) { _, _ in
                                        scheduleAutoSave()
                                    }
                            }
                            .padding(16)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            
                            // Min/Max settings (only if custom amounts enabled)
                            if allowCustomAmount {
                                VStack(spacing: 12) {
                                    Text("Set limits for custom amounts")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    
                                    HStack(spacing: 16) {
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text("Minimum")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            
                                            HStack(spacing: 8) {
                                                Text("$")
                                                    .foregroundStyle(.secondary)
                                                
                                                TextField("1", text: $minAmount)
                                                    .keyboardType(.numberPad)
                                                    .textFieldStyle(CompactTextFieldStyle())
                                                    .onChange(of: minAmount) { _, _ in
                                                        scheduleAutoSave()
                                                    }
                                            }
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text("Maximum")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            
                                            HStack(spacing: 8) {
                                                Text("$")
                                                    .foregroundStyle(.secondary)
                                                
                                                TextField("1000", text: $maxAmount)
                                                    .keyboardType(.numberPad)
                                                    .textFieldStyle(CompactTextFieldStyle())
                                                    .onChange(of: maxAmount) { _, _ in
                                                        scheduleAutoSave()
                                                    }
                                            }
                                        }
                                    }
                                }
                                .padding(16)
                                .background(Color(.tertiarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    // 🆕 Processing Fee Section - MOVED INSIDE ScrollView
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Processing Fees")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Add processing fees to donations")
                                    .font(.subheadline)
                                
                                Text("Adds 2.6% + 15¢ to cover transaction costs")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            Toggle("", isOn: $kioskStore.processingFeeEnabled)
                                .toggleStyle(SwitchToggleStyle(tint: .blue))
                                .onChange(of: kioskStore.processingFeeEnabled) { _, _ in
                                    scheduleAutoSave()
                                }
                        }
                        .padding(16)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24) // Add bottom padding for the last section
                    
                } // Closing LazyVStack
            } // Closing ScrollView
        } // Closing main VStack
        .background(Color(.systemGroupedBackground))
        .onAppear {
            loadSettings()
            kioskStore.connectCatalogService(catalogService)
            
            if squareAuthService.isAuthenticated {
                catalogService.fetchPresetDonations()
            }
        }
        .onChange(of: squareAuthService.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated {
                catalogService.fetchPresetDonations()
            }
        }
        .sheet(isPresented: $showingAddAmountSheet) {
            CompactAddAmountSheet(
                newAmountString: $newAmountString,
                isPresented: $showingAddAmountSheet,
                onAdd: { amount in
                    kioskStore.addPresetDonation(amount: amount)
                    autoSaveSettings()
                },
                onError: { message in
                    print("Error adding amount: \(message)")
                }
            )
            .presentationDetents([.height(300)])
        }
    }
    
    // MARK: - Functions
    
    func loadSettings() {
        allowCustomAmount = kioskStore.allowCustomAmount
        minAmount = kioskStore.minAmount
        maxAmount = kioskStore.maxAmount
    }
    
    // MARK: - Auto-Save Functions
    
    private func scheduleAutoSave() {
        // Cancel existing timer
        autoSaveTimer?.invalidate()
        
        // Schedule new timer with 1 second delay
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
            autoSaveSettings()
        }
    }
    
    private func autoSaveSettings() {
        kioskStore.allowCustomAmount = allowCustomAmount
        kioskStore.minAmount = minAmount
        kioskStore.maxAmount = maxAmount
        
        kioskStore.saveSettings()
        
    
    }
}

// MARK: - Clean Supporting Views

struct SimplePresetCard: View {
    let amount: String
    let onAmountChange: (String) -> Void
    let onRemove: () -> Void
    let canRemove: Bool
    
    @State private var isEditing = false
    @State private var editAmount = ""
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            // Main content area - now fully clickable
            if isEditing {
                HStack(spacing: 4) {
                    Text("$")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                    TextField("0", text: $editAmount)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .keyboardType(.numberPad)
                        .focused($isTextFieldFocused)
                        .multilineTextAlignment(.center)
                        .onSubmit {
                            finishEditing()
                        }
                }
                .frame(maxWidth: .infinity, minHeight: 44)
            } else {
                // Make the entire content area clickable
                Button(action: startEditing) {
                    Text("$\(amount)")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // Remove button (only show when not editing and removable)
            if canRemove && !isEditing {
                Button(action: onRemove) {
                    Image(systemName: "minus.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .frame(minHeight: 80)
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isEditing ? Color.blue : Color.clear, lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .animation(.easeInOut(duration: 0.1), value: isEditing)
        .onAppear {
            editAmount = amount
        }
        .onDisappear {
            // Auto-save when view disappears (user navigates away)
            if isEditing {
                finishEditing()
            }
        }
    }
    
    private func startEditing() {
        editAmount = amount
        isEditing = true
        isTextFieldFocused = true
    }
    
    private func finishEditing() {
        if let value = Double(editAmount), value > 0 {
            onAmountChange(editAmount)
        } else {
            editAmount = amount
        }
        isEditing = false
        isTextFieldFocused = false
    }
}

struct AddAmountButton: View {
    let onAdd: () -> Void
    
    var body: some View {
        Button(action: onAdd) {
            VStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.title2)
                    .foregroundStyle(.blue)
                
                Text("Add")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.blue)
            }
            .frame(minHeight: 80)
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.blue.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [6, 3]))
            )
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct CompactAddAmountSheet: View {
    @Binding var newAmountString: String
    @Binding var isPresented: Bool
    let onAdd: (String) -> Void
    let onError: (String) -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("Add Preset Amount")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Cancel") {
                    newAmountString = ""
                    isPresented = false
                }
                .foregroundStyle(.secondary)
            }
            
            // Amount input
            HStack(spacing: 8) {
                Text("$")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                
                TextField("25", text: $newAmountString)
                    .font(.title2)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(CompactTextFieldStyle())
                    .multilineTextAlignment(.center)
            }
            
            // Add button
            Button("Add Amount") {
                if let amount = Double(newAmountString), amount > 0 {
                    onAdd(newAmountString)
                    newAmountString = ""
                    isPresented = false
                } else {
                    onError("Please enter a valid amount")
                }
            }
            .font(.subheadline)
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(newAmountString.isEmpty || Double(newAmountString) == nil ? Color(.systemGray4) : Color.blue)
            .foregroundColor(newAmountString.isEmpty || Double(newAmountString) == nil ? .secondary : .white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .disabled(newAmountString.isEmpty || Double(newAmountString) == nil)
            
            Spacer()
        }
        .padding(24)
        .background(Color(.systemBackground))
    }
}

// MARK: - Text Field Style

struct CompactTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}



struct PresetAmountsView_Previews: PreviewProvider {
    static var previews: some View {
        PresetAmountsView()
            .environmentObject(KioskStore())
            .environmentObject(SquareAuthService())
            .environmentObject(SquareCatalogService(authService: SquareAuthService()))
    }
}
