import SwiftUI

struct AdminDashboardView: View {
    @State private var selectedTab: String? = nil
    @State private var showLogoutAlert = false
    @State private var isLoggingOut = false
    @State private var isProcessingLogout = false
    
    
    @AppStorage("isInAdminMode") private var isInAdminMode: Bool = true
    @EnvironmentObject private var organizationStore: OrganizationStore
    @EnvironmentObject private var kioskStore: KioskStore
    @EnvironmentObject private var donationViewModel: DonationViewModel
    @EnvironmentObject private var squareAuthService: SquareAuthService
    @EnvironmentObject private var squarePaymentService: SquarePaymentService
    @EnvironmentObject private var squareReaderService: SquareReaderService
    @EnvironmentObject private var subscriptionStore: SubscriptionStore
    
    var body: some View {
        NavigationSplitView {
            // Clean sidebar with modern styling
            VStack(spacing: 0) {
                // Organization header
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        // Organization logo or icon
                        ZStack {
                            Circle()
                                .fill(LinearGradient(
                                    colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.6)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                                .frame(width: 48, height: 48)
                            
                            Text(String(organizationStore.name.prefix(1).uppercased()))
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(organizationStore.name)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                            
                            Text("Admin Dashboard")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
                
                // Navigation list
                List(selection: $selectedTab) {
                    Section {
                        NavigationLink(value: "home") {
                            AdminNavItem(
                                icon: "house.fill",
                                title: "Home Page",
                                subtitle: "Customize appearance"
                            )
                        }
                        
                        NavigationLink(value: "presetAmounts") {
                            AdminNavItem(
                                icon: "dollarsign.circle.fill",
                                title: "Donation Amounts",
                                subtitle: "Set preset values"
                            )
                        }
                        
                        NavigationLink(value: "receipts") {
                            AdminNavItem(
                                icon: "envelope.fill",
                                title: "Email Receipts",
                                subtitle: "Organization details"
                            )
                        }
                        
                        NavigationLink(value: "timeout") {
                            AdminNavItem(
                                icon: "clock.fill",
                                title: "Timeout Settings",
                                subtitle: "Auto-reset duration"
                            )
                        }
                        
                        NavigationLink(value: "readers") {
                            AdminNavItem(
                                icon: "creditcard.fill",
                                title: "Card Readers",
                                subtitle: "Hardware management"
                            )
                        }
                        NavigationLink(value: "subscription") {
                            AdminNavItem(
                                icon: "creditcard.and.123",
                                title: "Subscription",
                                subtitle: "Manage billing & plan"
                            )
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                
                Spacer()
                
                // Connection status section
                VStack(spacing: 16) {
                    // Square connection status
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(squareAuthService.isAuthenticated ?
                                      Color.green.opacity(0.15) : Color.red.opacity(0.15))
                                .frame(width: 32, height: 32)
                            
                            Circle()
                                .fill(squareAuthService.isAuthenticated ? Color.green : Color.red)
                                .frame(width: 8, height: 8)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Square Integration")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text(squareAuthService.isAuthenticated ? "Connected" : "Disconnected")
                                .font(.caption)
                                .foregroundStyle(squareAuthService.isAuthenticated ? .green : .red)
                        }
                        
                        Spacer()
                    }
                    
                    // Reader status (only if Square is connected)
                    if squareAuthService.isAuthenticated {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(squarePaymentService.isReaderConnected ?
                                          Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                                    .frame(width: 32, height: 32)
                                
                                Image(systemName: "creditcard.trianglebadge.exclamationmark")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(squarePaymentService.isReaderConnected ? .green : .orange)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Card Reader")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                Text(squarePaymentService.connectionStatus)
                                    .font(.caption)
                                    .foregroundStyle(squarePaymentService.isReaderConnected ? .green : .orange)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.tertiarySystemBackground))
                )
                .padding(.horizontal, 16)
                
                // Action buttons
                VStack(spacing: 12) {
                    // Launch Kiosk button
                    Button(action: {
                        kioskStore.updateDonationViewModel(donationViewModel)
                        isInAdminMode = false
                    }) {
                        HStack {
                            Image(systemName: "play.circle.fill")
                                .font(.title3)
                            
                            Text("Launch Kiosk")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [Color.green, Color.green.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(!squareAuthService.isAuthenticated)
                    .opacity(squareAuthService.isAuthenticated ? 1.0 : 0.5)
                    
                    // 🔧 FIX 2: Improved logout button with state guards
                    Button(action: {
                        // Prevent double-taps and clicks while processing
                        guard !isProcessingLogout && !isLoggingOut else {
                            print("⚠️ Logout already in progress, ignoring tap")
                            return
                        }
                        
                        print("🔘 Logout button tapped")
                        showLogoutAlert = true
                    }) {
                        HStack {
                            Image(systemName: "arrow.right.square.fill")
                                .font(.title3)
                            
                            Text(isProcessingLogout ? "Processing..." : "Logout")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(.tertiarySystemBackground))
                        .foregroundStyle(.red)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .opacity(isProcessingLogout ? 0.6 : 1.0)
                    }
                    .disabled(isProcessingLogout || isLoggingOut) // 🔧 FIX 3: Disable while processing
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Color(.systemBackground))
            .navigationBarHidden(true)
            
        } detail: {
            // Clean detail view
            Group {
                if let selectedTab = selectedTab {
                    switch selectedTab {
                    case "home":
                        HomePageSettingsView().environmentObject(kioskStore)
                    case "presetAmounts":
                        PresetAmountsView().environmentObject(kioskStore)
                    case "receipts":
                        EmailReceiptsView().environmentObject(organizationStore)
                    case "timeout":
                        TimeoutSettingsView().environmentObject(kioskStore)
                    case "readers":
                        ReaderManagementView()
                            .environmentObject(squareAuthService)
                            .environmentObject(squareReaderService)
                    case "subscription":
                        SubscriptionManagementView()
                            .environmentObject(squareAuthService)
                    default:
                        EmptyDetailView()
                    }
                } else {
                    // Show Quick Setup card when no tab is selected
                    QuickSetupDetailView()
                }
            }
            .background(Color(.systemGroupedBackground))
        }
        // 🔧 FIX 4: Improved alert with proper state management
        .alert("Logout", isPresented: $showLogoutAlert) {
            Button("Cancel", role: .cancel) {
                print("🚫 Logout cancelled by user")
                showLogoutAlert = false
                isProcessingLogout = false
            }
            Button("Logout", role: .destructive) {
                print("✅ Logout confirmed by user")
                showLogoutAlert = false
                
                // 🔧 FIX 5: Set processing state immediately
                isProcessingLogout = true
                
                // 🔧 FIX 6: Use a longer delay to ensure alert dismissal
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    initiateLogoutProcess()
                }
            }
        } message: {
            Text("Are you sure you want to logout? You will need to authenticate again to access the admin panel.")
        }
        .overlay(
            Group {
                if isLoggingOut {
                    LogoutOverlay()
                }
            }
        )
        .onChange(of: squareAuthService.isAuthenticated) { _, newValue in
            if newValue {
                squarePaymentService.initializeSDK()
            }
        }
        .onAppear {
            if squareAuthService.isAuthenticated {
                squarePaymentService.initializeSDK()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .squareAuthenticationStatusChanged)) { _ in
            // Handle authentication status changes
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("LaunchKioskFromQuickSetup"))) { _ in
            print("🚀 Launching kiosk from quick setup")
            kioskStore.updateDonationViewModel(donationViewModel)
            isInAdminMode = false
        }
        .onReceive(NotificationCenter.default.publisher(for: .subscriptionActivated)) { _ in
            subscriptionStore.refreshSubscriptionStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: .refreshSubscriptionStatus)) { _ in
            subscriptionStore.refreshSubscriptionStatus()
        }
    }
    
    // MARK: - 🔧 FIX 7: Improved Logout Methods with Better Error Handling
    
    private func initiateLogoutProcess() {
            print("🔄 Starting logout process...")
            
            // 🔧 FIX: Notify that this is an explicit logout
            NotificationCenter.default.post(name: NSNotification.Name("ExplicitLogoutInitiated"), object: nil)
            
            // Ensure we're on main thread and not already logging out
            DispatchQueue.main.async {
                guard !self.isLoggingOut else {
                    print("⚠️ Already logging out, skipping duplicate request")
                    return
                }
                
                self.isLoggingOut = true
                self.isProcessingLogout = true
                
                // 🔧 FIX: Use Task for better async handling
                Task {
                    await self.performLogoutSequence()
                }
            }
        }
        
    @MainActor
    private func performLogoutSequence() async {
        print("🔄 Performing logout sequence...")
        
        // Step 1: FIRST clear local state to prevent re-authentication
        print("🧹 Clearing local state FIRST...")
        squareReaderService.stopMonitoring()
        donationViewModel.resetDonation()
        squareAuthService.clearLocalAuthData()  // This sets logout flags
        
        // Step 2: Update UI state immediately
        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
        self.isLoggingOut = false
        self.isProcessingLogout = false
        
        // Step 3: THEN try server disconnect (async, can fail)
        print("🌐 Attempting server disconnect...")
        squareAuthService.disconnectFromServer { success in
            print("🌐 Server disconnect result: \(success)")
            // Don't care if this fails - local logout already complete
        }
        
        // Step 4: THEN try SDK deauthorization (async, can fail)
        if squarePaymentService.isSDKAuthorized() {
            print("🔐 Deauthorizing Square SDK...")
            squarePaymentService.deauthorizeSDK {
                print("✅ SDK deauthorization complete")
                // 🔧 RESET logout flags after everything is done
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.squareAuthService.resetLogoutFlags()
                }
            }
        } else {
            // 🔧 RESET logout flags even if no SDK to deauthorize
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.squareAuthService.resetLogoutFlags()
            }
        }
        
        print("✅ Logout process complete!")
    }
    
    // 🔧 FIX 9: Fallback cleanup method (keeping original structure as backup)
    private func attemptServerDisconnect() {
        print("🌐 [FALLBACK] Attempting to disconnect from server...")
        squareAuthService.disconnectFromServer { serverDisconnectSuccess in
            print("🌐 [FALLBACK] Server disconnect result: \(serverDisconnectSuccess)")
            DispatchQueue.main.async {
                self.finalizeClientSideLogout()
            }
        }
    }
    
    private func finalizeClientSideLogout() {
        print("🧹 [FALLBACK] Finalizing client-side logout...")
        squareReaderService.stopMonitoring()
        donationViewModel.resetDonation()
        squareAuthService.clearLocalAuthData()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.isInAdminMode = true
            UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
            self.isLoggingOut = false
            self.isProcessingLogout = false
            print("✅ [FALLBACK] Logout process complete!")
        }
    }
}

// MARK: - Supporting Views (unchanged)

struct AdminNavItem: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.blue)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct EmptyDetailView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "sidebar.left")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.tertiary)
            
            Text("Select a setting")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
            
            Text("Choose an option from the sidebar to get started")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

struct LogoutOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.2)
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                
                VStack(spacing: 8) {
                    Text("Logging out...")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text("Cleaning up your session")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
            )
            .shadow(radius: 20)
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.3), value: true)
    }
}

struct QuickSetupDetailView: View {
    @State private var showingGuidedSetup = false
    
    var body: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "sparkles")
                    .font(.system(size: 64))
                    .foregroundColor(.blue.opacity(0.6))
                
                VStack(spacing: 12) {
                    Text("Welcome to Your Admin Dashboard")
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text("Get started quickly with our guided setup, or choose a specific setting from the sidebar to customize your donation kiosk.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 400)
                }
                
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
                .frame(maxWidth: 300)
            }
            
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .sheet(isPresented: $showingGuidedSetup) {
            GuidedSetupView()
        }
    }
}

// Preview
struct AdminDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        let authService = SquareAuthService()
        let catalogService = SquareCatalogService(authService: authService)
        let paymentService = SquarePaymentService(authService: authService, catalogService: catalogService)
        let readerService = SquareReaderService(authService: authService)

        return AdminDashboardView()
            .environmentObject(OrganizationStore())
            .environmentObject(KioskStore())
            .environmentObject(DonationViewModel())
            .environmentObject(authService)
            .environmentObject(catalogService)
            .environmentObject(paymentService)
            .environmentObject(readerService)
    }
}
