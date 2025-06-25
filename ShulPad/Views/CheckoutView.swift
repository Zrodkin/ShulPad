//
//  CheckoutView.swift
//  ShulPad
//
//  Created by Zalman Rodkin on 6/24/25.
//

import SwiftUI

struct PaymentCheckoutOverlays: View {
    @EnvironmentObject private var organizationStore: OrganizationStore
    @EnvironmentObject var donationViewModel: DonationViewModel
    @EnvironmentObject var paymentService: SquarePaymentService
    
    // Payment processing states
    @Binding var isProcessingPayment: Bool
    @Binding var showingThankYou: Bool
    @Binding var showingReceiptPrompt: Bool
    @Binding var showingEmailEntry: Bool
    @Binding var emailAddress: String
    @Binding var isEmailValid: Bool
    @Binding var isSendingReceipt: Bool
    @Binding var orderId: String?
    @Binding var paymentId: String?
    @Binding var receiptErrorAlertMessage: String?
    @Binding var showReceiptErrorAlert: Bool
    
    // Callbacks
    let onSuccessfulCompletion: () -> Void
    let onResetTimeout: () -> Void
    
    var body: some View {
        ZStack {
            // Payment processing overlay
            if isProcessingPayment {
                paymentProcessingOverlay
            }
            
            // Success overlay
            if showingThankYou {
                thankYouOverlay
            }
            
            // Receipt prompt overlay
            if showingReceiptPrompt {
                receiptPromptOverlay
            }
            
            // Email entry overlay
            if showingEmailEntry {
                emailEntryOverlay
            }
        }
        .alert(isPresented: $showReceiptErrorAlert) {
            Alert(
                title: Text("Receipt Error"),
                message: Text(receiptErrorAlertMessage ?? "An unknown error occurred."),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    // MARK: - Overlay Views (from DonationSelectionView)
    
    private var paymentProcessingOverlay: some View {
        ZStack {
            Color.black.opacity(0.8)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                
                VStack(spacing: 8) {
                    Text("Processing Payment")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Please follow the prompts on your card reader")
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
            }
            .padding(40)
        }
    }
    
    private var thankYouOverlay: some View {
        ZStack {
            Color.black.opacity(0.8)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 70))
                    .foregroundColor(.green)
                
                Text("Thank You!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Your donation has been processed.")
                    .foregroundColor(.white)
                
                Button("Done") {
                    onSuccessfulCompletion()
                }
                .padding(.horizontal, 40)
                .padding(.vertical, 10)
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding(.top, 20)
            }
            .padding()
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                if showingThankYou {
                    onSuccessfulCompletion()
                }
            }
        }
    }
    
    // Receipt prompt overlay - USING DonationSelectionView version (darker and higher)
    private var receiptPromptOverlay: some View {
        Color.clear
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                Color.black.opacity(0.9)
                    .edgesIgnoringSafeArea(.all)
            }
            .overlay(alignment: .center) {
                VStack(spacing: 30) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.2))
                            .frame(width: 100, height: 100)
                        
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.blue)
                    }
                    
                    VStack(spacing: 16) {
                        Text("Would you like a receipt?")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        
                        Text("We can send you a donation receipt for your tax records")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                    
                    VStack(spacing: 16) {
                        // Email receipt button
                        Button(action: {
                            showingReceiptPrompt = false
                            showingEmailEntry = true
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "envelope.fill")
                                    .font(.system(size: 18))
                                Text("Email receipt")
                                    .font(.headline)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.blue)
                            .cornerRadius(12)
                        }
                        
                        // No Receipt button
                        Button(action: {
                            showingReceiptPrompt = false
                            showingThankYou = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                if showingThankYou {
                                    onSuccessfulCompletion()
                                }
                            }
                        }) {
                            Text("No Receipt")
                                .foregroundColor(.white)
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color.clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.3), lineWidth: 2)
                                )
                        }
                    }
                    .padding(.horizontal, 40)
                }
                .padding(40)
                .offset(y: -80) // Adjust this to move higher/lower
            }
    }
    
    private var emailEntryOverlay: some View {
        Color.clear
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                Color.black.opacity(0.9)
                    .edgesIgnoringSafeArea(.all)
            }
            .overlay(alignment: .center) {
                VStack(spacing: 30) {
                    // Email icon
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.2))
                            .frame(width: 100, height: 100)
                        
                        Image(systemName: "at")
                            .font(.system(size: 40, weight: .medium))
                            .foregroundColor(.blue)
                    }
                    
                    VStack(spacing: 16) {
                        Text("Enter your email")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("We'll send your donation receipt to this email address")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                    
                    // Email input field - FIXED: Removed placeholder text
                    VStack(spacing: 12) {
                        TextField("", text: $emailAddress)
                            .textFieldStyle(EmailTextFieldStyle())
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .onChange(of: emailAddress) { _, newValue in
                                validateEmail(newValue)
                                onResetTimeout()
                            }
                        
                        if !emailAddress.isEmpty && !isEmailValid {
                            Text("Please enter a valid email address")
                                .font(.caption)
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 20)
                        }
                    }
                    .padding(.horizontal, 40)
                    
                    VStack(spacing: 16) {
                        Button(action: sendReceipt) {
                            HStack {
                                if isSendingReceipt {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.9)
                                    Text("Sending...")
                                } else {
                                    Image(systemName: "paperplane.fill")
                                    Text("Send Receipt")
                                }
                            }
                            .foregroundColor(.white)
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(isEmailValid && !isSendingReceipt ? Color.green : Color.gray)
                            .cornerRadius(12)
                        }
                        .disabled(!isEmailValid || isSendingReceipt)
                        
                        Button(action: {
                            showingEmailEntry = false
                            showingReceiptPrompt = true
                            emailAddress = ""
                            isEmailValid = false
                        }) {
                            Text("Back")
                                .foregroundColor(.white)
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color.clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.3), lineWidth: 2)
                                )
                        }
                        .disabled(isSendingReceipt)
                    }
                    .padding(.horizontal, 40)
                }
                .padding(40)
                .offset(y: -80) // Same positioning as receipt prompt
            }
    }
    
    // MARK: - Helper Methods
    
    private func validateEmail(_ email: String) {
        let emailRegex = "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        isEmailValid = emailPredicate.evaluate(with: email)
    }
    
    private func sendReceipt() {
        guard isEmailValid && !emailAddress.isEmpty else { return }
        
        isSendingReceipt = true
        print("📧 Sending receipt to: \(emailAddress)")
        print("📧 Order ID: \(orderId ?? "N/A")")
        print("📧 Payment ID: \(paymentId ?? "N/A")")
        print("📧 Amount: \(donationViewModel.selectedAmount ?? 0)")
        
        guard let url = URL(string: "\(SquareConfig.backendBaseURL)/api/receipts/send") else {
            print("❌ Invalid receipt API URL")
            self.handleReceiptError("Invalid server configuration. Please contact support.")
            return
        }
        
        let requestBody: [String: Any] = [
            "organization_id": SquareConfig.organizationId,
            "donor_email": emailAddress,
            "amount": donationViewModel.selectedAmount ?? 0,
            "transaction_id": paymentId ?? "",
            "order_id": orderId ?? "",
            "payment_date": ISO8601DateFormatter().string(from: Date()),
            "organization_name": organizationStore.name,
            "organization_tax_id": organizationStore.taxId,
            "organization_receipt_message": organizationStore.receiptMessage
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30.0
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            print("❌ Failed to serialize receipt request: \(error)")
            self.handleReceiptError("Failed to prepare the receipt request. Please try again.")
            return
        }
        
        print("🌐 Sending receipt request to: \(url)")
        
        if let jsonString = String(data: request.httpBody!, encoding: .utf8) {
            print("📤 Request body: \(jsonString)")
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isSendingReceipt = false
                
                if let error = error {
                    print("❌ Network error sending receipt: \(error.localizedDescription)")
                    if (error as NSError).code == NSURLErrorTimedOut {
                        self.handleReceiptError("The request timed out. Your receipt may still be sent. Please check your email or contact support if it doesn't arrive.")
                    } else {
                        self.handleReceiptError("A network error occurred while sending the receipt. Please check your connection and try again.")
                    }
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("❌ Invalid response from receipt API")
                    self.handleReceiptError("Received an invalid response from the server. Please try again.")
                    return
                }
                
                print("📧 Receipt API response: \(httpResponse.statusCode)")
                
                if let data = data, let responseString = String(data: data, encoding: .utf8) {
                    print("📥 Response body: \(responseString)")
                }
                
                switch httpResponse.statusCode {
                case 200:
                    if let data = data,
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let success = json["success"] as? Bool,
                       success {
                        print("✅ Receipt sent successfully")
                        if let receiptId = json["receipt_id"] as? String {
                            print("📧 Receipt ID: \(receiptId)")
                        }
                        self.showEmailSuccessAndComplete()
                    } else {
                        print("⚠️ Unexpected success response format from server.")
                        self.showEmailSuccessAndComplete()
                    }
                    
                case 400:
                    print("❌ Bad request (400)")
                    self.handleReceiptError("There was an issue with the information provided for the receipt. Please check and try again.")
                    
                case 404:
                    print("❌ Organization not found (404)")
                    self.handleReceiptError("The receipt service for this organization is not configured correctly. Please contact support.")
                    
                case 429:
                    print("❌ Rate limited (429)")
                    self.handleReceiptError("We've received too many requests. Please try sending the receipt again in a few moments.")
                    
                case 500...599:
                    print("❌ Server error (\(httpResponse.statusCode))")
                    self.handleReceiptError("A server error occurred while sending the receipt. Your donation was processed, but the receipt may be delayed. Please contact support if it doesn't arrive.")
                    
                default:
                    print("❌ Unexpected status code: \(httpResponse.statusCode)")
                    self.handleReceiptError("An unexpected error occurred while sending the receipt (Code: \(httpResponse.statusCode)). Please try again or contact support.")
                }
            }
        }.resume()
    }

    private func handleReceiptError(_ message: String) {
        print("🔴 Receipt Error: \(message)")
        self.receiptErrorAlertMessage = message
        self.showReceiptErrorAlert = true
    }
    
    private func showEmailSuccessAndComplete() {
        showingEmailEntry = false
        showingThankYou = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            if showingThankYou {
                onSuccessfulCompletion()
            }
        }
    }
}

// MARK: - Supporting Components (if not already defined elsewhere)

struct EmailTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(.title3)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
            )
            .foregroundColor(.black)
    }
}
