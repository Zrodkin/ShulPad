// ==========================================
// COMPLETE ENHANCED iOS SUBSCRIPTION STORE
// SubscriptionStore.swift
// ==========================================

import Foundation
import Combine
import UIKit

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
    let serviceEndsDate: String? // NEW: When service actually stops
    
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
        case serviceEndsDate = "service_ends_date"
    }
    
    // Enhanced status properties
    var isActive: Bool { status == "active" }
    var isPaused: Bool { status == "paused" }
    var isCanceled: Bool { status == "canceled" }
    var isCanceledButActive: Bool {
            return status == "canceled" && serviceEndsDate != nil && !isExpired
        }
        
    var isExpired: Bool {
        guard let serviceDateString = serviceEndsDate else { return false }
        guard let serviceDate = parseDate(serviceDateString) else { return false }
        return Date() > serviceDate
    }
    
    var daysUntilServiceEnds: Int? {
            guard let serviceDateString = serviceEndsDate,
                  let serviceDate = parseDate(serviceDateString) else { return nil }
            
            let calendar = Calendar.current
            let startOfToday = calendar.startOfDay(for: Date())
            let startOfEndDate = calendar.startOfDay(for: serviceDate)
            let components = calendar.dateComponents([.day], from: startOfToday, to: startOfEndDate)
            return max(0, components.day ?? 0)
        }
    
    // Helper function for date parsing
    private func parseDate(_ dateString: String) -> Date? {
        // Try ISO8601 first (with time)
        if let date = ISO8601DateFormatter().date(from: dateString) {
            return date
        }
        
        // Try simple date format (YYYY-MM-DD)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter.date(from: dateString)
    }
}

struct SubscriptionResponse: Codable {
    let subscription: SubscriptionDetails?
    let error: String?
}

struct SubscriptionStatusResponse: Decodable {
    let subscription: SubscriptionDetails?
    let canUseKiosk: Bool
    let gracePeriodEnds: String?
    let message: String?
    let urgencyLevel: String? // NEW: 'none', 'warning', 'critical'
    let error: String?
    
    enum CodingKeys: String, CodingKey {
        case subscription
        case canUseKiosk = "can_use_kiosk"
        case gracePeriodEnds = "grace_period_ends"
        case message
        case urgencyLevel = "urgency_level"
        case error
    }
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
    @Published var canUseKiosk: Bool = false
    
    // NEW: Enhanced status messaging
    @Published var statusMessage: String?
    @Published var urgencyLevel: UrgencyLevel = .none
    @Published var gracePeriodEnds: Date?
    @Published var daysUntilExpiration: Int?
    
    // NEW: Debouncing properties to prevent infinite loops
    private var refreshTimer: Timer?
    private var isRefreshInProgress = false
    private let refreshDebounceInterval: TimeInterval = 2.0 // 2 second minimum between refreshes
    private var lastRefreshTime: Date = Date.distantPast
    
    private var authService: SquareAuthService?
    private var cancellables = Set<AnyCancellable>()
    
    // Caching
    private let cacheKey = "cached_subscription_status"
    private let cacheTimeKey = "subscription_cache_time"
    private let cacheValidityDuration: TimeInterval = 300 // 5 minutes
    
    enum UrgencyLevel: String, CaseIterable {
        case none = "none"
        case warning = "warning"
        case critical = "critical"
        
        var color: UIColor {
            switch self {
            case .none: return .systemBlue
            case .warning: return .systemOrange
            case .critical: return .systemRed
            }
        }
        
        var systemName: String {
            switch self {
            case .none: return "info.circle"
            case .warning: return "exclamationmark.triangle"
            case .critical: return "exclamationmark.triangle.fill"
            }
        }
    }
    
    init() {
        setupNotifications()
        loadCachedSubscription()
    }
    
    // MARK: - Dependency Injection
    func setAuthService(_ authService: SquareAuthService) {
        self.authService = authService
        print("✅ SubscriptionStore: Auth service injected")
    }
    
    // MARK: - Fixed Setup Notifications (reduced frequency)
    private func setupNotifications() {
        // Only listen to external events, not internal status changes
        NotificationCenter.default.publisher(for: .subscriptionActivated)
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshSubscriptionStatus()
            }
            .store(in: &cancellables)
            
        NotificationCenter.default.publisher(for: .refreshSubscriptionStatus)
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshSubscriptionStatus()
            }
            .store(in: &cancellables)
    
        // REMOVED: subscriptionStatusChanged listener to prevent loops
    }
    
    // MARK: - Fixed Enhanced Status Refresh with Debouncing
    func refreshSubscriptionStatus() {
        // Prevent multiple simultaneous refreshes
        guard !isRefreshInProgress else {
            print("⚠️ Refresh already in progress, skipping...")
            return
        }
        
        // Debounce rapid successive calls
        let timeSinceLastRefresh = Date().timeIntervalSince(lastRefreshTime)
        guard timeSinceLastRefresh >= refreshDebounceInterval else {
            print("⚠️ Refresh called too soon (within \(refreshDebounceInterval)s), debouncing...")
            
            // Cancel existing timer and create a new one
            refreshTimer?.invalidate()
            refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshDebounceInterval - timeSinceLastRefresh, repeats: false) { [weak self] _ in
                self?.performRefresh()
            }
            return
        }
        
        performRefresh()
    }
    
    private func performRefresh() {
        guard let authService = authService,
              let merchantId = authService.merchantId,
              !merchantId.isEmpty else {
            print("❌ SubscriptionStore: Auth service or merchant ID not available for status refresh.")
            return
        }
        
        // Mark refresh as in progress
        isRefreshInProgress = true
        lastRefreshTime = Date()
        
        let urlString = "\(SquareConfig.backendBaseURL)/api/subscriptions/status?merchant_id=\(merchantId)"
        guard let url = URL(string: urlString) else {
            print("❌ SubscriptionStore: Invalid status URL")
            isRefreshInProgress = false
            return
        }
        
        isLoading = true
        error = nil
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                // Always mark refresh as complete
                self.isRefreshInProgress = false
                self.isLoading = false
                
                if let error = error {
                    self.handleNetworkError(error)
                    return
                }
                
                guard let data = data else {
                    self.error = "No data received from status endpoint"
                    return
                }
                
                do {
                    let statusResponse = try JSONDecoder().decode(SubscriptionStatusResponse.self, from: data)
                    
                    // Update all subscription state
                    self.subscription = statusResponse.subscription
                    self.canUseKiosk = statusResponse.canUseKiosk
                    self.hasActiveSubscription = statusResponse.subscription?.isActive ?? false
                    self.error = statusResponse.error
                    self.statusMessage = statusResponse.message
                    self.urgencyLevel = UrgencyLevel(rawValue: statusResponse.urgencyLevel ?? "none") ?? .none
                    
                    // Parse grace period end date
                    if let gracePeriodString = statusResponse.gracePeriodEnds {
                        self.gracePeriodEnds = self.parseDate(gracePeriodString)
                        self.calculateDaysUntilExpiration()
                    } else if let serviceEndsString = self.subscription?.serviceEndsDate {
                        self.gracePeriodEnds = self.parseDate(serviceEndsString)
                        self.calculateDaysUntilExpiration()
                    } else {
                        self.gracePeriodEnds = nil
                        self.daysUntilExpiration = nil
                    }
                    
                    if let subscription = statusResponse.subscription {
                        self.cacheSubscriptionStatus(subscription)
                        print("✅ SubscriptionStore: Status refreshed - \(subscription.status)")
                    } else {
                        self.clearCachedSubscription()
                        print("📭 SubscriptionStore: No subscription found")
                    }
                    
                } catch let decodingError {
                    self.error = "Failed to parse subscription status"
                    self.subscription = nil
                    self.hasActiveSubscription = false
                    self.canUseKiosk = false
                    self.clearCachedSubscription()
                    print("❌ SubscriptionStore: Parse error - \(decodingError)")
                }
                
                // REMOVED: Don't call objectWillChange.send() AND post notification
                // This was causing the infinite loop!
                // self.objectWillChange.send()
                
                // Only post notification for external listeners, not internal UI updates
                // NotificationCenter.default.post(name: .subscriptionStatusChanged, object: nil)
            }
        }.resume()
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
        guard let authService = authService, let merchantId = authService.merchantId, !merchantId.isEmpty else {
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
        
        let requestPayload = CreateSubscriptionRequest(
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
            urlRequest.httpBody = try JSONEncoder().encode(requestPayload)
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
    
    // MARK: - Enhanced Cancellation
    func cancelSubscription(completion: @escaping (Bool, String?) -> Void) {
        guard let authService = authService, let merchantId = authService.merchantId else {
            completion(false, "Authentication service or merchant ID not available")
            return
        }
        
        let urlString = "\(SquareConfig.backendBaseURL)/api/subscriptions/cancel"
        guard let url = URL(string: urlString) else {
            completion(false, "Invalid request URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = ["merchant_id": merchantId]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion(false, "Failed to prepare cancellation request")
            return
        }
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(false, "Network error: \(error.localizedDescription)")
                    return
                }
                
                guard let data = data else {
                    completion(false, "No response received from the server")
                    return
                }
                
                do {
                    // Parse the enhanced cancellation response
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        if let success = json["success"] as? Bool, success {
                            // Extract professional message from the server
                            var message = "Your subscription has been cancelled successfully."
                            
                            // Try to get message from subscription object first
                            if let subscriptionData = json["subscription"] as? [String: Any],
                               let serverMessage = subscriptionData["message"] as? String {
                                message = serverMessage
                            } else if let directMessage = json["message"] as? String {
                                message = directMessage
                            }
                            
                            // Refresh status to get updated information
                            self?.refreshSubscriptionStatus()
                            completion(true, message)
                        } else {
                            let errorMessage = json["error"] as? String ?? "An unknown error occurred during cancellation."
                            completion(false, errorMessage)
                        }
                    } else {
                        completion(false, "Invalid response format from server.")
                    }
                } catch {
                    completion(false, "Failed to process the cancellation response.")
                }
            }
        }.resume()
    }
    
    // MARK: - Pause Subscription
    func pauseSubscription(reason: String = "Customer request", completion: @escaping (Bool, String?) -> Void) {
        guard let authService = authService, let merchantId = authService.merchantId else {
            completion(false, "Authentication service or merchant ID not available")
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
        
        let requestBody = ["merchant_id": merchantId, "pause_reason": reason]
        
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
                
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    self?.refreshSubscriptionStatus()
                    completion(true, "Subscription paused successfully")
                } else {
                    completion(false, "Failed to pause subscription")
                }
            }
        }.resume()
    }
    
    // MARK: - Resume Subscription
    func resumeSubscription(completion: @escaping (Bool, String?) -> Void) {
        guard let authService = authService, let merchantId = authService.merchantId else {
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
                
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    self?.refreshSubscriptionStatus()
                    completion(true, "Subscription resumed successfully")
                } else {
                    completion(false, "Failed to resume subscription")
                }
            }
        }.resume()
    }
    
    // MARK: - Change Subscription Plan
    func changePlan(newPlanType: String, newDeviceCount: Int, completion: @escaping (Bool, String?) -> Void) {
        guard let authService = authService, let merchantId = authService.merchantId else {
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
            "merchant_id": merchantId,
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
                
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    self?.refreshSubscriptionStatus()
                    completion(true, "Plan changed successfully")
                } else {
                    completion(false, "Failed to change plan")
                }
            }
        }.resume()
    }
    
    // MARK: - Helper Methods
    private func calculateDaysUntilExpiration() {
        guard let endDate = gracePeriodEnds ?? (subscription?.serviceEndsDate.flatMap { parseDate($0) }) else {
            daysUntilExpiration = nil
            return
        }
        
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let startOfEndDate = calendar.startOfDay(for: endDate)
        let components = calendar.dateComponents([.day], from: startOfToday, to: startOfEndDate)
        daysUntilExpiration = max(0, components.day ?? 0)
    }
    
    private func parseDate(_ dateString: String) -> Date? {
        // Try ISO8601 first (with time)
        if let date = ISO8601DateFormatter().date(from: dateString) {
            return date
        }
        
        // Try simple date format (YYYY-MM-DD)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter.date(from: dateString)
    }
    
    // MARK: - Professional Status Messages
    func getStatusDisplayInfo() -> (title: String, message: String, actionText: String?) {
        guard let subscription = subscription else {
            return (
                title: "No Subscription",
                message: "Subscribe to start accepting payments with your kiosk.",
                actionText: "Subscribe Now"
            )
        }
        
        switch subscription.status {
        case "active":
            return (
                title: "Active Subscription",
                message: "Your \(subscription.planType.capitalized) plan is active and ready to accept payments.",
                actionText: nil
            )
            
        case "paused":
            return (
                title: "Subscription Paused",
                message: "Your subscription is paused. Resume to continue accepting payments.",
                actionText: "Resume Subscription"
            )
            
        case "canceled":
            if let days = daysUntilExpiration {
                if days == 0 {
                    return (
                        title: "Subscription Expired",
                        message: "Your subscription has ended. Resubscribe to restore your payment kiosk.",
                        actionText: "Resubscribe Now"
                    )
                } else {
                    return (
                        title: "Subscription Ending Soon",
                        message: "Your access will end in \(days) day\(days == 1 ? "" : "s"). Resubscribe to avoid service interruption.",
                        actionText: "Resubscribe"
                    )
                }
            } else {
                return (
                    title: "Subscription Cancelled",
                    message: "Your subscription has been cancelled. You can resubscribe at any time.",
                    actionText: "Resubscribe"
                )
            }
            
        default:
            return (
                title: "Subscription Status Unknown",
                message: "We're unable to determine your subscription status. Please check your connection or contact support.",
                actionText: "Retry"
            )
        }
    }
    
    func formatServiceEndDate() -> String? {
        guard let subscription = subscription,
              let serviceEndsString = subscription.serviceEndsDate,
              let serviceDate = parseDate(serviceEndsString) else {
            return nil
        }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: serviceDate)
    }
    
    // MARK: - URL Generation
    func getCheckoutURL(planType: String = "monthly", deviceCount: Int = 1, email: String = "") -> URL? {
        print("🔍 Attempting to generate checkout URL...")
        guard let authService = authService else {
            print("❌ getCheckoutURL failed: authService not available.")
            return nil
        }
        
        guard let merchantId = authService.merchantId, !merchantId.isEmpty else {
            print("❌ getCheckoutURL failed: merchantId is not available.")
            return nil
        }
        
        let baseURLString = "\(SquareConfig.backendBaseURL)/subscription/checkout"
        var components = URLComponents(string: baseURLString)
        components?.queryItems = [
            URLQueryItem(name: "merchant_id", value: merchantId),
            URLQueryItem(name: "plan", value: planType),
            URLQueryItem(name: "devices", value: String(deviceCount)),
            URLQueryItem(name: "email", value: email)
        ]
        
        let finalURL = components?.url
        print("✅ Constructed checkout URL: \(finalURL?.absoluteString ?? "nil")")
        
        return finalURL
    }
    
    func getManagementURL() -> URL? {
        print("🔍 Attempting to generate management URL...")
        guard let authService = authService else {
            print("❌ getManagementURL failed: authService not available.")
            return nil
        }
        
        guard let merchantId = authService.merchantId, !merchantId.isEmpty else {
            print("❌ getManagementURL failed: merchantId is not available.")
            return nil
        }
        
        var components = URLComponents(string: "\(SquareConfig.backendBaseURL)/subscription/manage")
        components?.queryItems = [
            URLQueryItem(name: "merchant_id", value: merchantId)
        ]
        
        let finalURL = components?.url
        print("✅ Constructed management URL: \(finalURL?.absoluteString ?? "nil")")
        
        return finalURL
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
        
        // Only use cache if it's not stale
        guard Date().timeIntervalSince(cacheTime) < cacheValidityDuration else {
            print("📭 Cached subscription is stale, ignoring")
            clearCachedSubscription()
            return
        }
        
        do {
            let cachedSubscription = try JSONDecoder().decode(SubscriptionDetails.self, from: data)
            print("📦 Using cached subscription status")
            self.subscription = cachedSubscription
            self.hasActiveSubscription = cachedSubscription.isActive
            // Recalculate expiration on load
            self.calculateDaysUntilExpiration()
        } catch {
            print("⚠️ Failed to load cached subscription: \(error)")
            clearCachedSubscription()
        }
    }
    
    private func clearCachedSubscription() {
        UserDefaults.standard.removeObject(forKey: cacheKey)
        UserDefaults.standard.removeObject(forKey: cacheTimeKey)
        
        // Also clear related state
        self.gracePeriodEnds = nil
        self.daysUntilExpiration = nil
        self.statusMessage = nil
        self.urgencyLevel = .none
        
        print("🗑️ Cached subscription and related state cleared")
    }
    
    // MARK: - Error Handling
    private func handleNetworkError(_ error: Error) {
        // Use a more robust check for network-related errors
        let nsError = error as NSError
        if nsError.domain == URLError.errorDomain && [
            URLError.notConnectedToInternet.rawValue,
            URLError.timedOut.rawValue,
            URLError.cannotFindHost.rawValue,
            URLError.networkConnectionLost.rawValue
        ].contains(nsError.code) {
            self.error = "No internet connection. Using last known status."
            loadCachedSubscription() // Attempt to load from cache as fallback
        } else {
            self.error = "Network error: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Cleanup
    deinit {
        refreshTimer?.invalidate()
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

