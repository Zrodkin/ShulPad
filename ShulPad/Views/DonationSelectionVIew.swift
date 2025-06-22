import SwiftUI

struct DonationSelectionView: View {
    @EnvironmentObject var kioskStore: KioskStore
    @EnvironmentObject var donationViewModel: DonationViewModel
    @EnvironmentObject var squareAuthService: SquareAuthService
    @EnvironmentObject var catalogService: SquareCatalogService
    @EnvironmentObject var paymentService: SquarePaymentService
    @EnvironmentObject private var organizationStore: OrganizationStore
    
    
    @State private var navigateToCustomAmount = false
    @State private var navigateToCheckout = false
    @State private var navigateToHome = false
    
    @State private var timeoutTimer: Timer?
    
    // Payment processing states.onAppear
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
    
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            backgroundImageView
            
            Color.black.opacity(0.55)
                .edgesIgnoringSafeArea(.all)
            
            // CONSISTENT: Same layout structure as HomeView
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: KioskLayoutConstants.topContentOffset)
                
                // Title
                Text("Donation Amount")
                    .font(.system(size: horizontalSizeClass == .regular ? KioskLayoutConstants.titleFontSize : KioskLayoutConstants.titleFontSizeCompact, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                    .frame(height: KioskLayoutConstants.titleBottomSpacing)
                
    
                // Content area - buttons
                VStack(spacing: KioskLayoutConstants.buttonSpacing) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: KioskLayoutConstants.buttonSpacing), count: 3), spacing: KioskLayoutConstants.buttonSpacing) {
                        ForEach(0..<kioskStore.presetDonations.count, id: \.self) { index in
                            presetAmountButton(for: index)
                        }
                    }
                    
                    if kioskStore.allowCustomAmount {
                        customAmountButton
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
        .navigationBarTitleDisplayMode(.inline)
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
            if squareAuthService.isAuthenticated {
                kioskStore.connectCatalogService(catalogService)
                kioskStore.loadPresetDonationsFromCatalog()
            }
            updateDonationViewModel()
            
            // Connect to reader if not already connected
            if !paymentService.isReaderConnected {
                paymentService.connectToReader()
            }
            startTimeout()
        }
        .navigationDestination(isPresented: $navigateToCustomAmount) {
            UpdatedCustomAmountView { amount in
                // This callback is no longer used since payments are processed directly
                // in UpdatedCustomAmountView
            }
        }
        .navigationDestination(isPresented: $navigateToHome) {
            // Only navigate to HomeView if home page is enabled
            // When disabled, handleNavigateToHome() should reset state instead of setting navigateToHome = true
            HomeView()
                .navigationBarBackButtonHidden(true)
        }
        .alert(isPresented: $showReceiptErrorAlert) {
            Alert(
                title: Text("Receipt Error"),
                message: Text(receiptErrorAlertMessage ?? "An unknown error occurred."),
                dismissButton: .default(Text("OK"))
            )
        }
        .sheet(isPresented: $showingSquareAuth) {
            SquareAuthorizationView()
        }
        .onReceive(paymentService.$isProcessingPayment) { processing in
            if !processing && isProcessingPayment {
                print("🔄 Payment processing state changed to: \(processing)")
            }
        }
        .onDisappear {
            timeoutTimer?.invalidate()
            timeoutTimer = nil
        }
        .onTapGesture {
            resetTimeout()
        }
        .contentShape(Rectangle())
    }

    // MARK: - Computed Properties (unchanged)
    
    private var backgroundImageView: some View {
        Group {
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
        }
    }
    
    private var customAmountButton: some View {
        Button(action: {
            handleCustomAmountButtonPress()
        }) {
            Text("Custom Amount")
                .font(.system(size: horizontalSizeClass == .regular ? KioskLayoutConstants.buttonFontSize : KioskLayoutConstants.buttonFontSizeCompact, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: horizontalSizeClass == .regular ? KioskLayoutConstants.buttonHeight : KioskLayoutConstants.buttonHeightCompact)
                .background(Color.white.opacity(0.3))
                .cornerRadius(15)
        }
        
    }
    
    private func handleCustomAmountButtonPress() {
        resetTimeout()
        donationViewModel.isCustomAmount = true
        navigateToCustomAmount = true
    }
    
    // Payment processing overlay (unchanged)
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
    
    // Thank you overlay (unchanged)
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
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                if showingThankYou {
                    handleSuccessfulCompletion()
                }
            }
        }
    }
    
    // Receipt prompt overlay - FIXED
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
                        
                        // Text/SMS receipt button
                        Button(action: {
                            // TODO: Add text receipt logic later
                            print("Text receipt selected - logic not implemented yet")
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "message.fill")
                                    .font(.system(size: 18))
                                Text("Text receipt")
                                    .font(.headline)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.green)
                            .cornerRadius(12)
                        }
                        
                        // No Receipt button
                        Button(action: {
                            showingReceiptPrompt = false
                            showingThankYou = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                if showingThankYou {
                                    handleSuccessfulCompletion()
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
                        // FIXED: Send Receipt button
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
                        
                        // FIXED: Back button
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
    
    private func presetAmountButton(for index: Int) -> some View {
        let amount = Double(kioskStore.presetDonations[index].amount) ?? 0
        
        return Button(action: {
            resetTimeout()
            // Process payment immediately instead of navigating to checkout
            handlePresetAmountSelection(amount: amount)
        }) {
            ZStack {
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color.white.opacity(0.3))
                
                Text("$\(Int(amount))")
                    .font(.system(size: horizontalSizeClass == .regular ? KioskLayoutConstants.buttonFontSize : KioskLayoutConstants.buttonFontSizeCompact, weight: .semibold))
                    .foregroundColor(.white)
            }
            .frame(height: horizontalSizeClass == .regular ? KioskLayoutConstants.buttonHeight : KioskLayoutConstants.buttonHeightCompact)
        }
        .frame(maxWidth: .infinity)
    }
    
    // Process payment immediately for preset amounts
    private func handlePresetAmountSelection(amount: Double) {
        print("🚀 Preset amount selected: $\(amount) - processing immediately")
        
        donationViewModel.selectedAmount = amount
        donationViewModel.isCustomAmount = false
        
        // Process payment immediately
        processPayment(amount: amount, isCustomAmount: false)
    }
    
    
    private func handleCustomAmountSelection(amount: Double) {
        donationViewModel.selectedAmount = amount
        donationViewModel.isCustomAmount = true
        navigateToCheckout = true
    }
    
    private func handleCheckoutDismiss() {
        navigateToCheckout = false
        donationViewModel.resetDonation()
    }
    
    private func handleNavigateToHome() {
        print("🏠 Navigating to home from DonationSelectionView")
        
        // Reset all navigation states
        navigateToCheckout = false
        navigateToCustomAmount = false
        
        // Reset donation state
        donationViewModel.resetDonation()
        
        // Only navigate if home page is enabled, otherwise just reset state
        if kioskStore.homePageEnabled {
            navigateToHome = true
        } else {
            // We're already at the "home" view, just reset everything
            resetPaymentState()
            // Don't set navigateToHome = true
        }
    }
    
    // Process payment method (unchanged)
    private func processPayment(amount: Double, isCustomAmount: Bool) {
        timeoutTimer?.invalidate()
        // Check authentication
        if !squareAuthService.isAuthenticated {
            showingSquareAuth = true
            return
        }
        
        // Check reader connection - warn but allow to continue for graceful degradation
        if !paymentService.isReaderConnected {
            print("⚠️ No reader connected - will attempt to connect during payment")
            // Don't return here - let the payment service handle reader connection
        }
        
        resetPaymentState()
        isProcessingPayment = true
        
        print("🚀 Starting payment processing for amount: $\(amount)")
        print("💰 Is custom amount: \(isCustomAmount)")
        
        // Find catalog item ID if this is a preset amount
        var catalogItemId: String? = nil
        if !isCustomAmount {
            if let donation = kioskStore.presetDonations.first(where: { Double($0.amount) == amount }) {
                catalogItemId = donation.catalogItemId
                print("📋 Found catalog item ID: \(catalogItemId ?? "nil")")
            }
        }
        
        // Use the unified payment processing method from SquarePaymentService
        paymentService.processPayment(
            amount: amount,
            orderId: nil,
            isCustomAmount: isCustomAmount,
            catalogItemId: catalogItemId,
            allowOffline: true
        ) { success, transactionId in
            DispatchQueue.main.async {
                // Always reset processing state first
                self.isProcessingPayment = false
                
                if success {
                    print("✅ Payment Success: Recording donation and showing receipt prompt")
                    // Record the donation
                    self.donationViewModel.recordDonation(amount: amount, transactionId: transactionId)
                    self.orderId = self.paymentService.currentOrderId
                    self.paymentId = transactionId
                    
                    // Go directly to receipt prompt
                    self.showingReceiptPrompt = true
                } else {
                    print("❌ Payment Cancelled/Failed: Going back to previous screen")
                    self.handleSilentFailureOrCancellation()
                }
            }
        }
    }
    
    // Silent handling of payment failures/cancellations
    private func handleSilentFailureOrCancellation() {
        print("🔇 Payment failed or cancelled - silently navigating to home")
        
        // Clear any error state
        paymentService.paymentError = nil
        
        // Reset payment state
        resetPaymentState()
        
        // Navigate directly to home
        handleNavigateToHome()
    }
    
    private func handleSuccessfulCompletion() {
        resetPaymentState()
        donationViewModel.resetDonation()  // Clear donation state
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Only navigate if home page is enabled, otherwise just reset state
            if self.kioskStore.homePageEnabled {
                self.navigateToHome = true
            } else {
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
    
    // Email validation (unchanged)
    private func validateEmail(_ email: String) {
        let emailRegex = "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        isEmailValid = emailPredicate.evaluate(with: email)
    }
    
    // Send receipt (unchanged) - keeping the existing implementation
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
                handleSuccessfulCompletion()
            }
        }
    }
    
    // MARK: - Timeout Management

    private func startTimeout() {
        timeoutTimer?.invalidate()
        let timeoutSeconds = Double(kioskStore.timeoutDuration) ?? 10.0
        timeoutTimer = Timer.scheduledTimer(withTimeInterval: timeoutSeconds, repeats: false) { _ in
            // Use the same logic as handleSuccessfulCompletion
            if self.kioskStore.homePageEnabled {
                self.navigateToHome = true
            } else {
                // When home is disabled, timeout should just reset the view state
                self.resetPaymentState()
            }
        }
    }

    private func resetTimeout() {
        startTimeout()
    }
    
    private func updateDonationViewModel() {
        let amounts = kioskStore.presetDonations.compactMap { Double($0.amount) }
        if !amounts.isEmpty {
            donationViewModel.presetAmounts = amounts
        }
    }
}



struct DonationSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        DonationSelectionView()
            .environmentObject(KioskStore())
            .environmentObject(DonationViewModel())
            .environmentObject(SquareAuthService())
            .environmentObject(SquareCatalogService(authService: SquareAuthService()))
    }
}
