// ==========================================
// UPDATED iOS SUBSCRIPTION STORE
// SubscriptionStore.swift
// ==========================================

import Foundation
import Combine

// MARK: - Enhanced Subscription Models
struct SubscriptionDetails: Codable, Identifiable {
    let id: String
    let status: String
    let planType: String
    let deviceCount: Int
    let totalPrice: Double
    let nextBillingDate: String?
    let cardLastFour: String?
    let startDate: String?
    let canceledDate: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case status
        case planType = "plan_type"
        case deviceCount = "device_count"
        case totalPrice = "total_price"
        case nextBillingDate = "next_billing_date"
        case cardLastFour = "card_last_four"
        case startDate = "start_date"
        case canceledDate = "canceled_date"
    }
    
    var isActive: Bool {
        return status == "active"
    }
    
    var isPaused: Bool {
        return status == "paused"
    }
    
    var isCanceled: Bool {
        return status == "canceled"
    }
}

struct SubscriptionResponse: Codable {
    let subscription: SubscriptionDetails?
    let error: String?
}

struct CreateSubscriptionRequest: Codable {
    let merchantId: String
    let planType: String
    let deviceCount: Int
    let customerEmail: String
    let sourceId: String
    let promoCode: String?
    
    enum CodingKeys: String, CodingKey {
        case merchantId = "merchant_id"
        case planType = "plan_type"
        case deviceCount = "device_count"
        case customerEmail = "customer_email"
        case sourceId = "source_id"
        case promoCode = "promo_code"
    }
}

// MARK: - Enhanced Subscription Store
class SubscriptionStore: ObservableObject {
    @Published var subscription: SubscriptionDetails?
    @Published var isLoading = false
    @Published var error: String?
    @Published var hasActiveSubscription = false
    @Published var subscriptionHistory: [SubscriptionDetails] = []
    
    private var authService: SquareAuthService?
    private var cancellables = Set<AnyCancellable>()
    
    // Caching
    private let cacheKey = "cached_subscription_status"
    private let cacheTimeKey = "subscription_cache_time"
    private let cacheValidityDuration: TimeInterval = 300 // 5 minutes
    
    init() {
        setupNotifications()
        loadCachedSubscription()
    }
    
    // MARK: - Dependency Injection
    func setAuthService(_ authService: SquareAuthService) {
        self.authService = authService
        print("✅ SubscriptionStore: Auth service injected")
    }
    
    // MARK: - Setup Notifications
    private func setupNotifications() {
        NotificationCenter.default.publisher(for: .subscriptionActivated)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.refreshSubscriptionStatus()
                }
            }
            .store(in: &cancellables)
            
        NotificationCenter.default.publisher(for: .refreshSubscriptionStatus)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.refreshSubscriptionStatus()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Create Subscription
    func createSubscription(
        planType: String,
        deviceCount: Int,
        customerEmail: String,
        sourceId: String,
        promoCode: String? = nil,
        completion: @escaping (Bool, String?) -> Void
    ) {
        guard let authService = authService else {
            completion(false, "Authentication service not available")
            return
        }
        
   
        guard let merchantId = authService.merchantId, !merchantId.isEmpty else {
            completion(false, "No merchant ID available")
            return
        }
        
        let urlString = "\(SquareConfig.backendBaseURL)/api/subscriptions/create"
        guard let url = URL(string: urlString) else {
            completion(false, "Invalid URL")
            return
        }
        
        isLoading = true
        error = nil
        
      
        let request = CreateSubscriptionRequest(
            merchantId: merchantId,
            planType: planType,
            deviceCount: deviceCount,
            customerEmail: customerEmail,
            sourceId: sourceId,
            promoCode: promoCode
        )
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            urlRequest.httpBody = try JSONEncoder().encode(request)
        } catch {
            DispatchQueue.main.async {
                self.isLoading = false
                completion(false, "Failed to encode request")
            }
            return
        }
        
        URLSession.shared.dataTask(with: urlRequest) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.error = "Network error: \(error.localizedDescription)"
                    completion(false, self?.error)
                    return
                }
                
                guard let data = data else {
                    self?.error = "No data received"
                    completion(false, "No data received")
                    return
                }
                
                do {
                    let response = try JSONDecoder().decode(SubscriptionResponse.self, from: data)
                    
                    if let subscription = response.subscription {
                        self?.subscription = subscription
                        self?.hasActiveSubscription = subscription.isActive
                        self?.cacheSubscriptionStatus(subscription)
                        completion(true, nil)
                    } else {
                        self?.error = response.error ?? "Unknown error"
                        completion(false, self?.error)
                    }
                } catch {
                    self?.error = "Failed to parse response: \(error.localizedDescription)"
                    completion(false, self?.error)
                }
            }
        }.resume()
    }
    
    // MARK: - Refresh Subscription Status
    func refreshSubscriptionStatus() {
        guard let authService = authService else {
            print("❌ SubscriptionStore: Auth service not available")
            return
        }
        
        // ✅ FIX: Use merchantId instead of organizationId
        guard let merchantId = authService.merchantId, !merchantId.isEmpty else {
            print("❌ SubscriptionStore: No merchant ID available")
            return
        }
        
        // ✅ FIX: Use merchant_id in URL (this was already correct)
        let urlString = "\(SquareConfig.backendBaseURL)/api/subscriptions/status?merchant_id=\(merchantId)"
        guard let url = URL(string: urlString) else {
            print("❌ SubscriptionStore: Invalid status URL")
            return
        }
        
        isLoading = true
        error = nil
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.handleNetworkError(error)
                    return
                }
                
                guard let data = data else {
                    self?.error = "No data received"
                    return
                }
                
                do {
                    let response = try JSONDecoder().decode(SubscriptionResponse.self, from: data)
                    
                    if let subscription = response.subscription {
                        self?.subscription = subscription
                        self?.hasActiveSubscription = subscription.isActive
                        self?.cacheSubscriptionStatus(subscription)
                        self?.error = nil
                        
                        print("✅ SubscriptionStore: Status refreshed - \(subscription.status)")
                    } else {
                        self?.subscription = nil
                        self?.hasActiveSubscription = false
                        self?.clearCachedSubscription()
                        print("📭 SubscriptionStore: No active subscription")
                    }
                } catch {
                    self?.error = "Failed to parse response: \(error.localizedDescription)"
                    print("❌ SubscriptionStore: Parse error - \(error)")
                }
            }
        }.resume()
    }
    
    // MARK: - Pause Subscription
    func pauseSubscription(reason: String = "Customer request", completion: @escaping (Bool, String?) -> Void) {
        guard let authService = authService else {
            completion(false, "Authentication service not available")
            return
        }
        
        guard let merchantId = authService.merchantId else {
            completion(false, "No merchant ID available")
            return
        }
        
        let urlString = "\(SquareConfig.backendBaseURL)/api/subscriptions/pause"
        guard let url = URL(string: urlString) else {
            completion(false, "Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = [
            "merchant_id": merchantId,
            "pause_reason": reason
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion(false, "Failed to encode request")
            return
        }
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(false, "Network error: \(error.localizedDescription)")
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 200 {
                    self?.refreshSubscriptionStatus()
                    completion(true, nil)
                } else {
                    completion(false, "Failed to pause subscription")
                }
            }
        }.resume()
    }
    
    // MARK: - Resume Subscription
    func resumeSubscription(completion: @escaping (Bool, String?) -> Void) {
        guard let authService = authService else {
            completion(false, "Authentication service not available")
            return
        }
        
        guard let merchantId = authService.merchantId else {  // ✅ CHANGE
            completion(false, "No merchant ID available")
            return
        }
        
        let urlString = "\(SquareConfig.backendBaseURL)/api/subscriptions/resume"
        guard let url = URL(string: urlString) else {
            completion(false, "Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = ["merchant_id": merchantId]  // ✅ CHANGED
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion(false, "Failed to encode request")
            return
        }
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(false, "Network error: \(error.localizedDescription)")
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 200 {
                    self?.refreshSubscriptionStatus()
                    completion(true, nil)
                } else {
                    completion(false, "Failed to resume subscription")
                }
            }
        }.resume()
    }
    
    // MARK: - Change Subscription Plan
    func changePlan(newPlanType: String, newDeviceCount: Int, completion: @escaping (Bool, String?) -> Void) {
        guard let authService = authService else {
            completion(false, "Authentication service not available")
            return
        }
        
        guard let merchantId = authService.merchantId else {  // ✅ CHANGE
            completion(false, "No merchant ID available")
            return
        }
        
        let urlString = "\(SquareConfig.backendBaseURL)/api/subscriptions/change-plan"
        guard let url = URL(string: urlString) else {
            completion(false, "Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = [
            "merchant_id": merchantId,              // ✅ CHANGED
            "new_plan_type": newPlanType,
            "new_device_count": newDeviceCount
        ] as [String : Any]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion(false, "Failed to encode request")
            return
        }
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(false, "Network error: \(error.localizedDescription)")
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 200 {
                    self?.refreshSubscriptionStatus()
                    completion(true, nil)
                } else {
                    completion(false, "Failed to change plan")
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
        
        guard let merchantId = authService.merchantId else {  // ✅ CHANGE
            completion(false, "No merchant ID available")
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
        
        let requestBody = ["merchant_id": merchantId]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion(false, "Failed to encode request")
            return
        }
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(false, "Network error: \(error.localizedDescription)")
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 200 {
                    self?.hasActiveSubscription = false
                    self?.subscription = nil
                    self?.clearCachedSubscription()
                    completion(true, nil)
                } else {
                    completion(false, "Failed to cancel subscription")
                }
            }
        }.resume()
    }
    
    // MARK: - Generate URLs
    func getCheckoutURL(planType: String = "monthly", deviceCount: Int = 1, email: String = "") -> URL? {
        guard let authService = authService else { return nil }
        
        // ✅ FIX: Use merchantId instead of organizationId
        guard let merchantId = authService.merchantId else { return nil }
        
        let baseURLString = "\(SquareConfig.backendBaseURL)/subscription/checkout"
        print("🔍 Base URL String: \(baseURLString)")
        
        var components = URLComponents(string: baseURLString)
        components?.queryItems = [
            URLQueryItem(name: "merchant_id", value: merchantId),  // ✅ CHANGED: org_id → merchant_id
            URLQueryItem(name: "plan", value: planType),
            URLQueryItem(name: "devices", value: String(deviceCount)),
            URLQueryItem(name: "email", value: email)
        ]
        
        let finalURL = components?.url
        print("🌐 Final checkout URL: \(finalURL?.absoluteString ?? "nil")")
        
        return finalURL
    }
    
    func getManagementURL() -> URL? {
        guard let authService = authService else { return nil }
        
        var components = URLComponents(string: "\(SquareConfig.backendBaseURL)/subscription/manage")
        components?.queryItems = [
            URLQueryItem(name: "merchant_id", value: authService.merchantId)
        ]
        
        return components?.url
    }
    
    // MARK: - Caching Support
    private func cacheSubscriptionStatus(_ subscription: SubscriptionDetails) {
        do {
            let data = try JSONEncoder().encode(subscription)
            UserDefaults.standard.set(data, forKey: cacheKey)
            UserDefaults.standard.set(Date(), forKey: cacheTimeKey)
            print("💾 Subscription status cached")
        } catch {
            print("⚠️ Failed to cache subscription status: \(error)")
        }
    }
    
    private func loadCachedSubscription() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let cacheTime = UserDefaults.standard.object(forKey: cacheTimeKey) as? Date else {
            print("📭 No cached subscription found")
            return
        }
        
        // Only use cache if less than validity duration
        guard Date().timeIntervalSince(cacheTime) < cacheValidityDuration else {
            print("📭 Cached subscription too old, ignoring")
            clearCachedSubscription()
            return
        }
        
        do {
            let cachedSubscription = try JSONDecoder().decode(SubscriptionDetails.self, from: data)
            print("📦 Using cached subscription status")
            self.subscription = cachedSubscription
            self.hasActiveSubscription = cachedSubscription.isActive
        } catch {
            print("⚠️ Failed to load cached subscription: \(error)")
            clearCachedSubscription()
        }
    }
    
    private func clearCachedSubscription() {
        UserDefaults.standard.removeObject(forKey: cacheKey)
        UserDefaults.standard.removeObject(forKey: cacheTimeKey)
        print("🗑️ Cached subscription cleared")
    }
    
    // MARK: - Error Handling
    private func handleNetworkError(_ error: Error) {
        if error.localizedDescription.contains("offline") ||
           error.localizedDescription.contains("Internet connection") {
            // Load cached subscription if available
            loadCachedSubscription()
            if self.subscription == nil {
                self.error = "No internet connection. Please check your network."
            }
        } else {
            self.error = "Network error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Helper Extensions
extension Encodable {
    func asDictionary() throws -> [String: Any] {
        let data = try JSONEncoder().encode(self)
        guard let dictionary = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any] else {
            throw NSError(domain: "EncodingError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to convert to dictionary"])
        }
        return dictionary
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let subscriptionActivated = Notification.Name("SubscriptionActivated")
    static let subscriptionCancelled = Notification.Name("SubscriptionCancelled")
    static let subscriptionPaused = Notification.Name("SubscriptionPaused")
    static let subscriptionResumed = Notification.Name("SubscriptionResumed")
    static let deviceConflictDetected = Notification.Name("DeviceConflictDetected")
}
