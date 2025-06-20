import Foundation
import Combine

/// Structure to represent a donation catalog item - UPDATED to match backend response
struct DonationItem: Identifiable, Codable {
    var id: String
    var parentId: String
    var name: String
    var amount: Double
    var formattedAmount: String
    var type: String
    var ordinal: Int?
    
    enum CodingKeys: String, CodingKey {
        case id
        case parentId = "parent_id"
        case name
        case amount
        case formattedAmount = "formatted_amount"
        case type
        case ordinal
    }
}

/// Parent item information
struct ParentItem: Identifiable, Codable {
    var id: String
    var name: String
    var description: String?
    var productType: String?
    var updatedAt: String?
    var version: Int?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case productType = "product_type"
        case updatedAt = "updated_at"
        case version
    }
}

/// Service responsible for managing donation catalog items in Square
class SquareCatalogService: ObservableObject {
    // MARK: - Published Properties
    
    @Published var presetDonations: [DonationItem] = []
    @Published var parentItems: [ParentItem] = []
    @Published var isLoading: Bool = false
    @Published var error: String? = nil
    @Published var parentItemId: String? = nil
    @Published var lastSyncTime: Date? = nil
    
    // MARK: - Private Properties
    
    private let authService: SquareAuthService
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(authService: SquareAuthService) {
        self.authService = authService
    }
    
    // MARK: - Public Methods
    
    /// Fetch preset donations from Square catalog
    func fetchPresetDonations() {
        guard authService.isAuthenticated else {
            error = "Not connected to Square"
            return
        }
        
        isLoading = true
        error = nil
        
        guard let url = URL(string: "\(SquareConfig.backendBaseURL)/api/square/catalog/list?organization_id=\(authService.organizationId)") else {
            error = "Invalid request URL"
            isLoading = false
            return
        }
        
        print("📋 Fetching catalog items from: \(url)")
        
        URLSession.shared.dataTaskPublisher(for: url)
            .map { $0.data }
            .decode(type: CatalogResponse.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                guard let self = self else { return }
                self.isLoading = false
                
                switch completion {
                case .finished:
                    break
                case .failure(let error):
                    self.error = "Failed to fetch donation items: \(error.localizedDescription)"
                    print("❌ Catalog fetch error: \(error)")
                }
            }, receiveValue: { [weak self] response in
                guard let self = self else { return }
                
                // Store parent items and donation items
                self.parentItems = response.parentItems
                self.presetDonations = response.donationItems.sorted { $0.amount < $1.amount }
                
                // Store parent item ID if available
                if let firstParent = response.parentItems.first {
                    self.parentItemId = firstParent.id
                }
                
                // Update last sync time
                self.lastSyncTime = Date()
                
                print("✅ Fetched \(self.presetDonations.count) donation items with \(self.parentItems.count) parent items")
                print("📊 Amounts: \(self.presetDonations.map { $0.amount })")
            })
            .store(in: &cancellables)
    }
    
    /// Save preset donation amounts to Square catalog using batch upsert with robust error handling
    func savePresetDonations(amounts: [Double]) {
        guard authService.isAuthenticated else {
            error = "Not connected to Square"
            return
        }
        
        isLoading = true
        error = nil
        
        guard let url = URL(string: "\(SquareConfig.backendBaseURL)/api/square/catalog/batch-upsert") else {
            error = "Invalid request URL"
            isLoading = false
            return
        }
        
        let requestBody: [String: Any] = [
            "organization_id": authService.organizationId,
            "amounts": amounts,
            "parent_item_id": parentItemId as Any,
            "parent_item_name": "Donations",
            "parent_item_description": "Donation preset amounts",
            "replace_existing": true, // NEW: Force replacement if needed
            "validate_existing": true  // NEW: Validate items before operations
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            self.error = "Failed to serialize request: \(error.localizedDescription)"
            isLoading = false
            return
        }
        
        print("💾 Saving \(amounts.count) preset amounts with robust sync: \(amounts)")
        
        performNetworkRequestWithRetry(request: request, maxRetries: 2) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                switch result {
                case .success(let data):
                    self.handleSaveSuccess(data: data, amounts: amounts)
                case .failure(let error):
                    self.handleSaveFailure(error: error, amounts: amounts)
                }
            }
        }
    }

    /// NEW: Network request with automatic retry logic
    private func performNetworkRequestWithRetry(
        request: URLRequest,
        maxRetries: Int,
        completion: @escaping (Result<Data, Error>) -> Void
    ) {
        func attempt(retryCount: Int) {
            URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
                // Check for network errors
                if let error = error {
                    print("❌ Network error (attempt \(maxRetries - retryCount + 1)): \(error.localizedDescription)")
                    
                    if retryCount > 0 {
                        print("🔄 Retrying in 2 seconds...")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            attempt(retryCount: retryCount - 1)
                        }
                    } else {
                        completion(.failure(error))
                    }
                    return
                }
                
                // Check HTTP response
                guard let httpResponse = response as? HTTPURLResponse else {
                    let error = NSError(domain: "InvalidResponse", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
                    completion(.failure(error))
                    return
                }
                
                // Handle specific HTTP status codes
                switch httpResponse.statusCode {
                case 200...299:
                    // Success
                    if let data = data {
                        completion(.success(data))
                    } else {
                        let error = NSError(domain: "NoData", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data received"])
                        completion(.failure(error))
                    }
                    
                case 400...499:
                    // Client errors - don't retry these
                    let errorMessage = "Client error: \(httpResponse.statusCode)"
                    let error = NSError(domain: "ClientError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
                    completion(.failure(error))
                    
                case 500...599:
                    // Server errors - retry these
                    print("⚠️ Server error \(httpResponse.statusCode) (attempt \(maxRetries - retryCount + 1))")
                    
                    if retryCount > 0 {
                        print("🔄 Retrying server error in 3 seconds...")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                            attempt(retryCount: retryCount - 1)
                        }
                    } else {
                        let errorMessage = "Server error: \(httpResponse.statusCode)"
                        let error = NSError(domain: "ServerError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
                        completion(.failure(error))
                    }
                    
                default:
                    let errorMessage = "Unexpected status code: \(httpResponse.statusCode)"
                    let error = NSError(domain: "UnexpectedStatus", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
                    completion(.failure(error))
                }
            }.resume()
        }
        
        attempt(retryCount: maxRetries)
    }

    /// NEW: Handle successful save response
    private func handleSaveSuccess(data: Data, amounts: [Double]) {
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let parentId = json["parent_item_id"] as? String {
                    self.parentItemId = parentId
                    print("✅ Updated parent item ID: \(parentId)")
                }
                
                if let error = json["error"] as? String {
                    self.handleSpecificSaveError(error: error, amounts: amounts)
                } else {
                    self.error = nil
                    self.lastSyncTime = Date()
                    print("✅ Successfully saved \(amounts.count) preset donations")
                    
                    // Refresh the list after successful save
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.fetchPresetDonations()
                    }
                }
            }
        } catch {
            self.error = "Failed to parse response: \(error.localizedDescription)"
            print("❌ Parse error: \(error)")
        }
        
        self.isLoading = false
    }

    /// NEW: Handle save failure with intelligent retry
    private func handleSaveFailure(error: Error, amounts: [Double]) {
        print("❌ Save failed: \(error.localizedDescription)")
        
        // Check if this is a stale data error
        let errorMessage = error.localizedDescription.lowercased()
        if errorMessage.contains("not found") ||
           errorMessage.contains("invalid") ||
           errorMessage.contains("404") {
            
            print("🔄 Detected stale data error, attempting force sync...")
            self.error = "Items were out of sync. Attempting fresh sync..."
            
            // Auto-retry with force sync after a brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.forceSyncPresetDonations(amounts: amounts)
            }
        } else {
            self.error = "Failed to save preset donations: \(error.localizedDescription)"
            self.isLoading = false
        }
    }

    /// NEW: Handle specific backend errors
    private func handleSpecificSaveError(error: String, amounts: [Double]) {
        print("❌ Backend error: \(error)")
        
        if error.contains("not found") || error.contains("invalid") {
            print("🔄 Stale item detected, clearing local state")
            self.parentItemId = nil
            self.error = "Items were out of sync. Please try saving again."
            
            // Auto-retry with cleared state
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.forceSyncPresetDonations(amounts: amounts)
            }
        } else {
            self.error = error
        }
        
        self.isLoading = false
    }

    /// NEW: Force sync method that clears all local state and creates fresh
    private func forceSyncPresetDonations(amounts: [Double]) {
        print("🔄 Force syncing preset donations (clearing stale state)")
        
        // Clear all local state
        parentItemId = nil
        presetDonations = []
        error = nil
        
        guard let url = URL(string: "\(SquareConfig.backendBaseURL)/api/square/catalog/batch-upsert") else {
            error = "Invalid request URL"
            isLoading = false
            return
        }
        
        let requestBody: [String: Any] = [
            "organization_id": authService.organizationId,
            "amounts": amounts,
            "parent_item_name": "Donations",
            "parent_item_description": "Donation preset amounts",
            "force_new": true // This will create completely new items
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            self.error = "Failed to serialize request: \(error.localizedDescription)"
            isLoading = false
            return
        }
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let error = error {
                    self.error = "Force sync failed: \(error.localizedDescription)"
                    self.isLoading = false
                    return
                }
                
                guard let data = data else {
                    self.error = "No response from force sync"
                    self.isLoading = false
                    return
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        if let parentId = json["parent_item_id"] as? String {
                            self.parentItemId = parentId
                            self.error = nil
                            self.lastSyncTime = Date()
                            print("✅ Force sync successful with new parent ID: \(parentId)")
                            
                            // Refresh to get the new items
                            self.fetchPresetDonations()
                        } else if let error = json["error"] as? String {
                            self.error = "Force sync error: \(error)"
                        }
                    }
                } catch {
                    self.error = "Failed to parse force sync response: \(error.localizedDescription)"
                }
                
                self.isLoading = false
            }
        }.resume()
    }
    
    /// Delete a preset donation from the catalog
    func deletePresetDonation(id: String) {
        guard authService.isAuthenticated else {
            error = "Not connected to Square"
            return
        }
        
        isLoading = true
        error = nil
        
        guard let url = URL(string: "\(SquareConfig.backendBaseURL)/api/square/catalog/delete") else {
            error = "Invalid request URL"
            isLoading = false
            return
        }
        
        let requestBody: [String: Any] = [
            "organization_id": authService.organizationId,
            "object_id": id
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            self.error = "Failed to serialize request: \(error.localizedDescription)"
            isLoading = false
            return
        }
        
        print("🗑️ Deleting preset donation: \(id)")
        
        URLSession.shared.dataTaskPublisher(for: request)
            .map { $0.data }
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                guard let self = self else { return }
                self.isLoading = false
                
                switch completion {
                case .finished:
                    self.presetDonations.removeAll { $0.id == id }
                    print("✅ Successfully deleted preset donation")
                case .failure(let error):
                    self.error = "Failed to delete preset donation: \(error.localizedDescription)"
                    print("❌ Delete error: \(error)")
                }
            }, receiveValue: { [weak self] data in
                guard let self = self else { return }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        if let error = json["error"] as? String {
                            self.error = error
                            print("❌ Delete backend error: \(error)")
                        } else {
                            self.error = nil
                            print("✅ Delete successful")
                        }
                    }
                } catch {
                    self.error = "Failed to parse response: \(error.localizedDescription)"
                    print("❌ Delete parse error: \(error)")
                }
            })
            .store(in: &cancellables)
    }
    
    /// Create a donation order with line items (for order-based payment flow)
    func createDonationOrder(amount: Double, isCustom: Bool = false, catalogItemId: String? = nil, completion: @escaping (String?, Error?) -> Void) {
        guard authService.isAuthenticated else {
            error = "Not connected to Square"
            completion(nil, NSError(domain: "com.charitypad", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not connected to Square"]))
            return
        }
        
        isLoading = true
        error = nil
        
        guard let url = URL(string: "\(SquareConfig.backendBaseURL)/api/square/orders/create") else {
            error = "Invalid request URL"
            isLoading = false
            completion(nil, NSError(domain: "com.charitypad", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid request URL"]))
            return
        }
        
        var lineItem: [String: Any]
        
        if isCustom || catalogItemId == nil {
            lineItem = [
                "name": "Custom Donation",
                "quantity": "1",
                "base_price_money": [
                    "amount": Int(amount * 100),
                    "currency": "USD"
                ]
            ]
            print("📝 Creating ad-hoc line item for custom amount: $\(amount)")
        } else {
            lineItem = [
                "catalog_object_id": catalogItemId!,
                "quantity": "1"
            ]
            print("📝 Creating catalog line item for preset amount: $\(amount) (ID: \(catalogItemId!))")
        }
        
        let requestBody: [String: Any] = [
            "organization_id": authService.organizationId,
            "line_items": [lineItem],
            "reference_id": "donation_\(Int(Date().timeIntervalSince1970))",
            "state": "OPEN"
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            self.error = "Failed to serialize request: \(error.localizedDescription)"
            isLoading = false
            completion(nil, error)
            return
        }
        
        URLSession.shared.dataTaskPublisher(for: request)
            .map { $0.data }
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completionResult in
                guard let self = self else { return }
                self.isLoading = false
                
                switch completionResult {
                case .finished:
                    break
                case .failure(let error):
                    self.error = "Failed to create order: \(error.localizedDescription)"
                    completion(nil, error)
                    print("❌ Order creation error: \(error)")
                }
            }, receiveValue: { [weak self] data in
                guard let self = self else { return }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        if let error = json["error"] as? String {
                            self.error = error
                            completion(nil, NSError(domain: "com.charitypad", code: 500, userInfo: [NSLocalizedDescriptionKey: error]))
                            print("❌ Order creation backend error: \(error)")
                        } else if let orderId = json["order_id"] as? String {
                            self.error = nil
                            completion(orderId, nil)
                            print("✅ Order created successfully: \(orderId)")
                        } else {
                            self.error = "Unable to parse order ID from response"
                            completion(nil, NSError(domain: "com.charitypad", code: 500, userInfo: [NSLocalizedDescriptionKey: "Unable to parse order ID from response"]))
                            print("❌ No order ID in response")
                        }
                    }
                } catch {
                    self.error = "Failed to parse response: \(error.localizedDescription)"
                    completion(nil, error)
                    print("❌ Order response parse error: \(error)")
                }
            })
            .store(in: &cancellables)
    }
    
    /// Find catalog item ID for a specific amount
    func catalogItemId(for amount: Double) -> String? {
        return presetDonations.first { $0.amount == amount }?.id
    }
}

// MARK: - Response Types

struct CatalogResponse: Codable {
    let donationItems: [DonationItem]
    let parentItems: [ParentItem]
    let pagination: PaginationInfo?
    let metadata: MetadataInfo?
    
    enum CodingKeys: String, CodingKey {
        case donationItems = "donation_items"
        case parentItems = "parent_items"
        case pagination
        case metadata
    }
}

struct PaginationInfo: Codable {
    let cursor: String?
    let hasMore: Bool
    
    enum CodingKeys: String, CodingKey {
        case cursor
        case hasMore = "has_more"
    }
}

struct MetadataInfo: Codable {
    let totalVariations: Int
    let totalParentItems: Int
    let searchStrategy: String
    
    enum CodingKeys: String, CodingKey {
        case totalVariations = "total_variations"
        case totalParentItems = "total_parent_items"
        case searchStrategy = "search_strategy"
    }
}
