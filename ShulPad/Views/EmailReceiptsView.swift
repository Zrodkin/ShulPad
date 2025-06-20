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
                    
                    // Receipt Preview Card
                    ReceiptPreviewCard(
                        organizationName: organizationName.isEmpty ? "Your Organization" : organizationName,
                        taxId: taxId.isEmpty ? "12-3456789" : taxId,
                        receiptMessage: receiptMessage.isEmpty ? "Thank you for your generous donation!" : receiptMessage
                    )
                    
                    // Receipt Information Card
                    SettingsCard(title: "About Tax Receipts", icon: "doc.text.fill") {
                        VStack(spacing: 20) {
                            ReceiptInfoItem(
                                icon: "checkmark.seal.fill",
                                color: .green,
                                title: "Tax Deductible",
                                description: "Receipts help donors claim tax deductions for their charitable contributions"
                            )
                            
                            ReceiptInfoItem(
                                icon: "envelope.badge.fill",
                                color: .blue,
                                title: "Automatic Delivery",
                                description: "Receipts are automatically sent to donors after successful donations"
                            )
                            
                            ReceiptInfoItem(
                                icon: "shield.checkered",
                                color: .purple,
                                title: "Legal Compliance",
                                description: "Proper receipts help your organization meet IRS requirements for charitable giving"
                            )
                            
                            ReceiptInfoItem(
                                icon: "heart.fill",
                                color: .red,
                                title: "Donor Trust",
                                description: "Professional receipts build confidence and encourage future donations"
                            )
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

// MARK: - Supporting Views

struct ReceiptPreviewCard: View {
    let organizationName: String
    let taxId: String
    let receiptMessage: String
    
    var body: some View {
        SettingsCard(title: "Receipt Preview", icon: "doc.richtext.fill") {
            VStack(spacing: 16) {
                Text("Here's how your donation receipts will appear:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Mock receipt preview
                VStack(spacing: 16) {
                    // Receipt header
                    VStack(spacing: 8) {
                        Text("DONATION RECEIPT")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)
                        
                        Text(organizationName)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.center)
                    }
                    
                    Divider()
                        .padding(.horizontal, 20)
                    
                    // Receipt details
                    VStack(spacing: 12) {
                        ReceiptRow(label: "Date", value: DateFormatter.receiptDate.string(from: Date()))
                        ReceiptRow(label: "Amount", value: "$50.00")
                        ReceiptRow(label: "Transaction ID", value: "TXN-12345")
                        ReceiptRow(label: "Tax ID", value: taxId)
                    }
                    
                    Divider()
                        .padding(.horizontal, 20)
                    
                    // Footer
                    VStack(spacing: 6) {
                        Text(receiptMessage.isEmpty ? "Thank you for your generous donation!" : receiptMessage)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                        
                        Text("This receipt is for your tax records.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.tertiarySystemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(.separator), lineWidth: 1)
                        )
                )
            }
        }
    }
}

struct ReceiptRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
        }
    }
}

struct ReceiptInfoItem: View {
    let icon: String
    let color: Color
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
    }
}

// MARK: - Extensions

extension DateFormatter {
    static let receiptDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
}

struct EmailReceiptsView_Previews: PreviewProvider {
    static var previews: some View {
        EmailReceiptsView()
            .environmentObject(OrganizationStore())
    }
}
