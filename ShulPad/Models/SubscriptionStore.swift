// SubscriptionStore.swift - FIXED VERSION
import Foundation
import Combine

// MARK: - Subscription Models
struct SubscriptionDetails: Codable, Identifiable {
    let id: String
    let status: String
    let planType: String
    let deviceCount: Int
    let totalPrice: Double
    let nextBillingDate: String
    let cardLastFour: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case status
        case planType = "plan_type"
        case deviceCount = "device_count"
        case totalPrice = "total_price"
        case nextBillingDate = "next_billing_date"
        case cardLastFour = "card_last_four"
    }
}

struct SubscriptionResponse: Codable {
    let subscription: SubscriptionDetails?
    let error: String?
}

// MARK: - Subscription Store
class SubscriptionStore: ObservableObject {
    @Published var subscription: SubscriptionDetails?
    @Published var isLoading = false
    @Published var error: String?
    @Published var hasActiveSubscription = false
    
    private var authService: SquareAuthService?
    private var cancellables = Set<AnyCancellable>()
    
    // FIXED: Remove the default parameter and require injection
    init() {
        setupNotifications()
    }
    
    // MARK: - Dependency Injection
    func setAuthService(_ authService: SquareAuthService) {
        self.authService = authService
        print("✅ SubscriptionStore: Auth service injected")
    }
    
    // MARK: - Setup Notifications
    private func setupNotifications() {
        // Listen for subscription activation
        NotificationCenter.default.publisher(for: .subscriptionActivated)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.refreshSubscriptionStatus()
                }
            }
            .store(in: &cancellables)
            
        // Listen for refresh requests
        NotificationCenter.default.publisher(for: .refreshSubscriptionStatus)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.refreshSubscriptionStatus()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Check Subscription Status
    func refreshSubscriptionStatus() {
        print("🔄 Refreshing subscription status...")
        
        guard let authService = authService else {
            print("⚠️ Auth service not available")
            error = "Authentication service not available"
            return
        }
        
        guard !authService.organizationId.isEmpty else {
            print("⚠️ No organization ID available")
            error = "No organization ID available"
            return
        }
        
        isLoading = true
        error = nil
        
        let urlString = "\(SquareConfig.backendBaseURL)/api/subscriptions/status?organization_id=\(authService.organizationId)"
        
        guard let url = URL(string: urlString) else {
            DispatchQueue.main.async {
                self.error = "Invalid URL"
                self.isLoading = false
            }
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    print("❌ Network error: \(error.localizedDescription)")
                    self?.handleNetworkError(error)
                    return
                }
                
                guard let data = data else {
                    self?.error = "No data received"
                    return
                }
                
                do {
                    let subscriptionResponse = try JSONDecoder().decode(SubscriptionResponse.self, from: data)
                    
                    if let subscription = subscriptionResponse.subscription {
                        print("✅ Subscription found: \(subscription.status)")
                        self?.subscription = subscription
                        self?.hasActiveSubscription = subscription.status == "active"
                        self?.cacheSubscriptionStatus(subscription)
                    } else {
                        print("ℹ️ No active subscription")
                        self?.subscription = nil
                        self?.hasActiveSubscription = false
                    }
                    
                    if let error = subscriptionResponse.error {
                        self?.error = error
                    }
                } catch {
                    print("❌ JSON decode error: \(error)")
                    self?.error = "Failed to parse subscription data"
                    // Try to load cached data on parse error
                    self?.loadCachedSubscription()
                }
            }
        }.resume()
    }
    
    // MARK: - Cancel Subscription
    func cancelSubscription(completion: @escaping (Bool, String?) -> Void) {
        guard let authService = authService else {
            completion(false, "Authentication service not available")
            return
        }
        
        guard !authService.organizationId.isEmpty else {
            completion(false, "No organization ID available")
            return
        }
        
        let urlString = "\(SquareConfig.backendBaseURL)/api/subscriptions/cancel"
        guard let url = URL(string: urlString) else {
            completion(false, "Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = ["organization_id": authService.organizationId]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion(false, "Failed to encode request")
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(false, "Network error: \(error.localizedDescription)")
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 200 {
                    self.hasActiveSubscription = false
                    self.subscription = nil
                    // Clear cached subscription
                    self.clearCachedSubscription()
                    completion(true, nil)
                } else {
                    completion(false, "Failed to cancel subscription")
                }
            }
        }.resume()
    }
    
    // MARK: - Generate URLs (Simplified - no email)
    func getCheckoutURL() -> URL? {
        return authService?.getSubscriptionCheckoutURL()
    }
    
    func getManagementURL() -> URL? {
        return authService?.getSubscriptionManagementURL()
    }
    
    // MARK: - Caching Support
    private func cacheSubscriptionStatus(_ subscription: SubscriptionDetails) {
        do {
            let data = try JSONEncoder().encode(subscription)
            UserDefaults.standard.set(data, forKey: "cached_subscription_status")
            UserDefaults.standard.set(Date(), forKey: "subscription_cache_time")
            print("💾 Subscription status cached")
        } catch {
            print("⚠️ Failed to cache subscription status: \(error)")
        }
    }
    
    private func loadCachedSubscription() {
        guard let data = UserDefaults.standard.data(forKey: "cached_subscription_status"),
              let cacheTime = UserDefaults.standard.object(forKey: "subscription_cache_time") as? Date else {
            print("📭 No cached subscription found")
            return
        }
        
        // Only use cache if less than 5 minutes old
        guard Date().timeIntervalSince(cacheTime) < 300 else {
            print("📭 Cached subscription too old, ignoring")
            return
        }
        
        do {
            let cachedSubscription = try JSONDecoder().decode(SubscriptionDetails.self, from: data)
            print("📦 Using cached subscription status")
            self.subscription = cachedSubscription
            self.hasActiveSubscription = cachedSubscription.status == "active"
            self.error = "Using cached subscription status (offline)"
        } catch {
            print("⚠️ Failed to load cached subscription: \(error)")
        }
    }
    
    private func clearCachedSubscription() {
        UserDefaults.standard.removeObject(forKey: "cached_subscription_status")
        UserDefaults.standard.removeObject(forKey: "subscription_cache_time")
        print("🗑️ Cached subscription cleared")
    }
    
    // MARK: - Error Handling
    private func handleNetworkError(_ error: Error) {
        if error.localizedDescription.contains("offline") ||
           error.localizedDescription.contains("Internet connection") {
            // Load cached subscription if available
            loadCachedSubscription()
            if self.error == nil {
                self.error = "Using cached subscription status (offline)"
            }
        } else {
            self.error = "Network error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let subscriptionActivated = Notification.Name("SubscriptionActivated")
    static let subscriptionCancelled = Notification.Name("SubscriptionCancelled")
   
}
