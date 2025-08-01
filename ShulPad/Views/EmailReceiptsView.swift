import SwiftUI

struct EmailReceiptsView: View {
    @EnvironmentObject private var organizationStore: OrganizationStore
    @State private var organizationName: String = ""
    @State private var taxId: String = ""
    @State private var receiptMessage: String = ""
    @State private var showToast = false
    @State private var toastMessage = "Settings saved"
    
    // Auto-save timer
    @State private var autoSaveTimer: Timer?
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                // Page header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "envelope.fill")
                            .font(.title2)
                            .foregroundStyle(.blue)
                        
                        Text("Email Receipts")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Spacer()
                    }
                    
                    Text("Configure your organization details for donation receipts")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                
                // Main content
                VStack(spacing: 20) {
                    // Organization Information Card
                    SettingsCard(title: "Organization Information", icon: "building.2.fill") {
                        VStack(spacing: 24) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("This information will appear on all donation receipts sent to donors")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            
                            // Organization Name Field
                            VStack(alignment: .leading, spacing: 8) {
                                SectionHeader(
                                    title: "Organization Name",
                                    subtitle: "Your official organization or charity name"
                                )
                                
                                TextField("Enter organization name", text: $organizationName)
                                    .textFieldStyle(ModernTextFieldStyle())
                                    .onChange(of: organizationName) { _, _ in
                                        scheduleAutoSave()
                                    }
                            }
                            
                            // Tax ID Field
                            VStack(alignment: .leading, spacing: 8) {
                                SectionHeader(
                                    title: "Tax ID (EIN)",
                                    subtitle: "Required for tax-deductible donation receipts"
                                )
                                
                                TextField("", text: $taxId)
                                    .textFieldStyle(ModernTextFieldStyle())
                                    .keyboardType(.numbersAndPunctuation)
                                    .onChange(of: taxId) { _, _ in
                                        scheduleAutoSave()
                                    }
                            }
                            
                            // Custom Receipt Message Field
                            VStack(alignment: .leading, spacing: 8) {
                                SectionHeader(
                                    title: "Receipt Message",
                                    subtitle: "Custom thank you message for donors"
                                )
                                
                                ZStack(alignment: .topLeading) {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(.secondarySystemBackground))
                                        .frame(minHeight: 100)
                                    
                                    TextEditor(text: $receiptMessage)
                                        .padding(12)
                                        .background(Color.clear)
                                        .onChange(of: receiptMessage) { _, _ in
                                            scheduleAutoSave()
                                        }
                                    
                                    if receiptMessage.isEmpty {
                                        Text("Enter your custom thank you message...")
                                            .foregroundStyle(.tertiary)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 20)
                                            .allowsHitTesting(false)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            organizationName = organizationStore.name
            taxId = organizationStore.taxId
            receiptMessage = organizationStore.receiptMessage
        }
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
        organizationStore.name = organizationName
        organizationStore.taxId = taxId
        organizationStore.receiptMessage = receiptMessage
        
        organizationStore.saveToUserDefaults()
    }
}

struct EmailReceiptsView_Previews: PreviewProvider {
    static var previews: some View {
        EmailReceiptsView()
            .environmentObject(OrganizationStore())
    }
}
