import Foundation
import Combine
import SwiftUI

/// Preset donation amount with Square catalog ID
struct PresetDonation: Identifiable, Equatable, Codable {
    var id: String
    var amount: String
    var catalogItemId: String?
    var isSync: Bool
    
    static func == (lhs: PresetDonation, rhs: PresetDonation) -> Bool {
        return lhs.id == rhs.id && lhs.amount == rhs.amount && lhs.catalogItemId == rhs.catalogItemId
    }
}

class KioskStore: ObservableObject {
    // MARK: - Published Properties
    
    @Published var headline: String = "Tap to Donate"
    @Published var subtext: String = ""
    @Published var backgroundImage: UIImage?
    @Published var logoImage: UIImage?
    @Published var presetDonations: [PresetDonation] = []
    @Published var allowCustomAmount: Bool = true
    @Published var minAmount: String = "1"
    @Published var maxAmount: String = "100000"
    @Published var timeoutDuration: String = "15"
    @Published var homePageEnabled: Bool = true
    @Published var processingFeeEnabled: Bool = false
    @Published var processingFeePercentage: Double = 2.6
    @Published var processingFeeFixedCents: Int = 15
    
    @Published var textVerticalPosition: KioskLayoutConstants.VerticalTextPosition = .center
    @Published var textVerticalFineTuning: Double = 0.0  // Range: -50 to +50
    @Published var headlineTextSize: Double = KioskLayoutConstants.defaultHeadlineSize
    @Published var subtextTextSize: Double = KioskLayoutConstants.defaultSubtextSize
    
    @Published var backgroundImageZoom: Double = 1.0
    @Published var backgroundImagePanX: Double = 0.0
    @Published var backgroundImagePanY: Double = 0.0
    
    // MARK: - Catalog Sync State
    @Published var isSyncingWithCatalog: Bool = false
    @Published var lastSyncError: String? = nil
    @Published var lastSyncTime: Date? = nil
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private var catalogService: SquareCatalogService?
    
    // MARK: - Initialization
    
    init() {
        setDefaultsIfNeeded()
        loadFromUserDefaults()
        
        // NEW: Listen for catalog state clear notifications
        NotificationCenter.default.addObserver(
            forName: Notification.Name("ClearCatalogState"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.clearCatalogState()
        }
    }
    private func setDefaultsIfNeeded() {
        let defaults: [String: Any] = [
            "kioskHomePageEnabled": true,
            "kioskAllowCustomAmount": true,
            "kioskTimeoutDuration": "15"
        ]
        
        UserDefaults.standard.register(defaults: defaults)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Public Methods
    
    /// Connect to the catalog service for sync operations
    func connectCatalogService(_ service: SquareCatalogService) {
        self.catalogService = service
        
        // Set up publishers to monitor catalog service changes
        service.$isLoading
            .assign(to: \.isSyncingWithCatalog, on: self)
            .store(in: &cancellables)
        
        service.$error
            .assign(to: \.lastSyncError, on: self)
            .store(in: &cancellables)
    }
    
    /// Load settings from UserDefaults
    func loadFromUserDefaults() {
        if let headline = UserDefaults.standard.string(forKey: "kioskHeadline") {
            self.headline = headline
        }
        
        if let subtext = UserDefaults.standard.string(forKey: "kioskSubtext") {
            self.subtext = subtext
        }
        
        // Load preset donations
        if let presetDonationsData = UserDefaults.standard.data(forKey: "kioskPresetDonations") {
            do {
                let decoder = JSONDecoder()
                self.presetDonations = try decoder.decode([PresetDonation].self, from: presetDonationsData)
            } catch {
                print("Failed to decode preset donations: \(error)")
                
                // Fallback to legacy presetAmounts format
                if let presetAmountsData = UserDefaults.standard.array(forKey: "kioskPresetAmounts") as? [String] {
                    self.presetDonations = presetAmountsData.map { amount in
                        PresetDonation(
                            id: UUID().uuidString,
                            amount: amount,
                            catalogItemId: nil,
                            isSync: false
                        )
                    }
                }
            }
        } else if let presetAmountsData = UserDefaults.standard.array(forKey: "kioskPresetAmounts") as? [String] {
            // Legacy support - migrate from old format
            self.presetDonations = presetAmountsData.map { amount in
                PresetDonation(
                    id: UUID().uuidString,
                    amount: amount,
                    catalogItemId: nil,
                    isSync: false
                )
            }
        }
        
        self.allowCustomAmount = UserDefaults.standard.bool(forKey: "kioskAllowCustomAmount")
        
        if let minAmount = UserDefaults.standard.string(forKey: "kioskMinAmount") {
            self.minAmount = minAmount
        }
        
        if let maxAmount = UserDefaults.standard.string(forKey: "kioskMaxAmount") {
            self.maxAmount = maxAmount
        }
        
        if let timeoutDuration = UserDefaults.standard.string(forKey: "kioskTimeoutDuration") {
            self.timeoutDuration = timeoutDuration
        }
        
        // Load homePageEnabled state
        self.homePageEnabled = UserDefaults.standard.bool(forKey: "kioskHomePageEnabled")
        
        // Load images if they exist
        if let logoImageData = UserDefaults.standard.data(forKey: "kioskLogoImage") {
            self.logoImage = UIImage(data: logoImageData)
        }
        
        if let backgroundImageData = UserDefaults.standard.data(forKey: "kioskBackgroundImage") {
            self.backgroundImage = UIImage(data: backgroundImageData)
        }
        
        // Load sync state
        if let lastSyncTimeInterval = UserDefaults.standard.object(forKey: "kioskLastSyncTime") as? TimeInterval {
            self.lastSyncTime = Date(timeIntervalSince1970: lastSyncTimeInterval)
        }
        
        // Load layout customization settings
        if let positionRaw = UserDefaults.standard.string(forKey: "kioskTextVerticalPosition"),
           let position = KioskLayoutConstants.VerticalTextPosition(rawValue: positionRaw) {
            self.textVerticalPosition = position
        }

        self.textVerticalFineTuning = UserDefaults.standard.double(forKey: "kioskTextVerticalFineTuning")

        let savedHeadlineSize = UserDefaults.standard.double(forKey: "kioskHeadlineTextSize")
        if savedHeadlineSize > 0 {
            self.headlineTextSize = savedHeadlineSize
        }

        let savedSubtextSize = UserDefaults.standard.double(forKey: "kioskSubtextTextSize")
        if savedSubtextSize > 0 {
            self.subtextTextSize = savedSubtextSize
        }
        
        let savedZoom = UserDefaults.standard.double(forKey: "kioskBackgroundImageZoom")
             if savedZoom > 0 {
                 self.backgroundImageZoom = savedZoom
             }
             
             self.backgroundImagePanX = UserDefaults.standard.double(forKey: "kioskBackgroundImagePanX")
             self.backgroundImagePanY = UserDefaults.standard.double(forKey: "kioskBackgroundImagePanY")
        
        if presetDonations.isEmpty {
            presetDonations = [
                PresetDonation(id: UUID().uuidString, amount: "18", catalogItemId: nil, isSync: false),
                PresetDonation(id: UUID().uuidString, amount: "36", catalogItemId: nil, isSync: false),
                PresetDonation(id: UUID().uuidString, amount: "54", catalogItemId: nil, isSync: false),
                PresetDonation(id: UUID().uuidString, amount: "100", catalogItemId: nil, isSync: false),
                PresetDonation(id: UUID().uuidString, amount: "180", catalogItemId: nil, isSync: false),
                PresetDonation(id: UUID().uuidString, amount: "360", catalogItemId: nil, isSync: false)
            ]
            saveToUserDefaults() // Save the defaults
        }
        
        // Load processing fee settings
           self.processingFeeEnabled = UserDefaults.standard.bool(forKey: "kioskProcessingFeeEnabled")
           
           // Load percentage with fallback to default
           let savedPercentage = UserDefaults.standard.double(forKey: "kioskProcessingFeePercentage")
           self.processingFeePercentage = savedPercentage > 0 ? savedPercentage : 2.6
           
           // Load fixed cents with fallback to default
           let savedFixedCents = UserDefaults.standard.integer(forKey: "kioskProcessingFeeFixedCents")
           self.processingFeeFixedCents = savedFixedCents > 0 ? savedFixedCents : 15
    }


    /// Save settings to UserDefaults
    func saveToUserDefaults() {
        UserDefaults.standard.set(headline, forKey: "kioskHeadline")
        UserDefaults.standard.set(subtext, forKey: "kioskSubtext")
        
        // Save preset donations in new format
        do {
            let encoder = JSONEncoder()
            let presetDonationsData = try encoder.encode(presetDonations)
            UserDefaults.standard.set(presetDonationsData, forKey: "kioskPresetDonations")
            
            // Also save in legacy format for backwards compatibility
            let amountsOnly = presetDonations.map { $0.amount }
            UserDefaults.standard.set(amountsOnly, forKey: "kioskPresetAmounts")
        } catch {
            print("Failed to encode preset donations: \(error)")
            
            // Fallback to legacy format
            let amountsOnly = presetDonations.map { $0.amount }
            UserDefaults.standard.set(amountsOnly, forKey: "kioskPresetAmounts")
        }
        
        UserDefaults.standard.set(allowCustomAmount, forKey: "kioskAllowCustomAmount")
        UserDefaults.standard.set(minAmount, forKey: "kioskMinAmount")
        UserDefaults.standard.set(maxAmount, forKey: "kioskMaxAmount")
        UserDefaults.standard.set(timeoutDuration, forKey: "kioskTimeoutDuration")
        UserDefaults.standard.set(homePageEnabled, forKey: "kioskHomePageEnabled")
        
        // Save layout customization settings
        UserDefaults.standard.set(textVerticalPosition.rawValue, forKey: "kioskTextVerticalPosition")
        UserDefaults.standard.set(textVerticalFineTuning, forKey: "kioskTextVerticalFineTuning")
        UserDefaults.standard.set(headlineTextSize, forKey: "kioskHeadlineTextSize")
        UserDefaults.standard.set(subtextTextSize, forKey: "kioskSubtextTextSize")
        
        // 🆕 ADD THESE LINES - Save zoom and pan settings
        UserDefaults.standard.set(backgroundImageZoom, forKey: "kioskBackgroundImageZoom")
        UserDefaults.standard.set(backgroundImagePanX, forKey: "kioskBackgroundImagePanX")
        UserDefaults.standard.set(backgroundImagePanY, forKey: "kioskBackgroundImagePanY")
        
        // Save processing fee settings
           UserDefaults.standard.set(processingFeeEnabled, forKey: "kioskProcessingFeeEnabled")
           UserDefaults.standard.set(processingFeePercentage, forKey: "kioskProcessingFeePercentage")
           UserDefaults.standard.set(processingFeeFixedCents, forKey: "kioskProcessingFeeFixedCents")
               
        
        // Save logo image or remove it if nil
        if let logoImage = logoImage, let logoData = logoImage.jpegData(compressionQuality: 0.8) {
            UserDefaults.standard.set(logoData, forKey: "kioskLogoImage")
        } else {
            UserDefaults.standard.removeObject(forKey: "kioskLogoImage")
        }
        
        // Save background image
        if let backgroundImage = backgroundImage, let backgroundData = backgroundImage.jpegData(compressionQuality: 0.8) {
            UserDefaults.standard.set(backgroundData, forKey: "kioskBackgroundImage")
        } else {
            UserDefaults.standard.removeObject(forKey: "kioskBackgroundImage")
        }
        
        // Save sync state
        if let lastSyncTime = lastSyncTime {
            UserDefaults.standard.set(lastSyncTime.timeIntervalSince1970, forKey: "kioskLastSyncTime")
        } else {
            UserDefaults.standard.removeObject(forKey: "kioskLastSyncTime")
        }
    }
    
    /// Save all settings, including syncing to Square catalog if connected
    func saveSettings() {
        saveToUserDefaults()
        
        // If catalog service is connected, sync preset amounts
        if let catalogService = catalogService {
            syncPresetAmountsWithCatalog(using: catalogService)
        }
        
        // In a real app, you might want to sync with a server here
        NotificationCenter.default.post(name: Notification.Name("KioskSettingsUpdated"), object: nil)
    }
    
    /// Sync preset donation amounts with Square catalog
    func syncPresetAmountsWithCatalog(using service: SquareCatalogService) {
        isSyncingWithCatalog = true
        lastSyncError = nil
        
        // Extract amounts as doubles
        let amountValues = presetDonations.compactMap { Double($0.amount) }
        
        // Only sync if we have valid amounts
        if !amountValues.isEmpty {
            service.savePresetDonations(amounts: amountValues)
            
            // Update sync status
            lastSyncTime = Date()
            saveToUserDefaults()
            
            // Start watching for catalog service changes
            service.$presetDonations
                .sink { [weak self] catalogItems in
                    guard let self = self else { return }
                    
                    // Update preset donations with catalog item IDs
                    self.updatePresetDonationsFromCatalog(catalogItems)
                }
                .store(in: &cancellables)
        } else {
            isSyncingWithCatalog = false
        }
    }
    
    /// Update the DonationViewModel with the current preset amounts
    func updateDonationViewModel(_ donationViewModel: DonationViewModel) {
        var numericAmounts: [Double] = []
        for donation in presetDonations {
            if let amount = Double(donation.amount) {
                numericAmounts.append(amount)
            }
        }
        
        if !numericAmounts.isEmpty {
            donationViewModel.presetAmounts = numericAmounts
        }
    }
    
    /// Load preset donations from Square catalog
    func loadPresetDonationsFromCatalog() {
        guard let catalogService = catalogService else {
            lastSyncError = "Catalog service not connected"
            return
        }
        
        isSyncingWithCatalog = true
        lastSyncError = nil
        
        // Load donations from catalog
        catalogService.fetchPresetDonations()
    }
    
    /// Update preset donations with catalog item IDs - with stale data handling
    private func updatePresetDonationsFromCatalog(_ catalogItems: [DonationItem]) {
        print("🔄 Updating preset donations from catalog with \(catalogItems.count) items")
        
        // Skip if there are no catalog items
        if catalogItems.isEmpty {
            print("⚠️ No catalog items received, marking all as unsynced")
            // Mark all existing items as not synced but don't clear IDs yet
            var updatedDonations: [PresetDonation] = []
            for donation in presetDonations {
                updatedDonations.append(PresetDonation(
                    id: donation.id,
                    amount: donation.amount,
                    catalogItemId: donation.catalogItemId, // Keep ID for now
                    isSync: false  // But mark as not synced
                ))
            }
            presetDonations = updatedDonations
            saveToUserDefaults()
            return
        }
        
        // Create a map of amount to catalog item for easier lookup
        var catalogItemMap: [Double: DonationItem] = [:]
        for item in catalogItems {
            catalogItemMap[item.amount] = item
        }
        
        // Update local preset donations with catalog item IDs
        var updatedDonations: [PresetDonation] = []
        var hasStaleItems = false
        
        for donation in presetDonations {
            if let amount = Double(donation.amount),
               let catalogItem = catalogItemMap[amount] {
                // Found matching catalog item
                let newDonation = PresetDonation(
                    id: donation.id,
                    amount: donation.amount,
                    catalogItemId: catalogItem.id,
                    isSync: true
                )
                updatedDonations.append(newDonation)
                
                // Check if the catalog ID actually changed (item was recreated)
                if donation.catalogItemId != nil && donation.catalogItemId != catalogItem.id {
                    print("📋 Catalog ID updated for amount \(donation.amount): \(donation.catalogItemId ?? "nil") -> \(catalogItem.id)")
                }
            } else {
                // No matching catalog item found
                if donation.catalogItemId != nil {
                    // Had an ID but no longer matches - this is stale data
                    hasStaleItems = true
                    print("⚠️ Stale catalog ID detected for amount \(donation.amount)")
                }
                
                updatedDonations.append(PresetDonation(
                    id: donation.id,
                    amount: donation.amount,
                    catalogItemId: nil,  // Clear stale ID
                    isSync: false
                ))
            }
        }
        
        // Update the published property
        presetDonations = updatedDonations
        
        // Save the updated state
        saveToUserDefaults()
        
        // If we detected stale items, log it but don't auto-retry here
        // Let the user's next save operation handle the sync
        if hasStaleItems {
            print("⚠️ Some items have stale catalog IDs - they will be recreated on next sync")
        }
        
        print("✅ Updated \(updatedDonations.count) preset donations, \(updatedDonations.filter { $0.isSync }.count) synced")
    }
    
    /// NEW: Clear all catalog state when disconnecting
    func clearCatalogState() {
        print("🔄 Clearing all catalog state due to authentication change")
        
        // Clear parent item ID
        if let catalogService = catalogService {
            catalogService.parentItemId = nil
            catalogService.presetDonations = []
            catalogService.lastSyncTime = nil
        }
        
        // Mark all preset donations as unsynced and clear IDs
        var clearedDonations: [PresetDonation] = []
        for donation in presetDonations {
            clearedDonations.append(PresetDonation(
                id: donation.id,
                amount: donation.amount,
                catalogItemId: nil,
                isSync: false
            ))
        }
        presetDonations = clearedDonations
        
        saveToUserDefaults()
        print("✅ Catalog state cleared")
    }
    
    /// Add a new preset donation amount
    func addPresetDonation(amount: String) {
        let newDonation = PresetDonation(
            id: UUID().uuidString,
            amount: amount,
            catalogItemId: nil,
            isSync: false
        )
        
        presetDonations.append(newDonation)
        
        // Sort by amount
        sortPresetDonations()
        
        // Save settings
        saveToUserDefaults()
    }
    
    /// Remove a preset donation amount
    func removePresetDonation(at index: Int) {
        // Check if donation has a catalog item ID
        let donation = presetDonations[index]
        
        if let catalogItemId = donation.catalogItemId, let catalogService = catalogService {
            // Delete from catalog if synced
            catalogService.deletePresetDonation(id: catalogItemId)
        }
        
        // Remove from local list
        presetDonations.remove(at: index)
        
        // Save settings
        saveToUserDefaults()
    }
    
    /// Update a preset donation amount
    func updatePresetDonation(at index: Int, amount: String) {
        let donation = presetDonations[index]
        
        // Create updated donation
        let updatedDonation = PresetDonation(
            id: donation.id,
            amount: amount,
            catalogItemId: donation.catalogItemId,
            isSync: false // Mark as not synced since amount changed
        )
        
        // Replace in array
        presetDonations[index] = updatedDonation
        
        // Sort by amount
        sortPresetDonations()
        
        // Save settings
        saveToUserDefaults()
    }
    
    /// Sort preset donations by amount
    private func sortPresetDonations() {
        presetDonations.sort {
            guard let amount1 = Double($0.amount),
                  let amount2 = Double($1.amount) else {
                return false
            }
            return amount1 < amount2
        }
    }
    
    // MARK: - NEW: Order Creation Method
    
    /// Create an order for a donation using the catalog service
    func createDonationOrder(
        amount: Double,
        isCustomAmount: Bool,
        completion: @escaping (String?, Error?) -> Void
    ) {
        print("🛒 KioskStore.createDonationOrder called")
        print("💰 Amount: $\(amount)")
        print("🎯 Is Custom: \(isCustomAmount)")
        
        guard amount > 0 else {
            let error = NSError(
                domain: "com.charitypad",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Invalid amount: \(amount)"]
            )
            print("❌ Invalid amount provided")
            completion(nil, error)
            return
        }
        
        // Construct URL for the order creation endpoint
        guard let url = URL(string: "\(SquareConfig.backendBaseURL)/api/square/orders/create") else {
            let error = NSError(
                domain: "com.charitypad",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Invalid request URL"]
            )
            print("❌ Invalid backend URL")
            completion(nil, error)
            return
        }
        
        var requestBody: [String: Any]
        
        if isCustomAmount {
             // UPDATED: Include processing fee parameters for custom amounts
             requestBody = [
                 "organization_id": SquareConfig.organizationId,
                 "is_custom_amount": true,
                 "custom_amount": amount,
                 "reference_id": "custom_donation_\(Int(Date().timeIntervalSince1970))",
                 "state": "OPEN",
                 "processing_fee_enabled": processingFeeEnabled,
                 "processing_fee_percentage": processingFeePercentage,
                 "processing_fee_fixed_cents": processingFeeFixedCents
             ]
            
            print("📝 Creating custom amount order request")
            print("🔧 Using new backend custom amount flow")
        } else {
            // For preset amounts, try to find matching catalog item
            var catalogItemId: String? = nil
            
            if let donation = presetDonations.first(where: { Double($0.amount) == amount }) {
                catalogItemId = donation.catalogItemId
                print("📋 Found catalog item ID: \(catalogItemId ?? "nil")")
            } else {
                print("⚠️ No catalog item found for preset amount $\(amount)")
            }
            
            var lineItem: [String: Any]
            
            if let catalogItemId = catalogItemId {
                // Use catalog item for preset amount
                lineItem = [
                    "catalogObjectId": catalogItemId,
                    "quantity": "1"
                ]
                print("📋 Using catalog item: \(catalogItemId)")
            } else {
                // Fallback to ad-hoc item for preset amount
                lineItem = [
                    "name": "$\(Int(amount)) Donation",
                    "quantity": "1",
                    "basePriceMoney": [
                        "amount": Int(amount * 100),
                        "currency": "USD"
                    ]
                ]
                print("🏗️ Using ad-hoc item fallback")
            }
            
            requestBody = [
                      "organization_id": SquareConfig.organizationId,
                      "line_items": [lineItem],
                      "reference_id": "preset_donation_\(Int(Date().timeIntervalSince1970))",
                      "state": "OPEN",
                      "processing_fee_enabled": processingFeeEnabled,
                      "processing_fee_percentage": processingFeePercentage,
                      "processing_fee_fixed_cents": processingFeeFixedCents
                  ]
            
            print("📝 Creating preset amount order request")
        }
        
        // Create and configure the request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
            request.httpBody = jsonData
            
            // Log request for debugging
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("📤 Request body: \(jsonString)")
            }
        } catch {
            print("❌ Failed to serialize request: \(error)")
            completion(nil, error)
            return
        }
        
        print("🌐 Making request to: \(url)")
        
        // Make the network request
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                // Handle network error
                if let error = error {
                    print("❌ Network error: \(error.localizedDescription)")
                    completion(nil, error)
                    return
                }
                
                // Log HTTP response status
                if let httpResponse = response as? HTTPURLResponse {
                    print("📡 HTTP Status: \(httpResponse.statusCode)")
                }
                
                // Handle missing data
                guard let data = data else {
                    let error = NSError(
                        domain: "com.charitypad",
                        code: 500,
                        userInfo: [NSLocalizedDescriptionKey: "No data received from server"]
                    )
                    print("❌ No data received")
                    completion(nil, error)
                    return
                }
                
                // Log raw response for debugging
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📥 Response: \(responseString)")
                }
                
                // Parse JSON response
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        
                        // Check for success field
                        if let success = json["success"] as? Bool, !success {
                            // Handle structured error response
                            let errorMessage = json["error"] as? String ?? "Order creation failed"
                            let nsError = NSError(
                                domain: "com.charitypad",
                                code: 500,
                                userInfo: [NSLocalizedDescriptionKey: errorMessage]
                            )
                            print("❌ Server error: \(errorMessage)")
                            completion(nil, nsError)
                            return
                        }
                        
                        // Handle legacy error field
                        if let error = json["error"] as? String {
                            let nsError = NSError(
                                domain: "com.charitypad",
                                code: 500,
                                userInfo: [NSLocalizedDescriptionKey: error]
                            )
                            print("❌ Backend error: \(error)")
                            completion(nil, nsError)
                            return
                        }
                        
                        // Extract order ID
                        if let orderId = json["order_id"] as? String {
                            print("✅ Order created successfully: \(orderId)")
                            
                            // Log additional order details if available
                            if let totalMoney = json["total_money"] as? [String: Any],
                               let amount = totalMoney["amount"] as? Int {
                                let dollarAmount = Double(amount) / 100.0
                                print("💰 Order total: $\(dollarAmount)")
                            }
                            
                            if let lineItems = json["line_items"] as? [[String: Any]] {
                                print("📋 Line items count: \(lineItems.count)")
                                for (index, item) in lineItems.enumerated() {
                                    if let name = item["name"] as? String {
                                        print("📋 Item \(index): \(name)")
                                    }
                                }
                            }
                            
                            completion(orderId, nil)
                        } else {
                            let error = NSError(
                                domain: "com.charitypad",
                                code: 500,
                                userInfo: [NSLocalizedDescriptionKey: "No order ID in response"]
                            )
                            print("❌ No order ID in response")
                            completion(nil, error)
                        }
                    } else {
                        let error = NSError(
                            domain: "com.charitypad",
                            code: 500,
                            userInfo: [NSLocalizedDescriptionKey: "Invalid JSON response"]
                        )
                        print("❌ Failed to parse JSON response")
                        completion(nil, error)
                    }
                } catch {
                    print("❌ JSON parsing error: \(error)")
                    completion(nil, error)
                }
            }
        }.resume()
    }
    // MARK: - Processing Fee Calculation Helper
    func calculateProcessingFee(for amount: Double) -> Double {
        guard processingFeeEnabled else { return 0 }
        
        let percentageFee = amount * (processingFeePercentage / 100.0)
        let fixedFee = Double(processingFeeFixedCents) / 100.0
        
        return percentageFee + fixedFee
    }

    func calculateTotalWithFees(for amount: Double) -> Double {
        return amount + calculateProcessingFee(for: amount)
    }
}


