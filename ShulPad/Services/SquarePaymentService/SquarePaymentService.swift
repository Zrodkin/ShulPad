import Foundation
import SwiftUI
import SquareMobilePaymentsSDK

/// Enhanced payment service that uses Square's order system for all payments
class SquarePaymentService: NSObject, ObservableObject {
    // MARK: - Published Properties
    
    @Published var isProcessingPayment = false
    @Published var paymentError: String? = nil
    @Published var isReaderConnected = false
    @Published var connectionStatus: String = "Disconnected"
    
    // Payment methods support flags
    @Published var supportsContactless = false
    @Published var supportsChip = false
    @Published var supportsSwipe = false
    @Published var supportsOfflinePayments = false
    @Published var hasAvailablePaymentMethods = false
    @Published var offlinePendingCount = 0
    
    // Order tracking
    @Published var currentOrderId: String? = nil
    
    // MARK: - Services
    
    private let authService: SquareAuthService
    private let sdkInitializationService: SquareSDKInitializationService
    private let permissionService: SquarePermissionService
    private let offlinePaymentService: SquareOfflinePaymentService
    private let catalogService: SquareCatalogService
    
    // MARK: - Private Properties
    
    private var readerService: SquareReaderService?
    private var kioskStore: KioskStore? // Add KioskStore dependency
    private var paymentHandle: PaymentHandle?
    private let idempotencyKeyManager = IdempotencyKeyManager()
    
    // Completion handlers
    private var mainPaymentCompletion: ((Bool, String?) -> Void)?
    
    // MARK: - Initialization
    
    init(authService: SquareAuthService, catalogService: SquareCatalogService) {
        self.authService = authService
        self.catalogService = catalogService
        
        // Initialize services
        self.sdkInitializationService = SquareSDKInitializationService()
        self.permissionService = SquarePermissionService()
        self.offlinePaymentService = SquareOfflinePaymentService()
        
        super.init()
        
        authService.setPaymentService(self)
        
        // Configure services with dependencies
        self.sdkInitializationService.configure(with: authService, paymentService: self)
        self.permissionService.configure(with: self)
        self.offlinePaymentService.configure(with: self)
        
        // Register for authentication success notification
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAuthenticationSuccess(_:)),
            name: .squareAuthenticationSuccessful,
            object: nil
        )
        // Start maintenance after a delay to ensure everything is initialized
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.startIdempotencyKeyMaintenance()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Public Methods
    
    /// Check if the SDK is authorized
    func isSDKAuthorized() -> Bool {
        return sdkInitializationService.isSDKAuthorized()
    }
    
    /// Initialize the Square SDK
    func initializeSDK() {
        sdkInitializationService.initializeSDK()
    }
    
    /// Connect to a Square reader
    func connectToReader() {
        // Use the injected reader service if available
        readerService?.connectToReader()
    }
    
    /// Set the reader service and configure it
    func setReaderService(_ readerService: SquareReaderService) {
        self.readerService = readerService
        // Configure the reader service with this payment service and permission service
        readerService.configure(with: self, permissionService: permissionService)
    }
    
    /// Set the kiosk store dependency
    func setKioskStore(_ kioskStore: KioskStore) {
        self.kioskStore = kioskStore
    }
    
    /// Deauthorize the Square SDK
    func deauthorizeSDK(completion: @escaping () -> Void = {}) {
        sdkInitializationService.deauthorizeSDK(completion: completion)
    }
    
    // In init() or when payment service starts
    func startIdempotencyKeyMaintenance() {
        // Clean up on start
        idempotencyKeyManager.cleanupExpiredKeys()
        
        // Clean up daily
        Timer.scheduledTimer(withTimeInterval: 86400, repeats: true) { [weak self] _ in
            self?.idempotencyKeyManager.cleanupExpiredKeys()
        }
    }
    
    // MARK: - Square's Built-in Reader Management
    
    /// Present Square's built-in reader management UI
    func presentSquareReaderSettings() {
        guard isSDKAuthorized() else {
            DispatchQueue.main.async {
                self.paymentError = "Please connect to Square first"
            }
            return
        }
        
        guard let windowScene = UIApplication.shared.connectedScenes
            .filter({ $0.activationState == .foregroundActive })
            .compactMap({ $0 as? UIWindowScene })
            .first,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            print("Could not find root view controller")
            return
        }

        var topController = rootViewController
        while let presented = topController.presentedViewController {
            topController = presented
        }

        print("🎛️ Presenting Square's built-in reader settings...")
        
        MobilePaymentsSDK.shared.settingsManager.presentSettings(
            with: topController,
            completion: { [weak self] _ in
                print("✅ Square settings dismissed")
                DispatchQueue.main.async {
                    self?.checkReaderStatus()
                }
            }
        )
    }
    
    /// Check reader status using Square's built-in management
    func checkReaderStatus() {
        print("🔌 Checking reader connection via Square SDK...")
        
        guard isSDKAuthorized() else {
            DispatchQueue.main.async {
                self.connectionStatus = "Not authorized with Square"
                self.isReaderConnected = false
            }
            return
        }
        
        let availableReaders = MobilePaymentsSDK.shared.readerManager.readers
        let readyReaders = availableReaders.filter { $0.state == .ready }
        
        // ADD THIS: Debug what we actually found
        print("🔍 Found \(availableReaders.count) total readers, \(readyReaders.count) ready")
        for reader in availableReaders {
            print("   Reader: \(reader.serialNumber ?? "unknown") - State: \(reader.state)")
        }
        
        DispatchQueue.main.async {
            if readyReaders.isEmpty {
                self.connectionStatus = "No readers connected. Use 'Manage Readers' to pair a reader."
                self.isReaderConnected = false
            } else {
                let readerName = readyReaders.first?.model == .stand ? "Square Stand" : "Square Reader"
                self.connectionStatus = "Connected to \(readerName)"
                self.isReaderConnected = true
                self.paymentError = nil
            }
            
            self.updateAvailablePaymentMethods()
        }
    }
    
    
    
    // MARK: - UNIFIED Payment Processing (Order-Based)
    
    /// Process payment using Square's order system
    /// This is the ONLY payment method - all payments go through Square orders
    func processPayment(
        amount: Double,
        orderId: String? = nil,
        isCustomAmount: Bool = false,
        catalogItemId: String? = nil,
        allowOffline: Bool = true,
        completion: @escaping (Bool, String?) -> Void
    ) {
        print("🚀 Starting Square payment processing")
        print("💰 Amount: $\(amount)")
        print("🛒 Order ID: \(orderId ?? "Will be created")")
        print("📦 Custom Amount: \(isCustomAmount)")
        
        // Step 1: Validate prerequisites
        guard validatePaymentPrerequisites(completion: completion) else { return }
        
        // Step 2: Check for ready readers
        guard hasReadyReader() else {
            DispatchQueue.main.async { [weak self] in
                self?.paymentError = "No card reader ready. Please check reader connection in settings."
                completion(false, nil)
            }
            return
        }
        
        // Step 3: Create order if not provided
        if let existingOrderId = orderId {
            startPaymentWithOrder(orderId: existingOrderId, amount: amount, allowOffline: allowOffline, completion: completion)
        } else {
            createOrderThenProcessPayment(amount: amount, isCustomAmount: isCustomAmount, catalogItemId: catalogItemId, allowOffline: allowOffline, completion: completion)
        }
    }
    
    // MARK: - Private Payment Helper Methods
    
    private func validatePaymentPrerequisites(completion: @escaping (Bool, String?) -> Void) -> Bool {
        // Ensure SDK is initialized
        guard MobilePaymentsSDK.shared.authorizationManager.state == .authorized else {
            DispatchQueue.main.async { [weak self] in
                self?.paymentError = "Square SDK not initialized"
                completion(false, nil)
            }
            return false
        }
        
        // Verify authentication
        guard authService.isAuthenticated else {
            DispatchQueue.main.async { [weak self] in
                self?.paymentError = "Not authenticated with Square"
                completion(false, nil)
            }
            return false
        }
        
        // Ensure SDK is authorized
        guard MobilePaymentsSDK.shared.authorizationManager.state == .authorized else {
            DispatchQueue.main.async { [weak self] in
                self?.initializeSDK()
                self?.paymentError = "SDK not authorized"
                completion(false, nil)
            }
            return false
        }
        
        return true
    }
    
    private func hasReadyReader() -> Bool {
        let readers = MobilePaymentsSDK.shared.readerManager.readers
        let readyReaders = readers.filter { $0.state == .ready }
        
        print("🔍 Reader Check:")
        print("   Total readers: \(readers.count)")
        print("   Ready readers: \(readyReaders.count)")
        
        for reader in readers {
            print("   Reader: \(reader.name)")
            print("     State: \(reader.state)")
            print("     Connection: \(reader.connectionInfo.state)")
            if let failure = reader.connectionInfo.failureInfo {
                print("     Failure: \(failure)")
            }
        }
        
        return !readyReaders.isEmpty
    }
    
    private func createOrderThenProcessPayment(
        amount: Double,
        isCustomAmount: Bool,
        catalogItemId: String?,
        allowOffline: Bool,
        completion: @escaping (Bool, String?) -> Void
    ) {
        print("📝 Creating order before payment...")
        
        // Use the injected KioskStore to create the order
        guard let kioskStore = self.kioskStore else {
            DispatchQueue.main.async { [weak self] in
                self?.paymentError = "Unable to create order - kiosk service not available"
                completion(false, nil)
            }
            return
        }
        
        kioskStore.createDonationOrder(amount: amount, isCustomAmount: isCustomAmount) { [weak self] orderId, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.paymentError = "Failed to create order: \(error.localizedDescription)"
                    completion(false, nil)
                    return
                }
                
                guard let orderId = orderId else {
                    self?.paymentError = "No order ID received"
                    completion(false, nil)
                    return
                }
                
                print("✅ Order created: \(orderId)")
                // Now process payment with the created order
                self?.startPaymentWithOrder(orderId: orderId, amount: amount, allowOffline: allowOffline, completion: completion)
            }
        }
    }
    
    private func startPaymentWithOrder(
        orderId: String,
        amount: Double,
        allowOffline: Bool,
        completion: @escaping (Bool, String?) -> Void
    ) {
        DispatchQueue.main.async { [weak self] in
            self?.isProcessingPayment = true
            self?.paymentError = nil
            self?.currentOrderId = orderId
        }
        
        let amountInCents = UInt(amount * 100)
        
        guard let presentedVC = getTopViewController() else {
            DispatchQueue.main.async { [weak self] in
                self?.isProcessingPayment = false
                self?.paymentError = "Unable to find view controller to present payment UI"
                completion(false, nil)
            }
            return
        }
        
        // Generate transaction ID and idempotency key
        let transactionId = "txn_\(String(orderId.suffix(8)))_\(Int(Date().timeIntervalSince1970))"
        let idempotencyKey = idempotencyKeyManager.getKey(for: transactionId) ?? {
            let newKey = UUID().uuidString
            idempotencyKeyManager.store(id: transactionId, idempotencyKey: newKey)
            return newKey
        }()
        
        // Determine processing mode
        let processingMode: ProcessingMode = (allowOffline && supportsOfflinePayments) ? .autoDetect : .onlineOnly
        
        // Create payment parameters with order integration
        let paymentParameters = PaymentParameters(
            idempotencyKey: idempotencyKey,
            amountMoney: Money(amount: amountInCents, currency: .USD),
            processingMode: processingMode
        )
        
        // Set the order ID - this is the key to Square's order system
        paymentParameters.orderID = orderId
        paymentParameters.referenceID = "donation_\(transactionId)"
        paymentParameters.note = "Donation via CharityPad"
        
        print("📋 Payment Parameters:")
        print("   💳 Amount: \(amountInCents) cents")
        print("   🛒 Order ID: \(orderId)")
        print("   🔑 Idempotency Key: \(idempotencyKey)")
        print("   📱 Processing Mode: \(processingMode)")
        
        // Create prompt parameters - NO manual card entry
        let promptParameters = PromptParameters(
            mode: .default,
            additionalMethods: AdditionalPaymentMethods()  // Empty = hardware readers only
        )
        
        // Store completion for delegate
        mainPaymentCompletion = completion
        
        // Start the payment
        print("🚀 Starting Square payment with order integration...")
        paymentHandle = MobilePaymentsSDK.shared.paymentManager.startPayment(
            paymentParameters,
            promptParameters: promptParameters,
            from: presentedVC,
            delegate: self
        )
    }
    
    // MARK: - Helper Methods
    
    private func updateAvailablePaymentMethods() {
        guard isSDKAuthorized() else { return }
        
        let _ = MobilePaymentsSDK.shared.paymentManager.availableCardInputMethods  // Silences warning
        
        DispatchQueue.main.async {
            self.hasAvailablePaymentMethods = true
            print("💳 Available payment methods updated")
        }
    }
    
    private func getTopViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes
            .filter({ $0.activationState == .foregroundActive })
            .compactMap({ $0 as? UIWindowScene })
            .first,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return nil
        }
        
        var topController = rootViewController
        while let presented = topController.presentedViewController {
            topController = presented
        }
        
        return topController
    }
    
    @objc private func handleAuthenticationSuccess(_ notification: Notification) {
          DispatchQueue.main.async {
              self.initializeSDK()
          }
      }
      
      // MARK: - Health Check Methods
      
      /// Check if payment system is fully healthy
      func performHealthCheck() {
          print("🏥 Performing payment system health check...")
          
          guard authService.isAuthenticated else {
              print("🚨 Health check: Not authenticated")
              return
          }
          
          // Check SDK authorization
          if !isSDKAuthorized() {
              print("🚨 Health check failed: SDK not authorized despite being authenticated")
              authService.forceCompleteLogout()
              return
          }
          
          // Check if we can at least attempt reader operations
          if !canAttemptReaderOperations() {
              print("🚨 Health check failed: Cannot perform reader operations")
              authService.forceCompleteLogout()
              return
          }
          
          print("✅ Payment system health check passed")
      }
      
      /// Check if we can attempt reader operations
      private func canAttemptReaderOperations() -> Bool {
          // At minimum, we should be able to access Square's reader management
          return isSDKAuthorized() && authService.locationId != nil
      }
      
      /// Schedule regular health checks
      func startHealthCheckMonitoring() {
          // Check health every 30 seconds when app is active
          Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
              self?.performHealthCheck()
          }
      }
  }

// MARK: - PaymentManagerDelegate Implementation

extension SquarePaymentService: PaymentManagerDelegate {
    
    func paymentManager(_ paymentManager: PaymentManager, didStart payment: Payment) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            print("Payment started with ID: \(String(describing: payment.id))")
            
            self.isProcessingPayment = true
            self.paymentError = nil
            self.connectionStatus = "Processing payment..."
        }
    }
    
    func paymentManager(_ paymentManager: PaymentManager, didFinish payment: Payment) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.isProcessingPayment = false
            self.paymentError = nil
            self.connectionStatus = "Payment completed"
            
            print("✅ Payment successful with ID: \(String(describing: payment.id))")
            
            // Handle successful completion
            self.mainPaymentCompletion?(true, payment.id)
            self.mainPaymentCompletion = nil
            
            // ADD THIS LINE:
            self.idempotencyKeyManager.cleanupExpiredKeys()
        }
    }
    
    func paymentManager(_ paymentManager: PaymentManager, didCancel payment: Payment) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.isProcessingPayment = false
            self.paymentError = nil // Don't set this as an error
            self.connectionStatus = "Payment cancelled"
            
            print("🚫 Payment was cancelled by user")
            
            // Handle cancellation - return false for success, nil for transaction ID
            self.mainPaymentCompletion?(false, nil)
            self.mainPaymentCompletion = nil
        }
    }
    
    func paymentManager(_ paymentManager: PaymentManager, didFail payment: Payment, withError error: Error) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.isProcessingPayment = false
            self.paymentError = "Payment failed: \(error.localizedDescription)"
            self.connectionStatus = "Payment failed"
            
            print("❌ Payment failed: \(error.localizedDescription)")
            
            // Handle failure
            self.mainPaymentCompletion?(false, nil)
            self.mainPaymentCompletion = nil
        }
    }
    
    // Optional methods
    func paymentManager(_ paymentManager: PaymentManager, willCancel payment: Payment) {
        print("Payment will cancel - preparing UI")
    }
    
    func paymentManager(_ paymentManager: PaymentManager, willFinish payment: Payment) {
        print("Payment will finish - preparing UI")
    }
}
