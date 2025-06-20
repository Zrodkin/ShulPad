import SwiftUI

struct SupportView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingEmailComposer = false
    @State private var deviceInfo = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                // Clean solid background
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        // Contact options
                        VStack(spacing: 16) {
                            // WhatsApp option
                            ContactOptionCard(
                                icon: "message.fill",
                                title: "WhatsApp Support",
                                subtitle: "Get instant help via WhatsApp",
                                description: "Chat with our support team in real-time. Perfect for quick questions and immediate assistance.",
                                buttonText: "Open WhatsApp",
                                buttonColor: Color.green,
                                action: openWhatsApp
                            )
                            
                            // Email option
                            ContactOptionCard(
                                icon: "envelope.fill",
                                title: "Email Support",
                                subtitle: "Send us a detailed message",
                                description: "Perfect for complex issues or when you need to share screenshots and detailed information.",
                                buttonText: "Send Email",
                                buttonColor: Color.blue,
                                action: openEmail
                            )
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 30)
                        
                        Spacer(minLength: 40)
                        
                        // Enhanced FAQ section
                        VStack(alignment: .leading, spacing: 20) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Frequently Asked Questions")
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                    
                                    Text("Quick answers to common setup questions")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            
                            VStack(spacing: 16) {
                                EnhancedFAQItem(
                                    question: "How do I connect my Square account?",
                                    answer: "Click 'Connect with Square' on the onboarding screen and follow the authorization steps in your browser."
                                )
                                
                                EnhancedFAQItem(
                                    question: "What Square features do I need?",
                                    answer: "You'll need a Square account with payment processing enabled and access to card readers if you want in-person donations."
                                )
                                
                                EnhancedFAQItem(
                                    question: "Can I customize the donation amounts?",
                                    answer: "Yes! Once connected, you can set custom preset amounts and configure your kiosk appearance in the admin panel."
                                )
                                
                                EnhancedFAQItem(
                                    question: "Is my data secure?",
                                    answer: "Absolutely. We use Square's secure payment processing and don't store sensitive payment information."
                                )
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        Spacer(minLength: 60)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                    .fontWeight(.medium)
                }
            }
        }
        .onAppear {
            generateDeviceInfo()
        }
    }
    
    // MARK: - Actions
    
    private func openWhatsApp() {
        let message = """
        Hi! I need help setting up ShulPad.
        
        Device: \(deviceInfo)
        
        My question is: 
        """
        
        let encodedMessage = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let phoneNumber = "16179032387" // Replace with your actual WhatsApp business number
        
        if let whatsappURL = URL(string: "https://wa.me/\(phoneNumber)?text=\(encodedMessage)") {
            if UIApplication.shared.canOpenURL(whatsappURL) {
                UIApplication.shared.open(whatsappURL)
            } else {
                // Fallback to WhatsApp web if app not installed
                if let webURL = URL(string: "https://web.whatsapp.com/send?phone=\(phoneNumber)&text=\(encodedMessage)") {
                    UIApplication.shared.open(webURL)
                }
            }
        }
    }
    
    private func openEmail() {
        let subject = "ShulPad Support Request"
        let body = """
        Hi ShulPad Support Team,
        
        I need help with setting up ShulPad.
        
        Device Information:
        \(deviceInfo)
        
        My question/issue is:
        [Please describe your question or issue here]
        
        Thank you for your help!
        """
        
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        if let emailURL = URL(string: "mailto:hello@shulpad.com?subject=\(encodedSubject)&body=\(encodedBody)") {
            if UIApplication.shared.canOpenURL(emailURL) {
                UIApplication.shared.open(emailURL)
            }
        }
    }
    
    private func generateDeviceInfo() {
        let device = UIDevice.current
        let systemVersion = device.systemVersion
        let model = device.model
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        
        deviceInfo = """
        iOS: \(systemVersion)
        Device: \(model)
        App Version: \(appVersion)
        """
    }
}

// MARK: - Enhanced FAQ Item

struct EnhancedFAQItem: View {
    let question: String
    let answer: String
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 0) {
            Button(action: {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Text(question)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isExpanded)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                VStack(spacing: 0) {
                    Divider()
                        .padding(.horizontal, 20)
                    
                    Text(answer)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.separator), lineWidth: 0.5)
        )
    }
}

// MARK: - Legacy FAQ Item (keeping for compatibility)

struct ContactOptionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let description: String
    let buttonText: String
    let buttonColor: Color
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Card content
            VStack(spacing: 16) {
                // Icon and titles
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(buttonColor.opacity(0.15))
                            .frame(width: 60, height: 60)
                        
                        Image(systemName: icon)
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(buttonColor)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                // Description
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            
            // Action button
            Button(action: action) {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                    
                    Text(buttonText)
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(buttonColor)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
    }
}

struct FAQItem: View {
    let question: String
    let answer: String
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 0) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Text(question)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                VStack {
                    Text(answer)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.tertiarySystemBackground))
        )
    }
}

// MARK: - Preview

struct SupportView_Previews: PreviewProvider {
    static var previews: some View {
        SupportView()
    }
}
