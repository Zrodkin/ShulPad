import Foundation
import Combine

// MARK: - Models matching backend responses

struct StripeCheckoutSession: Codable {
    let url: String
    let sessionId: String
    
    enum CodingKeys: String, CodingKey {
        case url
        case sessionId = "session_id"
    }
}

struct StripeSubscriptionStatus: Codable {
    let hasSubscription: Bool
    let status: String?
    let canUseKiosk: Bool
    let trialEnd: String?
    let currentPeriodEnd: String?
    let cancelAtPeriodEnd: Bool?
    let daysRemaining: Int?
    let stripeCustomerId: String?
    let stripeSubscriptionId: String?
    
    enum CodingKeys: String, CodingKey {
        case hasSubscription = "has_subscription"
        case status
        case canUseKiosk = "can_use_kiosk"
        case trialEnd = "trial_end"
        case currentPeriodEnd = "current_period_end"
        case cancelAtPeriodEnd = "cancel_at_period_end"
        case daysRemaining = "days_remaining"
        case stripeCustomerId = "stripe_customer_id"
        case stripeSubscriptionId = "stripe_subscription_id"
    }
}

struct StripePortalSession: Codable {
    let url: String
}

// MARK: - Stripe Subscription Store

class StripeSubscriptionStore: ObservableObject {
    // Published properties for UI
    @Published var isLoading = false
    @Published var error: String?
    
    // Subscription state
    @Published var hasSubscription = false
    @Published var canUseKiosk = false
    @Published var subscriptionStatus: String?
    @Published var isTrialing = false
    @Published var daysRemaining: Int?
    @Published var currentPeriodEnd: Date?
    
    // Dependencies
    private var organizationId: String?
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupNotifications()
    }
    
    // MARK: - Setup
    
    func setOrganizationId(_ id: String) {
        self.organizationId = id
        print("✅ StripeSubscriptionStore: Organization ID set to \(id)")
    }
    
    private func setupNotifications() {
        // Listen for when we need to refresh subscription status
        NotificationCenter.default.publisher(for: .subscriptionStatusChanged)
            .sink { [weak self] _ in
                self?.checkSubscriptionStatus()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Create Checkout Session
    
    func createCheckoutSession(email: String? = nil, completion: @escaping (URL?, String?) -> Void) {
        guard let organizationId = organizationId else {
            completion(nil, "Organization ID not set")
            return
        }
        
        isLoading = true
        error = nil
        
        let url = URL(string: "\(SquareConfig.backendBaseURL)/api/stripe/create-checkout-session")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var body: [String: Any] = ["organization_id": organizationId]
        if let email = email {
            body["merchant_email"] = email
        }
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.error = error.localizedDescription
                    completion(nil, error.localizedDescription)
                    return
                }
                
                guard let data = data else {
                    let error = "No data received"
                    self?.error = error
                    completion(nil, error)
                    return
                }
                
                // Check for error response
                if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    self?.error = errorResponse.error
                    completion(nil, errorResponse.error)
                    return
                }
                
                // Parse success response
                do {
                    let session = try JSONDecoder().decode(StripeCheckoutSession.self, from: data)
                    if let checkoutURL = URL(string: session.url) {
                        print("✅ Checkout session created: \(session.sessionId)")
                        completion(checkoutURL, nil)
                    } else {
                        throw URLError(.badURL)
                    }
                } catch {
                    self?.error = "Invalid response"
                    completion(nil, "Invalid response")
                }
            }
        }.resume()
    }
    
    // MARK: - Check Subscription Status
    
    func checkSubscriptionStatus() {
        guard let organizationId = organizationId else {
            print("❌ No organization ID set")
            return
        }
        
        isLoading = true
        error = nil
        
        let urlString = "\(SquareConfig.backendBaseURL)/api/stripe/subscription/status?organization_id=\(organizationId)"
        guard let url = URL(string: urlString) else { return }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.error = error.localizedDescription
                    return
                }
                
                guard let data = data else {
                    self?.error = "No data received"
                    return
                }
                
                do {
                    let status = try JSONDecoder().decode(StripeSubscriptionStatus.self, from: data)
                    
                    // Update our state
                    self?.hasSubscription = status.hasSubscription
                    self?.canUseKiosk = status.canUseKiosk
                    self?.subscriptionStatus = status.status
                    self?.isTrialing = status.status == "trialing"
                    self?.daysRemaining = status.daysRemaining
                    
                    // Parse the period end date
                    if let periodEndString = status.currentPeriodEnd {
                        let formatter = ISO8601DateFormatter()
                        self?.currentPeriodEnd = formatter.date(from: periodEndString)
                    }
                    
                    print("✅ Subscription status updated: \(status.status ?? "none")")
                    
                } catch {
                    self?.error = "Failed to parse subscription status"
                    print("❌ Parse error: \(error)")
                }
            }
        }.resume()
    }
    
    // MARK: - Create Portal Session
    
    func createPortalSession(completion: @escaping (URL?, String?) -> Void) {
        guard let organizationId = organizationId else {
            completion(nil, "Organization ID not set")
            return
        }
        
        isLoading = true
        
        let url = URL(string: "\(SquareConfig.backendBaseURL)/api/stripe/create-portal-session")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["organization_id": organizationId]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    completion(nil, error.localizedDescription)
                    return
                }
                
                guard let data = data else {
                    completion(nil, "No data received")
                    return
                }
                
                // Check for error response
                if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    completion(nil, errorResponse.error)
                    return
                }
                
                // Parse success response
                do {
                    let portal = try JSONDecoder().decode(StripePortalSession.self, from: data)
                    if let portalURL = URL(string: portal.url) {
                        print("✅ Portal session created")
                        completion(portalURL, nil)
                    } else {
                        throw URLError(.badURL)
                    }
                } catch {
                    completion(nil, "Invalid response")
                }
            }
        }.resume()
    }
    
    // MARK: - Helper Methods
    
    var statusDescription: String {
        guard hasSubscription else {
            return "No active subscription"
        }
        
        switch subscriptionStatus {
        case "active":
            return "Active subscription"
        case "trialing":
            if let days = daysRemaining {
                return "Free trial (\(days) days left)"
            }
            return "Free trial active"
        case "canceled":
            if canUseKiosk, let days = daysRemaining {
                return "Ending in \(days) days"
            }
            return "Subscription ended"
        default:
            return "Subscription status unknown"
        }
    }
    
    var requiresAction: Bool {
        return !hasSubscription || (subscriptionStatus == "canceled" && !canUseKiosk)
    }
}

// MARK: - Helper Models

struct ErrorResponse: Codable {
    let error: String
}

