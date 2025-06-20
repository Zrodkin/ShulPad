import SwiftUI
import PhotosUI

struct GuidedSetupView: View {
    @EnvironmentObject private var kioskStore: KioskStore
    @EnvironmentObject private var organizationStore: OrganizationStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var currentStep = 0
    @State private var backgroundImage: UIImage?
    @State private var organizationName = ""
    @State private var taxId = ""
    
    @State private var showingImagePicker = false
    @State private var isCompleting = false
    
    private let totalSteps = 3
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Progress indicator
                    progressIndicator
                    
                    // Content area
                    ScrollView {
                        VStack(spacing: 32) {
                            // Step content
                            Group {
                                switch currentStep {
                                case 0:
                                    backgroundImageStep
                                case 1:
                                    organizationNameStep
                                case 2:
                                    taxIdStep
                                default:
                                    EmptyView()
                                }
                            }
                            .animation(.easeInOut(duration: 0.3), value: currentStep)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 32)
                        .padding(.bottom, 120) // Space for navigation buttons
                    }
                }
                
                // Navigation buttons overlay
                VStack {
                    Spacer()
                    navigationButtons
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(.secondary)
            }
            
            ToolbarItem(placement: .principal) {
                Text("Quick Setup")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(selectedImage: $backgroundImage, isPresented: $showingImagePicker)
        }
        .onAppear {
            loadExistingValues()
        }
    }
    
    // MARK: - Progress Indicator
    
    private var progressIndicator: some View {
        VStack(spacing: 8) {
            // Step dots
            HStack(spacing: 12) {
                ForEach(0..<totalSteps, id: \.self) { step in
                    ZStack {
                        Circle()
                            .fill(step <= currentStep ? Color.blue : Color(.systemGray4))
                            .frame(width: 12, height: 12)
                        
                        if step < currentStep {
                            Image(systemName: "checkmark")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    
                    if step < totalSteps - 1 {
                        Rectangle()
                            .fill(step < currentStep ? Color.blue : Color(.systemGray4))
                            .frame(height: 2)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(.horizontal, 40)
            
            // Step counter
            Text("Step \(currentStep + 1) of \(totalSteps)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 20)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Step Views
    
    private var backgroundImageStep: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "photo.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.blue)
                
                Text("Choose Background Image")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Select an image that represents your organization. This will be displayed behind your donation interface.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Image preview/selector
            VStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.secondarySystemBackground))
                        .frame(height: 200)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color(.separator), lineWidth: 1)
                        )
                    
                    if let backgroundImage = backgroundImage {
                        Image(uiImage: backgroundImage)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                // Text preview overlay
                                ZStack {
                                    Rectangle()
                                        .fill(.black.opacity(0.4))
                                        .clipShape(RoundedRectangle(cornerRadius: 16))
                                    
                                    VStack(spacing: 8) {
                                        Text("Tap to Donate")
                                            .font(.title)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                        
                                        Text("Support our mission")
                                            .font(.subheadline)
                                            .foregroundColor(.white.opacity(0.9))
                                    }
                                }
                            )
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 40))
                                .foregroundColor(.blue)
                            
                            Text("Tap to select image")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                                .fontWeight(.medium)
                        }
                    }
                }
                .onTapGesture {
                    showingImagePicker = true
                }
                
                if backgroundImage != nil {
                    Button("Change Image") {
                        showingImagePicker = true
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
            }
            
            // Info box
            HStack(spacing: 12) {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.orange)
                
                Text("Tip: Choose an image that's visually appealing but not too busy. A dark overlay will be applied to ensure text is readable.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(Color(.tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    private var organizationNameStep: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "building.2.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.blue)
                
                Text("Organization Name")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Enter your official organization name. This will appear on donation receipts and help donors identify your cause.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Input field
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Organization Name")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    TextField("Enter your organization name", text: $organizationName, prompt: Text("e.g., Community Food Bank"))
                        .textFieldStyle(GuidedSetupTextFieldStyle())
                        .autocapitalization(.words)
                        .disableAutocorrection(false)
                }
                
                // Preview
                if !organizationName.isEmpty {
                    VStack(spacing: 12) {
                        Text("Receipt Preview")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        VStack(spacing: 8) {
                            Text("DONATION RECEIPT")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.secondary)
                            
                            Text(organizationName)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .multilineTextAlignment(.center)
                        }
                        .padding(16)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                } else {
                    // Show example when empty
                    VStack(spacing: 12) {
                        Text("Receipt Preview")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        VStack(spacing: 8) {
                            Text("DONATION RECEIPT")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.secondary)
                            
                            Text("Your Organization Name")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                                .italic()
                                .multilineTextAlignment(.center)
                        }
                        .padding(16)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            
            // Info box
            HStack(spacing: 12) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                
                Text("Use your official registered name as it appears on your tax documents for the most professional receipts.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(Color(.tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    private var taxIdStep: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.blue)
                
                Text("Tax ID (EIN)")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Enter your Employer Identification Number (EIN). This is required for donors to claim tax deductions on their charitable contributions.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Input field
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tax ID (EIN)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    TextField("", text: $taxId, prompt: Text("12-3456789"))
                        .textFieldStyle(GuidedSetupTextFieldStyle())
                        .keyboardType(.numbersAndPunctuation)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                
                // Format helper
                Text("Format: XX-XXXXXXX")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Live preview of entered value
                if !taxId.isEmpty {
                    VStack(spacing: 8) {
                        Text("Your EIN")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        HStack {
                            Text("Tax ID:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text(taxId)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            
                            Spacer()
                        }
                        .padding(12)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            
            // Info boxes
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.green)
                    
                    Text("Required for tax-deductible donation receipts")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(16)
                .background(Color(.tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                HStack(spacing: 12) {
                    Image(systemName: "shield.checkered")
                        .foregroundColor(.blue)
                    
                    Text("This information is only used for generating proper donation receipts and is never shared with third parties.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(16)
                .background(Color(.tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
    
    // MARK: - Navigation Buttons
    
    private var navigationButtons: some View {
        VStack(spacing: 12) {
            Divider()
            
            HStack(spacing: 16) {
                // Back button
                if currentStep > 0 {
                    Button("Back") {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentStep -= 1
                        }
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .frame(maxWidth: .infinity)
                }
                
                // Next/Complete button
                Button(currentStep == totalSteps - 1 ? "Complete Setup" : "Next") {
                    if currentStep == totalSteps - 1 {
                        completeSetup()
                    } else {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentStep += 1
                        }
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .frame(maxWidth: .infinity)
                .disabled(isCurrentStepInvalid || isCompleting)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .background(Color(.systemBackground))
    }
    
    // MARK: - Helper Properties
    
    private var isCurrentStepInvalid: Bool {
        switch currentStep {
        case 0:
            return false // Background image is optional
        case 1:
            return organizationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case 2:
            return taxId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        default:
            return false
        }
    }
    
    // MARK: - Functions
    
    private func loadExistingValues() {
        // Pre-populate with existing values (only if they're not default/placeholder values)
        backgroundImage = kioskStore.backgroundImage
        
        // Only load organization name if it's not the default placeholder
        let currentOrgName = organizationStore.name
        if currentOrgName != "Your Organization" && !currentOrgName.isEmpty {
            organizationName = currentOrgName
        }
        
        // Only load tax ID if it's not the default placeholder
        let currentTaxId = organizationStore.taxId
        if currentTaxId != "12-3456789" && !currentTaxId.isEmpty {
            taxId = currentTaxId
        }
    }
    
    private func completeSetup() {
        isCompleting = true
        
        // Save background image
        if let backgroundImage = backgroundImage {
            kioskStore.backgroundImage = backgroundImage
        }
        
        // Save organization details
        organizationStore.name = organizationName.trimmingCharacters(in: .whitespacesAndNewlines)
        organizationStore.taxId = taxId.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Save to storage
        kioskStore.saveSettings()
        organizationStore.saveToUserDefaults()
        
        // Brief delay for good UX, then dismiss and launch kiosk
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            dismiss()
            
            // Post notification to launch kiosk
            NotificationCenter.default.post(
                name: Notification.Name("LaunchKioskFromQuickSetup"),
                object: nil
            )
        }
    }
}

// MARK: - Supporting Views and Styles

struct GuidedSetupTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(16)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.separator), lineWidth: 1)
            )
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(configuration.isPressed ? Color.blue.opacity(0.8) : Color.blue)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .fontWeight(.medium)
            .foregroundColor(.primary)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Quick Setup Card for AdminDashboardView (OLD DESIGN)

struct QuickSetupCard: View {
    @State private var showingGuidedSetup = false
    
    var body: some View {
        VStack(spacing: 16) {
            Button(action: {
                showingGuidedSetup = true
            }) {
                Text("Start Quick Setup")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [Color.green, Color.blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(20)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .sheet(isPresented: $showingGuidedSetup) {
            GuidedSetupView()
        }
    }
}

struct QuickSetupStepRow: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 24, height: 24)
                
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(color)
            }
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct GuidedSetupView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            GuidedSetupView()
                .environmentObject(KioskStore())
                .environmentObject(OrganizationStore())
            
            QuickSetupCard()
                .padding()
                .background(Color(.systemGroupedBackground))
        }
    }
}
