import SwiftUI
import SquareMobilePaymentsSDK

@main
struct DonationPadApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @StateObject private var authService = SquareAuthService()
    @StateObject private var subscriptionStore = StripeSubscriptionStore()
    @StateObject private var donationViewModel = DonationViewModel()
    @StateObject private var organizationStore = OrganizationStore()
    @StateObject private var kioskStore = KioskStore()
    
    @State private var catalogService: SquareCatalogService?
    @State private var paymentService: SquarePaymentService?
    @State private var readerService: SquareReaderService?
    @State private var permissionService: SquarePermissionService?
    
    @State private var isInitialized = false
    @State private var hasInjectedServices = false
    
    init() {
        setupBasicConfiguration()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(donationViewModel)
                .environmentObject(organizationStore)
                .environmentObject(kioskStore)
                .environmentObject(authService)
                .environmentObject(subscriptionStore)
                .environmentObject(catalogService ?? SquareCatalogService(authService: authService))
                .environmentObject(paymentService ?? SquarePaymentService(authService: authService, catalogService: catalogService ?? SquareCatalogService(authService: authService)))
                .environmentObject(readerService ?? SquareReaderService(authService: authService))
                .opacity(isInitialized ? 1.0 : 0.0)
                .animation(.easeInOut(duration: 0.5), value: isInitialized)
                .onAppear {
                    if !hasInjectedServices {
                        // ✅ FIXED: Inject services after SwiftUI initialization
                        injectServices()
                        hasInjectedServices = true
                    }
                    
                    if !isInitialized {
                        initializeServicesAsync()
                    }
                }
                .onOpenURL { url in
                    if url.host == "subscription-success" {
                        // Immediately check subscription status
                        subscriptionStore.checkSubscriptionStatus()
                    }
                }
        }
    }
    
    private func setupBasicConfiguration() {
        SquareConfig.setDefaultConfiguration()
        registerDefaultSettings()
        
        // ✅ REMOVED: Don't access StateObjects during init
        // Service injection moved to onAppear
    }
    
    private func injectServices() {
        // ✅ FIXED: Set organization ID instead of auth service
        // The subscription store needs the merchant ID as organization ID
        if let merchantId = authService.merchantId {
            subscriptionStore.setOrganizationId(merchantId)
            print("✅ Organization ID set in subscription store: \(merchantId)")
        } else {
            print("⚠️ No merchant ID available yet for subscription store")
        }
    }
    
    private func registerDefaultSettings() {
        let defaults: [String: Any] = [
            "hasCompletedOnboarding": false,
            "isInAdminMode": false,
        ]
        UserDefaults.standard.register(defaults: defaults)
    }
    
    private func initializeServicesAsync() {
        Task {
            await performHeavyInitialization()
            
            await MainActor.run {
                self.isInitialized = true
            }
        }
    }
    
    @MainActor
    private func performHeavyInitialization() async {
        let catalog = SquareCatalogService(authService: authService)
        let payment = SquarePaymentService(authService: authService, catalogService: catalog)
        let reader = SquareReaderService(authService: authService)
        let permission = SquarePermissionService()
        
        permission.configure(with: payment)
        payment.setReaderService(reader)
        payment.setKioskStore(kioskStore)
        reader.configure(with: payment, permissionService: permission)
        kioskStore.connectCatalogService(catalog)
        
        self.catalogService = catalog
        self.paymentService = payment
        self.readerService = reader
        self.permissionService = permission
        
        await loadConfigurationAsync()
        
        if authService.hasLocalTokens() {
            authService.checkAuthentication()
            
            // Set organization ID after authentication check
            if let merchantId = authService.merchantId {
                subscriptionStore.setOrganizationId(merchantId)
            }
        }
    }
    
    private func loadConfigurationAsync() async {
        await withCheckedContinuation { continuation in
            SquareConfig.loadConfiguration { success in
                continuation.resume()
            }
        }
    }
}
