import Foundation
import SwiftUI
import SquareMobilePaymentsSDK

class SquareReaderService: NSObject, ObservableObject {
    // Published properties for UI updates
    @Published var readers: [ReaderInfo] = []
    @Published var selectedReader: ReaderInfo? = nil
    @Published var availableCardInputMethods = CardInputMethods()
    
    // Private properties
    private let authService: SquareAuthService
    private var isInitialized = false
    
    // Dependencies for connection logic
    private weak var paymentService: SquarePaymentService?
    private weak var permissionService: SquarePermissionService?
    
    init(authService: SquareAuthService) {
        self.authService = authService
        super.init()
        
        // Add notification listener for authentication success
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAuthenticationSuccess),
            name: .squareAuthenticationSuccessful,
            object: nil
        )
    }
    
    deinit {
        stopMonitoring()
        
        // Only remove observer if we added it previously
        if isInitialized {
            MobilePaymentsSDK.shared.authorizationManager.remove(self)
        }
        
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Configuration
    
    /// Configure the service with necessary dependencies
    func configure(with paymentService: SquarePaymentService, permissionService: SquarePermissionService) {
        self.paymentService = paymentService
        self.permissionService = permissionService
    }
    
    // MARK: - Connection Logic (Simplified)
    
    /// Connect to a Square reader - uses Square's built-in management
    func connectToReader() {
        // Ensure SDK is initialized and available
        guard MobilePaymentsSDK.shared.authorizationManager.state == .authorized else {
            updateConnectionStatus("Square SDK not authorized")
            return
        }
        
        // Just update the connection status - Square's built-in settings handle pairing
        updateReaderConnectionStatus()
    }
    
    /// Update reader connection status
    func updateReaderConnectionStatus() {
        if readers.isEmpty {
            updateConnectionStatus("No readers connected")
            updateReaderConnected(false)
            return
        }
        
        if let readyReader = readers.first(where: { $0.state == .ready }) {
            updateConnectionStatus("Connected to \(readyReader.model == .stand ? "Square Stand" : "Square Reader")")
            updateReaderConnected(true)
            return
        }
        
        // We have readers but none are ready
        if let firstReader = readers.first {
            updateConnectionStatus("Reader \(readerStateDescription(firstReader.state))")
            updateReaderConnected(false)
        }
    }
    
    // MARK: - Debug Methods
    
    /// Prints debug information about the Square SDK
    func debugSquareSDK() {
        guard isInitialized else {
            print("Cannot debug Square SDK - not yet initialized")
            return
        }
        
        print("\n--- Square SDK Debug Information ---")
        
        // SDK version and environment
        print("SDK Version: \(MobilePaymentsSDK.version)")
        print("SDK Environment: \(String(describing: MobilePaymentsSDK.shared.settingsManager.sdkSettings.environment))")
        
        // Authorization state
        print("Authorization State: \(String(describing: MobilePaymentsSDK.shared.authorizationManager.state))")
        
        // List available readers
        print("\n--- Available Readers ---")
        let readers = MobilePaymentsSDK.shared.readerManager.readers
        print("Found \(readers.count) readers")
        
        // If we have a reader, examine it
        for (index, reader) in readers.enumerated() {
            print("\nReader \(index + 1):")
            print("  Serial: \(reader.serialNumber ?? "unknown")")
            print("  Model: \(reader.model)")
            print("  State: \(reader.state)")
            print("  Connection: \(reader.connectionInfo.state)")
            
            if let batteryStatus = reader.batteryStatus {
                print("  Battery: \(batteryStatus.isCharging ? "Charging" : "Not charging")")
                print("  Level: \(batteryStatus.level)")
            }
        }
        
        print("\n--- Debug Complete ---")
    }
    
    // MARK: - Public Methods
    
    /// Check if SDK is initialized and fully ready
    func checkIfInitialized() -> Bool {
        guard let _ = try? MobilePaymentsSDK.shared else {
            print("Square SDK not initialized yet - shared instance not available")
            return false
        }
        
        if !isInitialized {
            isInitialized = true
            print("Square SDK initialized and available")
        }
        
        return true
    }
    
    /// Start monitoring for reader updates - only call after SDK is initialized
    func startMonitoring() {
        guard checkIfInitialized() else {
            print("Cannot start monitoring - SDK not initialized")
            return
        }
        
        // Add authorization observer if needed
        MobilePaymentsSDK.shared.authorizationManager.add(self)
        
        // Add this class as an observer to receive reader updates
        MobilePaymentsSDK.shared.readerManager.add(self)
        MobilePaymentsSDK.shared.paymentManager.add(self)
        
        // Update initial readers list
        refreshReaders()
        
        // Update available card input methods
        refreshAvailableCardInputMethods()
        
        #if DEBUG
        // Run debug in debug builds
        debugSquareSDK()
        #endif
    }
    
    /// Stop monitoring for reader updates
    func stopMonitoring() {
        guard isInitialized else {
            return
        }
        
        MobilePaymentsSDK.shared.readerManager.remove(self)
        MobilePaymentsSDK.shared.paymentManager.remove(self)
    }
    
    /// Select a reader to use for payments
    func selectReader(_ reader: ReaderInfo) {
        // Only select readers that are in ready state
        if reader.state == .ready {
            selectedReader = reader
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
    }
    
    /// Present the built-in Square reader settings UI
    func presentReaderSettings(from viewController: UIViewController) {
        guard checkIfInitialized() else { return }
        MobilePaymentsSDK.shared.settingsManager.presentSettings(
            with: viewController,
            completion: { _ in
                // Handle dismissal if needed
                self.refreshReaders()
            }
        )
    }
    
    // MARK: - Helper Methods
    
    /// Check if a reader supports a specific payment method
    func readerSupportsPaymentMethod(_ reader: ReaderInfo, method: String) -> Bool {
        switch method.lowercased() {
        case "contactless":
            return reader.model == .contactlessAndChip || reader.model == .stand
        case "chip":
            return reader.model == .contactlessAndChip || reader.model == .stand
        case "swipe", "magstripe":
            return reader.model == .magstripe || reader.model == .contactlessAndChip || reader.model == .stand
        default:
            return false
        }
    }
    
    /// Get battery level description
    func batteryLevelDescription(_ reader: ReaderInfo) -> String {
        guard let batteryStatus = reader.batteryStatus else {
            return "N/A"
        }
        
        let levelDescription: String
        let levelObj = batteryStatus.level
        if let numberLevel = levelObj as? Double {
            let percentage = Int(numberLevel * 100)
            levelDescription = "\(percentage)%"
        } else if let intLevel = levelObj as? Int {
            levelDescription = "\(intLevel)%"
        } else {
            levelDescription = "Available"
        }
        
        let chargingStatus = batteryStatus.isCharging ? " (Charging)" : ""
        return "\(levelDescription)\(chargingStatus)"
    }
    
    /// Get a descriptive text for reader state
    func readerStateDescription(_ state: ReaderState) -> String {
        switch state {
        case .connecting:
            return "Connecting..."
        case .ready:
            return "Ready"
        case .disconnected:
            return "Disconnected"
        case .updatingFirmware:
            return "Updating Firmware..."
        case .failedToConnect:
            return "Failed to Connect"
        case .disabled:
            return "Disabled"
        @unknown default:
            return "Unknown State"
        }
    }
    
    /// Get a descriptive text for reader model
    func readerModelDescription(_ model: ReaderModel) -> String {
        switch model {
        case .contactlessAndChip:
            return "Square Reader for contactless and chip"
        case .magstripe:
            return "Square Reader for magstripe"
        case .stand:
            return "Square Stand"
        case .tapToPay:
            return "Tap to Pay on iPhone"
        case .unknown:
            return "Unknown Square Reader"
        @unknown default:
            return "Unknown Reader Model"
        }
    }
    
    /// Get a string description of available payment methods
    func paymentMethodsDescription(_ methods: CardInputMethods) -> String {
        let mirror = Mirror(reflecting: methods)
        var supportedMethods: [String] = []
        
        for (label, value) in mirror.children {
            if let label = label, let boolValue = value as? Bool, boolValue {
                supportedMethods.append(label)
            }
        }
        
        if supportedMethods.isEmpty {
            return "None"
        } else {
            return supportedMethods.joined(separator: ", ")
        }
    }
    
    // MARK: - Private Methods
    
    /// Update the connection status in the payment service
    private func updateConnectionStatus(_ status: String) {
        DispatchQueue.main.async { [weak self] in
            self?.paymentService?.connectionStatus = status
        }
    }
    
    /// Update reader connected state in the payment service
    private func updateReaderConnected(_ connected: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.paymentService?.isReaderConnected = connected
        }
    }
    
    /// Update payment error in the payment service
    private func updatePaymentError(_ error: String?) {
        DispatchQueue.main.async { [weak self] in
            self?.paymentService?.paymentError = error
        }
    }
    
    @objc private func handleAuthenticationSuccess(_ notification: Notification) {
        DispatchQueue.main.async {
            print("SquareReaderService: Authentication success notification received, starting monitoring")
            self.startMonitoring()
        }
    }
    
    /// Refresh the list of available readers
    private func refreshReaders() {
        guard checkIfInitialized() else { return }
        
        DispatchQueue.main.async {
            self.readers = MobilePaymentsSDK.shared.readerManager.readers
            
            // If we have an available reader and none is selected, select the first ready one
            if self.selectedReader == nil && !self.readers.isEmpty {
                self.selectedReader = self.readers.first(where: { $0.state == .ready })
            }
            
            // If the currently selected reader is not ready anymore, try to find another ready reader
            if let selectedReader = self.selectedReader, selectedReader.state != .ready {
                self.selectedReader = self.readers.first(where: { $0.state == .ready })
            }
            
            self.objectWillChange.send()
            
            // Update connection status after refreshing readers
            self.updateReaderConnectionStatus()
        }
    }
    
    /// Refresh the available card input methods
    func refreshAvailableCardInputMethods() {
        guard checkIfInitialized() else { return }
        
        DispatchQueue.main.async {
            self.availableCardInputMethods = MobilePaymentsSDK.shared.paymentManager.availableCardInputMethods
            self.objectWillChange.send()
        }
    }
}

// MARK: - AuthorizationStateObserver
extension SquareReaderService: AuthorizationStateObserver {
    func authorizationStateDidChange(_ authorizationState: AuthorizationState) {
        DispatchQueue.main.async {
            if authorizationState == .authorized {
                print("SquareReaderService: SDK authorized, starting monitoring")
                self.startMonitoring()
            } else {
                print("SquareReaderService: SDK not authorized, stopping monitoring")
                self.stopMonitoring()
                self.readers = []
                self.selectedReader = nil
                self.updateConnectionStatus("Not connected to Square")
                self.updateReaderConnected(false)
            }
        }
    }
}

// MARK: - ReaderObserver
extension SquareReaderService: ReaderObserver {
    func readerWasAdded(_ readerInfo: ReaderInfo) {
        refreshReaders()
    }
    
    func readerWasRemoved(_ readerInfo: ReaderInfo) {
        DispatchQueue.main.async {
            self.refreshReaders()
            
            // If the removed reader was selected, clear selection
            if let selectedReader = self.selectedReader, selectedReader.serialNumber == readerInfo.serialNumber {
                self.selectedReader = nil
            }
            
            self.objectWillChange.send()
        }
    }
    
    func readerDidChange(_ readerInfo: ReaderInfo, change: ReaderChange) {
        DispatchQueue.main.async {
            // Update readers list for any change
            self.refreshReaders()
            
            // If the state changed for our selected reader, update available card input methods
            if change == .stateDidChange,
               let selectedReader = self.selectedReader,
               selectedReader.serialNumber == readerInfo.serialNumber {
                self.refreshAvailableCardInputMethods()
            }
            
            self.objectWillChange.send()
        }
    }
}

// MARK: - AvailableCardInputMethodsObserver
extension SquareReaderService: AvailableCardInputMethodsObserver {
    func availableCardInputMethodsDidChange(_ cardInputMethods: CardInputMethods) {
        DispatchQueue.main.async {
            self.availableCardInputMethods = cardInputMethods
            self.objectWillChange.send()
        }
    }
}
