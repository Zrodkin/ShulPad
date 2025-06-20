import Foundation
import SquareMobilePaymentsSDK

/// Service responsible for Square SDK initialization and authorization with enhanced location debugging
class SquareSDKInitializationService: NSObject, AuthorizationStateObserver {
    // MARK: - Private Properties
    
    private weak var authService: SquareAuthService?
    private weak var paymentService: SquarePaymentService?
    private var isInitialized = false
    private var isAuthorizationInProgress = false
    // MARK: - Public Methods
    
    /// Configure the service with necessary dependencies
    func configure(with authService: SquareAuthService, paymentService: SquarePaymentService) {
        self.authService = authService
        self.paymentService = paymentService
    }
    
    /// Check if the Square SDK is initialized and ready to use
    func checkIfInitialized() -> Bool {
        if !isInitialized {
            // Mark as initialized
            isInitialized = true
            
            // Register as authorization observer
            MobilePaymentsSDK.shared.authorizationManager.add(self)
            
            print("Square SDK initialized and available")
        }
        
        return true
    }
    
    /// Debug function to print SDK information with enhanced location details
    func debugSquareSDK() {
        // Don't proceed if not initialized
        guard checkIfInitialized() else {
            print("Cannot debug Square SDK - not yet initialized")
            return
        }
        
        print("\n--- ENHANCED Square SDK Debug Information ---")
        
        // SDK version and environment
        print("SDK Version: \(String(describing: MobilePaymentsSDK.version))")
        print("SDK Environment: \(MobilePaymentsSDK.shared.settingsManager.sdkSettings.environment)")
        
        // Authorization state
        print("Authorization State: \(MobilePaymentsSDK.shared.authorizationManager.state)")
        
        // ENHANCED: Check current location info from SDK
        if let currentLocation = MobilePaymentsSDK.shared.authorizationManager.location {
            print("✅ SDK Current Location ID: \(currentLocation.id)")
            print("✅ SDK Current Location Name: \(currentLocation.name)")
            print("ℹ️ SDK Current Location Status: (Not available on Location protocol)")
            
            // Compare with what we have in AuthService
            if let authService = authService {
                print("\n--- Location Comparison ---")
                print("AuthService Location ID: \(authService.locationId ?? "NIL")")
                print("AuthService Merchant ID: \(authService.merchantId ?? "NIL")")
                
                if let authLocationId = authService.locationId {
                    if authLocationId == currentLocation.id {
                        print("✅ MATCH: SDK and AuthService have same location ID")
                    } else {
                        print("❌ MISMATCH: SDK location (\(currentLocation.id)) != AuthService location (\(authLocationId))")
                        print("🔧 SOLUTION: Need to re-authorize SDK with correct location")
                    }
                } else {
                    print("❌ PROBLEM: AuthService has no location ID stored")
                }
            }
        } else {
            print("❌ NO CURRENT LOCATION SET IN SDK")
            print("🔧 This is why readers can't connect - SDK needs location authorization")
            
            if let authService = authService {
                print("AuthService Location ID available: \(authService.locationId ?? "NIL")")
                if authService.locationId != nil {
                    print("🔧 SOLUTION: Use authService.locationId to authorize SDK")
                } else {
                    print("🔧 SOLUTION: Need to get location ID from OAuth flow")
                }
            }
        }
        
        // Reader information
        print("\n--- Reader Information ---")
        let readers = MobilePaymentsSDK.shared.readerManager.readers
        print("Found \(readers.count) readers")
        
        for (index, reader) in readers.enumerated() {
            print("Reader \(index + 1):")
            print("  Serial: \(reader.serialNumber ?? "unknown")")
            print("  Model: \(reader.model)")
            print("  State: \(reader.state)")
            
            if let batteryStatus = reader.batteryStatus {
                print("  Battery: \(batteryStatus.isCharging ? "Charging" : "Not charging")")
            }
        }
        
        print("\n--- Debug Complete ---")
    }
    
    /// Enhanced SDK initialization with proper location handling
    func initializeSDK(onSuccess: @escaping () -> Void = {}) {
        // Check if SDK is available first
        guard checkIfInitialized() else {
            updateConnectionStatus("SDK not initialized")
            return
        }
        
        guard !isAuthorizationInProgress else {
                  print("⚠️ SDK authorization is already in progress. Skipping duplicate call.")
                  return
              }
        
        print("🔍 ENHANCED DEBUG: Starting SDK initialization with location verification")
        
        // Get credentials from auth service
        guard let authService = authService,
              let accessToken = authService.accessToken else {
            updatePaymentError("No access token available")
            updateConnectionStatus("Missing access token")
            print("❌ CRITICAL: No access token available")
            return
        }
        
        // ✅ CRITICAL FIX: Verify we have a location ID
        guard let locationID = authService.locationId else {
            print("❌ CRITICAL: No location ID available for SDK authorization")
            print("❌ This explains why readers can't connect!")
            print("🔧 SOLUTION: User needs to complete OAuth flow with location selection")
            
            // Check if we need to re-authenticate to get location
            checkAndFixLocationIssue()
            return
        }
        
        print("✅ Found Location ID for SDK: \(locationID)")
        print("✅ Found Merchant ID: \(authService.merchantId ?? "unknown")")
        
        // Check if already authorized with the SAME location
        if MobilePaymentsSDK.shared.authorizationManager.state == .authorized {
            // Verify we're authorized with the correct location
            if let currentLocation = MobilePaymentsSDK.shared.authorizationManager.location {
                print("📍 Current SDK Location: \(currentLocation.id) (\(currentLocation.name))")
                print("📍 Expected Location: \(locationID)")
                
                if currentLocation.id == locationID {
                    print("✅ Square SDK already authorized with correct location!")
                    updateConnectionStatus("SDK authorized with \(currentLocation.name)")
                    onSuccess()
                    return
                } else {
                    print("⚠️ SDK authorized but with WRONG location!")
                    print("🔄 Re-authorizing with correct location...")
                    
                    // Deauthorize first, then re-authorize with correct location
                    MobilePaymentsSDK.shared.authorizationManager.deauthorize {
                        DispatchQueue.main.async {
                            self.performAuthorization(accessToken: accessToken, locationID: locationID, onSuccess: onSuccess)
                        }
                    }
                    return
                }
            } else {
                print("⚠️ SDK authorized but no location info - this shouldn't happen")
                // Re-authorize to be safe
                MobilePaymentsSDK.shared.authorizationManager.deauthorize {
                    DispatchQueue.main.async {
                        self.performAuthorization(accessToken: accessToken, locationID: locationID, onSuccess: onSuccess)
                    }
                }
                return
            }
        }
        
        // Perform the authorization
                isAuthorizationInProgress = true // 👈 SET FLAG
                performAuthorization(accessToken: accessToken, locationID: locationID, onSuccess: onSuccess)
            }

    // Enhanced helper method for authorization
    private func performAuthorization(accessToken: String, locationID: String, onSuccess: @escaping () -> Void) {
            print("🚀 Authorizing Square SDK with location ID: \(locationID)")
            
            // Show what we're about to do
            updateConnectionStatus("Authorizing SDK with location...")
            
            // Use correct method signature from Square documentation
            MobilePaymentsSDK.shared.authorizationManager.authorize(
                withAccessToken: accessToken,
                locationID: locationID
            ) { [weak self] error in
                defer {
                    DispatchQueue.main.async {
                        self?.isAuthorizationInProgress = false
                    }
                }
            

                guard let self = self else { return }
                
                DispatchQueue.main.async {
                if let authError = error {
                    let errorMessage = "SDK Authorization failed: \(authError.localizedDescription)"
                    print("❌ \(errorMessage)")
                    self.updatePaymentError(errorMessage)
                    self.updateConnectionStatus("Authorization failed")
                    
                    // Enhanced error diagnosis
                    print("🔍 Error diagnosis:")
                    print("  - Access token length: \(accessToken.count)")
                    print("  - Location ID: \(locationID)")
                    print("  - Error domain: \(authError.localizedDescription)")
                    
                    // Check if this is a location-related error
                    if authError.localizedDescription.contains("location") ||
                       authError.localizedDescription.contains("Location") ||
                       authError.localizedDescription.contains("invalid") {
                        self.updatePaymentError("Invalid location - please reconnect to Square and select the correct location")
                        print("❌ Location-specific error detected - OAuth flow may need location reselection")
                    }
                    return
                }
                
                // Success!
                let currentLocation = MobilePaymentsSDK.shared.authorizationManager.location
                print("✅ Square Mobile Payments SDK successfully authorized!")
                print("✅ Location ID: \(currentLocation?.id ?? "Unknown")")
                print("✅ Location Name: \(currentLocation?.name ?? "Unknown")")
                print("ℹ️ SDK Current Location Status: (Not available on Location protocol)")
                
                self.updateConnectionStatus("SDK authorized with \(currentLocation?.name ?? "location")")
                self.updatePaymentError(nil) // Clear any previous errors
                
                // Debug what we just accomplished
                self.debugSquareSDK()
                
                onSuccess()
            }
        }
    }
    
    /// NEW: Check and attempt to fix location issues
    private func checkAndFixLocationIssue() {
        print("🔧 Checking for location issues...")
        
        guard let authService = authService else {
            print("❌ No auth service available")
            return
        }
        
        // Check if we have other auth data but missing location
        if authService.accessToken != nil && authService.merchantId != nil && authService.locationId == nil {
            print("🔍 Found tokens but missing location ID")
            print("🔧 This suggests OAuth completed but location wasn't properly stored")
            print("🔧 SOLUTION: Re-check authentication status to get location")
            
            updateConnectionStatus("Re-checking location info...")
            
            // Re-check authentication to see if backend has location
            authService.checkAuthentication()
            
            // After check, try again in 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                if authService.locationId != nil {
                    print("✅ Location found after re-check, retrying SDK init")
                    self.initializeSDK()
                } else {
                    print("❌ Still no location after re-check")
                    self.updatePaymentError("Missing location info - please reconnect to Square")
                    self.updateConnectionStatus("Location required - please reconnect")
                }
            }
        } else if authService.accessToken == nil {
            print("❌ No access token - user needs to authenticate")
            updatePaymentError("Not connected to Square - please authenticate")
            updateConnectionStatus("Not authenticated")
        } else {
            print("❌ Unknown auth issue")
            updateConnectionStatus("Authentication issue")
        }
    }
    
    /// Check if the Square SDK is authorized
    func isSDKAuthorized() -> Bool {
        guard checkIfInitialized() else {
            print("❌ SDK not initialized")
            return false
        }
        
        let authState = MobilePaymentsSDK.shared.authorizationManager.state
        
        switch authState {
        case .authorized:
            // Verify we have location info
            if let location = MobilePaymentsSDK.shared.authorizationManager.location {
                print("✅ SDK authorized with location: \(location.name) (\(location.id))")
                return true
            } else {
                print("⚠️ SDK authorized but no location info")
                return false
            }
            
        case .authorizing:
            print("⏳ SDK still authorizing...")
            return false
            
        case .notAuthorized:
            print("❌ SDK not authorized")
            return false
            
        @unknown default:
            print("❓ Unknown SDK authorization state: \(authState)")
            return false
        }
    }

    // Add a method to handle SDK re-authorization during disruptions
    func handleSDKDisruption() {
        print("🔧 Handling SDK disruption - attempting re-authorization...")
        
        guard let authService = authService,
              let accessToken = authService.accessToken,
              let locationID = authService.locationId else {
            print("❌ Missing auth data for SDK re-authorization")
            return
        }
        
        // Deauthorize first
        MobilePaymentsSDK.shared.authorizationManager.deauthorize {
            DispatchQueue.main.async {
                print("🔄 Re-authorizing SDK after disruption...")
                self.performAuthorization(accessToken: accessToken, locationID: locationID) {
                    print("✅ SDK re-authorization completed")
                }
            }
        }
    }
    
    /// Deauthorize the Square SDK
    func deauthorizeSDK(completion: @escaping () -> Void = {}) {
        guard checkIfInitialized() else {
            completion()
            return
        }
        
        print("🔄 Deauthorizing Square SDK...")
        
        MobilePaymentsSDK.shared.authorizationManager.deauthorize {
            DispatchQueue.main.async { [weak self] in
                print("✅ Square SDK deauthorized")
                self?.updateConnectionStatus("Disconnected")
                
                // Update reader connected state
                if let paymentService = self?.paymentService {
                    paymentService.isReaderConnected = false
                }
                
                completion()
            }
        }
    }
    
    /// Get the currently available card input methods
    func availableCardInputMethods() -> CardInputMethods {
        guard checkIfInitialized() else { return CardInputMethods() }
        return MobilePaymentsSDK.shared.paymentManager.availableCardInputMethods
    }
    
    // MARK: - AuthorizationStateObserver
    
    func authorizationStateDidChange(_ authorizationState: AuthorizationState) {
        DispatchQueue.main.async { [weak self] in
            print("🔄 Authorization state changed to: \(authorizationState)")
            
            if authorizationState == .authorized {
                if let location = MobilePaymentsSDK.shared.authorizationManager.location {
                    print("✅ SDK is now authorized with location: \(location.name)")
                    self?.updateConnectionStatus("SDK authorized with \(location.name)")
                    self?.paymentService?.connectToReader()
                } else {
                    print("⚠️ SDK authorized but no location info")
                    self?.updateConnectionStatus("SDK authorized but missing location")
                }
            } else {
                print("❌ SDK is not authorized")
                self?.updateConnectionStatus("Not authorized")
                
                // Update reader connected state
                if let paymentService = self?.paymentService {
                    paymentService.isReaderConnected = false
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// Update the connection status in the payment service (handle nil case)
    private func updateConnectionStatus(_ status: String) {
        DispatchQueue.main.async { [weak self] in
            self?.paymentService?.connectionStatus = status
        }
    }
    
    /// Update payment error in the payment service (handle nil case)
    private func updatePaymentError(_ error: String?) {
        DispatchQueue.main.async { [weak self] in
            self?.paymentService?.paymentError = error
        }
    }
}
