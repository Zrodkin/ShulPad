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
            
            // Add this after the main VStack but before the closing }
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
                // Your completion handler
            }
        }
        .navigationDestination(isPresented: $navigateToHome) {
            // Only navigate to HomeView if home page is enabled
            // When disabled, handleNavigateToHome() should reset state instead of setting navigateToHome = true
            HomeView()
                .navigationBarBackButtonHidden(true)
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
