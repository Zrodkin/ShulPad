import SwiftUI
struct ContentView: View {
    // Add a state variable to force refreshes
    @State private var refreshTrigger = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @AppStorage("isInAdminMode") private var isInAdminMode: Bool = false  // CHANGED: Default to false
    @EnvironmentObject private var donationViewModel: DonationViewModel
    @EnvironmentObject private var organizationStore: OrganizationStore
    @EnvironmentObject private var kioskStore: KioskStore
    @EnvironmentObject private var squareAuthService: SquareAuthService
    @EnvironmentObject private var squarePaymentService: SquarePaymentService
    
    var body: some View {
        Group {
            // FIXED: Check onboarding FIRST, before anything else
            if !hasCompletedOnboarding {
                OnboardingView()
                    .environmentObject(organizationStore)
                    .environmentObject(kioskStore)
                    .environmentObject(donationViewModel)
                    .environmentObject(squareAuthService)
                    .onAppear {
                        // Reset any other state when showing onboarding
                        resetAppState()
                    }
            } else if isInAdminMode {
                AdminDashboardView()
                    .environmentObject(organizationStore)
                    .environmentObject(kioskStore)
                    .environmentObject(donationViewModel)
                    .environmentObject(squareAuthService)
            } else {
                // 🆕 NEW: Handle kiosk mode routing at the top level with admin access
                kioskModeView
                    .adminAccess() // ← Add this line
            }
        }
        // Add this to force UI refresh when needed
        .id("main-content-\(refreshTrigger)")
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ForceViewRefresh"))) { _ in
            // Force view refresh by toggling the trigger
            refreshTrigger.toggle()
        }
        .onAppear {
            // 🚀 OPTIMIZED: Fast startup with delayed heavy operations
            performOptimizedStartup()
        }
        // Add listener for authentication state changes
        .onChange(of: squareAuthService.isAuthenticated) { _, isAuthenticated in
            // 🔧 FIX: Don't react to auth changes during explicit logout
            if squareAuthService.isExplicitlyLoggingOut {
                print("🚫 Ignoring auth state change during explicit logout")
                return
            }
            
            if isAuthenticated {
                // Initialize the SDK when authentication state changes to authenticated
                squarePaymentService.initializeSDK()
            }
            // Let the proper logout flow in AdminDashboardView handle logout instead
        }
        // NEW: Listen for forced logout notifications
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ForceReturnToOnboarding"))) { _ in
            print("🚨 Received force logout notification - returning to onboarding")
            hasCompletedOnboarding = false
            isInAdminMode = false
        }
    }
    
    // 🆕 NEW: Kiosk mode view that decides between Home and DonationSelection
    private var kioskModeView: some View {
        Group {
            if kioskStore.homePageEnabled {
                // Show full HomeView when home page is enabled
                HomeView()
                    .environmentObject(donationViewModel)
                    .environmentObject(kioskStore)
                    .environmentObject(squareAuthService)
            } else {
                // Show DonationSelectionView directly when home page is disabled
                // This gives it proper navigation context and layout
                NavigationStack {
                    DonationSelectionView()
                        .onAppear {
                            donationViewModel.resetDonation()
                        }
                }
            }
        }
    }
    
    // 🚀 NEW: Optimized startup sequence
    private func performOptimizedStartup() {
        print("🚀 Starting optimized app startup...")
        
        // IMMEDIATE: Only essential checks that don't block UI
        guard !squareAuthService.isExplicitlyLoggingOut else {
            print("🚫 Skipping startup - logout in progress")
            return
        }
        
        // IMMEDIATE: Fast state consistency check
        ensureStateConsistency()
        
        // DELAYED: Heavy operations with staggered timing
        scheduleHeavyOperations()
    }
    
    private func scheduleHeavyOperations() {
        // Stage 1: Quick auth check (only if we have local tokens) - 0.3s delay
        Task {
            do {
                try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                await MainActor.run {
                    performQuickAuthCheck()
                }
            } catch {
                print("⚠️ Task cancelled during auth check delay")
            }
        }
        
        // Stage 2: SDK initialization - 1s delay
        Task {
            do {
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                await MainActor.run {
                    initializeSDKIfNeeded()
                }
            } catch {
                print("⚠️ Task cancelled during SDK init delay")
            }
        }
        
        // Stage 3: Health monitoring - 2s delay
        Task {
            do {
                try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                await MainActor.run {
                    startHealthMonitoring()
                }
            } catch {
                print("⚠️ Task cancelled during health monitoring delay")
            }
        }
        
        // Stage 4: Full health check - 3s delay
        Task {
            do {
                try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
                await MainActor.run {
                    performFullHealthCheck()
                }
            } catch {
                print("⚠️ Task cancelled during health check delay")
            }
        }
    }
    
    private func performQuickAuthCheck() {
        // Only check auth if we have local tokens (fast local check)
        if squareAuthService.hasLocalTokens() {
            print("🔐 Quick auth check with local tokens...")
            squareAuthService.checkAuthentication()
        } else {
            print("🔐 No local tokens - skipping auth check")
        }
    }
    
    private func initializeSDKIfNeeded() {
        if squareAuthService.isAuthenticated && !squareAuthService.isExplicitlyLoggingOut {
            print("🔧 Initializing Square SDK...")
            squarePaymentService.initializeSDK()
        }
    }
    
    private func startHealthMonitoring() {
        print("🏥 Starting health check monitoring...")
        squarePaymentService.startHealthCheckMonitoring()
    }
    
    private func performFullHealthCheck() {
        if squareAuthService.isAuthenticated && !squareAuthService.isExplicitlyLoggingOut {
            print("🏥 Performing full health check...")
            squarePaymentService.performHealthCheck()
        }
    }
    
    // NEW: Ensure app state is consistent on startup
    private func ensureStateConsistency() {
        print("🔧 Checking app state consistency...")
        print("📱 hasCompletedOnboarding: \(hasCompletedOnboarding)")
        print("📱 isInAdminMode: \(isInAdminMode)")
        print("📱 squareAuthService.isAuthenticated: \(squareAuthService.isAuthenticated)")
        
        // If not onboarded, force admin mode off
        if !hasCompletedOnboarding {
            print("🔧 App not onboarded - resetting admin mode to false")
            isInAdminMode = false
            return
        }
        
        print("✅ App state consistency check passed")
    }
    
    // Add a function to reset app state when needed
    private func resetAppState() {
        // Reset any in-memory state that might be causing issues
        // This runs when returning to onboarding/login screen
        squareAuthService.authError = nil
        squareAuthService.isAuthenticating = false
        
        // Reset donation state
        donationViewModel.resetDonation()
        
        // Ensure in-memory state is clean for a fresh start
        print("App state reset for fresh onboarding")
    }
}
// MARK: - Extension for SquareAuthService (add this method if it doesn't exist)
extension SquareAuthService {
    func hasLocalTokens() -> Bool {
        // Add this method to your SquareAuthService if it doesn't exist
        return accessToken != nil && tokenExpirationDate != nil
    }
}
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        let authService = SquareAuthService()
        let catalogService = SquareCatalogService(authService: authService)
        
        return ContentView()
            .environmentObject(DonationViewModel())
            .environmentObject(OrganizationStore())
            .environmentObject(KioskStore())
            .environmentObject(authService)
            .environmentObject(catalogService)
            .environmentObject(SquarePaymentService(authService: authService, catalogService: catalogService))
    }
}

