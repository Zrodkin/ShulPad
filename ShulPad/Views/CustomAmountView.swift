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
            PaymentCheckoutOverlays(
                isProcessingPayment: $isProcessingPayment,
                showingThankYou: $showingThankYou,
                showingReceiptPrompt: $showingReceiptPrompt,
                showingEmailEntry: $showingEmailEntry,
                emailAddress: $emailAddress,
                isEmailValid: $isEmailValid,
                isSendingReceipt: $isSendingReceipt,
                orderId: $orderId,
                paymentId: $paymentId,
                receiptErrorAlertMessage: $receiptErrorAlertMessage,
                showReceiptErrorAlert: $showReceiptErrorAlert,
                onSuccessfulCompletion: handleSuccessfulCompletion,
                onResetTimeout: resetTimeout
            )
            
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
