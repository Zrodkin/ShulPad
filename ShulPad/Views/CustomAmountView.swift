import SwiftUI

struct UpdatedCustomAmountView: View {
    @EnvironmentObject var kioskStore: KioskStore
    @EnvironmentObject var donationViewModel: DonationViewModel
    @EnvironmentObject var squareAuthService: SquareAuthService
    @EnvironmentObject var paymentService: SquarePaymentService
    @EnvironmentObject private var organizationStore: OrganizationStore
    @Environment(\.dismiss) private var dismiss
    @State private var amountString: String = ""
    @State private var errorMessage: String? = nil
    @State private var shakeOffset: CGFloat = 0
    @State private var navigateToCheckout = false
    @State private var navigateToHome = false
    @State private var selectedAmount: Double = 0
    
    @State private var timeoutTimer: Timer?
    
    // Payment processing states
    @State private var isProcessingPayment = false
    @State private var showingSquareAuth = false
    @State private var showingThankYou = false
    @State private var showingReceiptPrompt = false
    @State private var showingEmailEntry = false
    @State private var emailAddress = ""
    @State private var isEmailValid = false
    @State private var isSendingReceipt = false
    @State private var orderId: String? = nil
    @State private var paymentId: String? = nil
    @State private var receiptErrorAlertMessage: String? = nil
    @State private var showReceiptErrorAlert = false
    
    // Callback for when amount is selected
    var onAmountSelected: (Double) -> Void
    
    var body: some View {
        ZStack {
            // Background image
            if let backgroundImage = kioskStore.backgroundImage {
                Image(uiImage: backgroundImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .edgesIgnoringSafeArea(.all)
                    .blur(radius: 5)
            } else {
                Image("logoImage")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .edgesIgnoringSafeArea(.all)
                    .blur(radius: 5)
            }
            
            Color.black.opacity(0.55)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: KioskLayoutConstants.topContentOffset)
                
                // Amount display
                Text("$\(amountString.isEmpty ? "0" : amountString)")
                    .font(.system(size: 65, weight: .bold))
                    .foregroundColor(.white)
                    .offset(x: shakeOffset)
                    .animation(.easeInOut(duration: 0.1), value: shakeOffset)
                
                Spacer()
                    .frame(height: 20)
                
                // Error message
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 16))
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.red.opacity(0.7))
                        .cornerRadius(10)
                        .transition(.opacity)
                }
                
                Spacer()
                    .frame(height: 30)
                
                // Keypad
                VStack(spacing: 12) {
                    // Row 1
                    HStack(spacing: 12) {
                        ForEach(1...3, id: \.self) { num in
                            KeypadButton(number: num, letters: num == 2 ? "ABC" : num == 3 ? "DEF" : "") {
                                handleNumberPress(String(num))
                            }
                        }
                    }
                    
                    // Row 2
                    HStack(spacing: 12) {
                        ForEach(4...6, id: \.self) { num in
                            KeypadButton(number: num, letters: num == 4 ? "GHI" : num == 5 ? "JKL" : "MNO") {
                                handleNumberPress(String(num))
                            }
                        }
                    }
                    
                    // Row 3
                    HStack(spacing: 12) {
                        ForEach(7...9, id: \.self) { num in
                            KeypadButton(number: num, letters: num == 7 ? "PQRS" : num == 8 ? "TUV" : "WXYZ") {
                                handleNumberPress(String(num))
                            }
                        }
                    }
                    
                    // Row 4
                    HStack(spacing: 12) {
                        // Delete button
                        Button(action: handleDelete) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.2))
                                    .frame(height: 64)
                                
                                Image(systemName: "delete.left")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white)
                            }
                        }
                        
                        // 0 button
                        KeypadButton(number: 0, letters: "") {
                            handleNumberPress("0")
                        }
                        
                        // Process Payment button
                        Button(action: {
                            handleDone()
                        }) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.green.opacity(0.8))
                                    .frame(height: 64)
                                
                                if isProcessingPayment {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "creditcard")
                                        .font(.system(size: 20, weight: .medium))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .disabled(isProcessingPayment)
                    }
                    
                    
                }
                .frame(maxWidth: KioskLayoutConstants.maxContentWidth)
                .padding(.horizontal, KioskLayoutConstants.contentHorizontalPadding)
                
                Spacer()
                    .frame(height: KioskLayoutConstants.bottomSafeArea)
            }
            
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
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    timeoutTimer?.invalidate()
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Circle().fill(Color.white.opacity(0.2)))
                }
            }
        }
        .onAppear {
            if !paymentService.isReaderConnected {
                paymentService.connectToReader()
            }
            startTimeout()
        }
        
        .navigationDestination(isPresented: $navigateToHome) {
            HomeView()
                .navigationBarBackButtonHidden(true)
        }
        .sheet(isPresented: $showingSquareAuth) {
            SquareAuthorizationView()
        }
        // ADD THESE MODIFIERS:
        .onDisappear {
            timeoutTimer?.invalidate()
            timeoutTimer = nil
        }
        .onTapGesture {
            resetTimeout()
        }
        .contentShape(Rectangle())
        // 🔧 REMOVED: The problematic onReceive that was causing race conditions
        // This was interfering with the completion handler and causing cancelled payments
        // to incorrectly show the thank you screen
    }
    
    // MARK: - UI Overlays
    
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
                

                
                // 🔧 CHANGED: "Done" now goes directly to completion
                Button("Done") {
                    handleSuccessfulCompletion()
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
        // 🔧 CHANGED: Auto-dismiss after 3 seconds goes to completion, not receipt prompt
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                if showingThankYou {
                    handleSuccessfulCompletion()
                }
            }
        }
    }
    
    private var receiptPromptOverlay: some View {
        ZStack {
            Color.black.opacity(0.8)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 30) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.blue)
                }
                
                VStack(spacing: 16) {
                    Text("Would you like a receipt?")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    Text("We can email you a donation receipt for your tax records")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                
                VStack(spacing: 16) {
                    // "Yes, send receipt" button - FIXED
                    Button(action: {
                        showingReceiptPrompt = false
                        showingEmailEntry = true
                    }) {
                        Text("Yes, send receipt")
                            .foregroundColor(.white)
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56) // ← ADD: Fixed height for consistency
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                    
                    // "No thanks" button - FIXED
                    Button(action: {
                        showingReceiptPrompt = false
                        showingThankYou = true
                        // Add auto-dismiss after showing thank you
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            if showingThankYou {
                                handleSuccessfulCompletion()
                            }
                        }
                    }) {
                        Text("No thanks")
                            .foregroundColor(.white)
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56) // ← ADD: Fixed height for consistency
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
        }
    }
    
    private var emailEntryOverlay: some View {
        ZStack {
            Color.black.opacity(0.8)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 30) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.2))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "at")
                        .font(.system(size: 40, weight: .medium))
                        .foregroundColor(.green)
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
                
                VStack(spacing: 12) {
                    // FIXED: Removed placeholder text
                    TextField("", text: $emailAddress)
                        .textFieldStyle(EmailTextFieldStyle())
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .onChange(of: emailAddress) { _, newValue in
                            validateEmail(newValue)
                            resetTimeout() 
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
                    // FIXED: Send Receipt button - moved styling inside
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
                    
                    // FIXED: Back button - moved styling inside
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
        }
    }
    
    // MARK: - Helper Methods
    
    private func handleNumberPress(_ num: String) {
        resetTimeout()
        let maxDigits = 7
        
        if amountString.isEmpty && num == "0" {
            return
        }
        
        let tempAmount = amountString + num
        if let amount = Double(tempAmount),
           let maxAmount = Double(kioskStore.maxAmount) {
            if amount > maxAmount {
                withAnimation(.easeInOut(duration: 0.3)) {
                    errorMessage = "Maximum amount is $\(Int(maxAmount))"
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        errorMessage = nil
                    }
                }
                return
            }
        }
        
        if amountString.count < maxDigits {
            amountString += num
        }
        
        if errorMessage != nil {
            withAnimation(.easeInOut(duration: 0.3)) {
                errorMessage = nil
            }
        }
        
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func handleDelete() {
        resetTimeout()
        if !amountString.isEmpty {
            amountString.removeLast()
        }
        
        if errorMessage != nil {
            withAnimation(.easeInOut(duration: 0.3)) {
                errorMessage = nil
            }
        }
        
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func handleDone() {
        resetTimeout()
            guard !isProcessingPayment else {
                return
            }
            
            guard let amount = Double(amountString), amount > 0 else {
                if amountString.isEmpty {
                    withAnimation(.interpolatingSpring(stiffness: 600, damping: 5)) {
                        shakeAmount()
                    }
                    
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        impactFeedback.impactOccurred()
                    }
                    
                    return
                } else {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        errorMessage = "Please enter a valid amount"
                    }
                }
                return
            }
            
            if let minAmount = Double(kioskStore.minAmount), amount < minAmount {
                withAnimation(.easeInOut(duration: 0.3)) {
                    errorMessage = "Minimum amount is $\(Int(minAmount))"
                }
                return
            }
            
            if let maxAmount = Double(kioskStore.maxAmount), amount > maxAmount {
                withAnimation(.easeInOut(duration: 0.3)) {
                    errorMessage = "Maximum amount is $\(Int(maxAmount))"
                }
                return
            }
            
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
            selectedAmount = amount
            donationViewModel.selectedAmount = amount
            donationViewModel.isCustomAmount = true
            
            onAmountSelected(amount)
            
            processPayment(amount: amount, isCustomAmount: true)
        }
    
   
    // FIXED: Replace the success handling in processPayment method in UpdatedCustomAmountView.swift
  private func processPayment(amount: Double, isCustomAmount: Bool) {
      timeoutTimer?.invalidate()
        if !squareAuthService.isAuthenticated {
            showingSquareAuth = true
            return
        }

        if !paymentService.isReaderConnected {
            print("⚠️ No reader connected - will attempt to connect during payment")
            // Don't return here - let the payment service handle reader connection
        }
        
        resetPaymentState()
        isProcessingPayment = true
        
        paymentService.processPayment(
            amount: amount,
            orderId: nil,
            isCustomAmount: isCustomAmount,
            catalogItemId: nil,
            allowOffline: true
        ) { success, transactionId in
            print("🎯 CustomAmount Completion handler: success=\(success), transactionId=\(transactionId ?? "nil")")
            
            DispatchQueue.main.async {
                // Always reset processing state first
                self.isProcessingPayment = false
                
                if success {
                    print("✅ Payment Success: Recording donation and showing receipt prompt")
                    // Record the donation
                    self.donationViewModel.recordDonation(amount: amount, transactionId: transactionId)
                    self.orderId = self.paymentService.currentOrderId
                    self.paymentId = transactionId
                    
                    // 🔧 NEW FLOW: Go directly to receipt prompt, skip thank you initially
                    self.showingReceiptPrompt = true
                } else {
                    print("❌ Payment Cancelled/Failed: Going back to previous screen")
                    self.handleSilentFailureOrCancellation()
                }
            }
        }
    }
    
    private func handleNavigateToHome() {
        print("🏠 Navigating to home from CustomAmountView")
        
        // Reset navigation state
        navigateToCheckout = false
        
        // Reset donation state
        donationViewModel.resetDonation()
        
        // Only navigate if home page is enabled, otherwise dismiss to parent
        if kioskStore.homePageEnabled {
            navigateToHome = true
        } else {
            // Home page is disabled, so just dismiss back to DonationSelectionView
            resetPaymentState()
            dismiss()
        }
    }
    
    private func handleSilentFailureOrCancellation() {
        paymentService.paymentError = nil
        resetPaymentState()
        
        // Handle navigation based on home page setting
        if kioskStore.homePageEnabled {
            navigateToHome = true
        } else {
            // Home page disabled, dismiss back to DonationSelectionView
            dismiss()
        }
    }
    
    private func handleSuccessfulCompletion() {
        resetPaymentState()
        donationViewModel.resetDonation()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if self.kioskStore.homePageEnabled {
                self.navigateToHome = true
            } else {
                // Home page disabled, dismiss to DonationSelectionView
                self.dismiss()
            }
        }
    }
    
    private func resetPaymentState() {
        isProcessingPayment = false
        showingThankYou = false
        showingReceiptPrompt = false
        showingEmailEntry = false
        orderId = nil
        paymentId = nil
        emailAddress = ""
        isEmailValid = false
        isSendingReceipt = false
    }
    
    private func validateEmail(_ email: String) {
        let emailRegex = "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        isEmailValid = emailPredicate.evaluate(with: email)
    }
    
    // 🆕 Send receipt via backend API with proper error handling
    private func sendReceipt() {
        guard isEmailValid && !emailAddress.isEmpty else { return }
        
        isSendingReceipt = true
        print("📧 Sending receipt to: \(emailAddress)")
        print("📧 Order ID: \(orderId ?? "N/A")")
        print("📧 Payment ID: \(paymentId ?? "N/A")")
        // FIX 1: Use self.selectedAmount
        print("📧 Amount: $\(self.selectedAmount)")
        
        guard let url = URL(string: "\(SquareConfig.backendBaseURL)/api/receipts/send") else {
            print("❌ Invalid receipt API URL")
            // FIX 2: Call the new handleReceiptError function
            self.handleReceiptError("Invalid server configuration")
            return
        }
        
        let requestBody: [String: Any] = [
            "organization_id": SquareConfig.organizationId,
            "donor_email": emailAddress,
            "amount": self.selectedAmount,
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
            // FIX 2: Call the new handleReceiptError function
            self.handleReceiptError("Failed to prepare request")
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
                        // FIX 2: Call the new handleReceiptError function
                        self.handleReceiptError("Request timed out. Receipt may still be sent.")
                    } else {
                        // FIX 2: Call the new handleReceiptError function
                        self.handleReceiptError("Network error occurred")
                    }
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("❌ Invalid response from receipt API")
                    // FIX 2: Call the new handleReceiptError function
                    self.handleReceiptError("Invalid server response")
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
                        print("⚠️ Unexpected success response format")
                        self.showEmailSuccessAndComplete()
                    }
                case 400:
                    print("❌ Bad request (400)")
                    // FIX 2: Call the new handleReceiptError function
                    self.handleReceiptError("Invalid email or request")
                case 404:
                    print("❌ Organization not found (404)")
                    // FIX 2: Call the new handleReceiptError function
                    self.handleReceiptError("Organization not configured")
                case 429:
                    print("❌ Rate limited (429)")
                    // FIX 2: Call the new handleReceiptError function
                    self.handleReceiptError("Too many requests. Please try again later.")
                case 500...599:
                    print("❌ Server error (\(httpResponse.statusCode))")
                    // FIX 2: Call the new handleReceiptError function
                    self.handleReceiptError("Server error. Receipt may be delayed.")
                default:
                    print("❌ Unexpected status code: \(httpResponse.statusCode)")
                    // FIX 2: Call the new handleReceiptError function
                    self.handleReceiptError("Unexpected error occurred")
                }
            }
        }.resume()
    }
    
    
    private func handleReceiptError(_ message: String) {
        // You can use an existing @State variable for showing alerts/messages
        // or create a new one specifically for receipt errors.
        // For now, let's reuse the existing errorMessage and assume you have a way to display it.
        // You might want to show an Alert.
        print("🔴 Receipt Error: \(message)")
        self.errorMessage = message // This will show the error message in your existing error display area.
        // Consider adding a @State var to trigger an Alert.
        
        // Optionally, decide if you still want to proceed to showEmailSuccessAndComplete
        // or keep the user on the email entry screen to try again or see the error.
        // For a critical error, you might not call showEmailSuccessAndComplete().
        // For a timeout where it might have been sent, you might.
        // For this example, we're just setting the message. You'll need to decide the UX.
        // For instance, after setting the error, you might want to keep showingEmailEntry = true
        // and not call showEmailSuccessAndComplete().
        
        // Example: Forcing the email entry view to stay if there's an error
        // self.showingEmailEntry = true
        // self.isSendingReceipt = false // Ensure button is re-enabled
    }
    
    // Ensure this function exists and handles UI appropriately
    private func showEmailSuccessAndComplete() {
        showingEmailEntry = false
        // 🔧 CHANGED: After email success, show thank you instead of going home
        showingThankYou = true
        
        // Auto-dismiss thank you after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            if showingThankYou {
                handleSuccessfulCompletion()
            }
        }
    }
    
    
    private func shakeAmount() {
            let shakeSequence: [CGFloat] = [0, -8, 8, -6, 6, -4, 4, -2, 2, 0]
            
            for (index, offset) in shakeSequence.enumerated() {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.05) {
                    shakeOffset = offset
                }
            }
        }
    
    // MARK: - Timeout Management

    private func startTimeout() {
        timeoutTimer?.invalidate()
        let timeoutSeconds = Double(kioskStore.timeoutDuration) ?? 10.0
        timeoutTimer = Timer.scheduledTimer(withTimeInterval: timeoutSeconds, repeats: false) { _ in
            navigateToHome = true
        }
    }

    private func resetTimeout() {
        startTimeout()
    }
}
// MARK: - Supporting Components

struct KeypadButton: View {
    let number: Int
    let letters: String
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            action()
        }) {
            VStack(spacing: 2) {
                Text("\(number)")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                if !letters.isEmpty {
                    Text(letters)
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.3))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.2))
            )
        }
        .buttonStyle(KeypadButtonStyle())
    }
}

struct KeypadButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct EmailTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(.title3)                    // ← Text size
            .padding(.horizontal, 20)         // ← Spacing
            .padding(.vertical, 16)           // ← Spacing
            .background(                      // ← White background
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
            )
            .foregroundColor(.black)          // ← Text color
    }
}


struct UpdatedCustomAmountView_Previews: PreviewProvider {
    static var previews: some View {
        UpdatedCustomAmountView { amount in
            print("Preview: Selected amount \(amount)")
        }
        .environmentObject(KioskStore())
        .environmentObject(DonationViewModel())
        .environmentObject(SquareAuthService())
        .environmentObject(SquarePaymentService(authService: SquareAuthService(), catalogService: SquareCatalogService(authService: SquareAuthService())))
    }
}
