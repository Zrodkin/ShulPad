import UIKit
import SwiftUI
import SquareMobilePaymentsSDK

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        // ✅ FIXED: Initialize Square SDK immediately, config loading happens separately
        let applicationId = SquareConfig.clientID
        MobilePaymentsSDK.initialize(squareApplicationID: applicationId)
        print("✅ Square Mobile Payments SDK initialized successfully")
        
        // 🆕 Load dynamic configuration in background (non-blocking)
        SquareConfig.loadConfiguration { success in
            print("🔧 Configuration loading completed: \(success ? "✅ Success" : "⚠️ Using defaults")")
        }
        
        return true
    }
    
    // MARK: - URL Handling for Deep Links
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        print("📱 AppDelegate received URL: \(url.absoluteString)")
        return handleDeepLink(url)
    }
    
    // MARK: - Deep Link Handler
    private func handleDeepLink(_ url: URL) -> Bool {
        print("🔗 Processing deep link: \(url)")
        
        guard url.scheme == "shulpad" else {
            print("⚠️ Unknown URL scheme: \(url.scheme ?? "none")")
            return false
        }
        
        // Handle different deep link types
        switch url.host {
        case "oauth-complete":
            return handleOAuthCallback(url)
        case "subscription-success", "subscription-cancelled", "subscription-manage":
            return handleSubscriptionDeepLink(url)
        default:
            // For backwards compatibility
            print("🔄 Handling as legacy OAuth callback: \(url.host ?? "none")")
            return handleOAuthCallback(url)
        }
    }
    
    // MARK: - OAuth Deep Link Handler (Enhanced)
    private func handleOAuthCallback(_ url: URL) -> Bool {
        print("🔐 Processing OAuth callback: \(url)")
        
        // Parse URL components
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            print("❌ Invalid OAuth callback URL structure")
            return false
        }
        
        let queryItems = components.queryItems ?? []
        
        // Extract parameters
        let success = queryItems.first(where: { $0.name == "success" })?.value == "true"
        let error = queryItems.first(where: { $0.name == "error" })?.value
        let merchantId = queryItems.first(where: { $0.name == "merchant_id" })?.value
        let locationId = queryItems.first(where: { $0.name == "location_id" })?.value
        let locationName = queryItems.first(where: { $0.name == "location_name" })?.value
        
        // Debug logging
        print("📊 OAuth Parameters:")
        print("  - Success: \(success)")
        print("  - Error: \(error ?? "none")")
        print("  - Merchant ID: \(merchantId ?? "none")")
        print("  - Location ID: \(locationId ?? "none")")
        print("  - Location Name: \(locationName ?? "none")")
        
        // Build notification userInfo with all parameters
        var userInfo: [String: Any] = ["success": success]
        if let error = error { userInfo["error"] = error }
        if let merchantId = merchantId { userInfo["merchant_id"] = merchantId }
        if let locationId = locationId { userInfo["location_id"] = locationId }
        if let locationName = locationName { userInfo["location_name"] = locationName }
        
        // Post notification with complete userInfo
        NotificationCenter.default.post(
            name: .squareOAuthCallback,
            object: url,
            userInfo: userInfo
        )
        
        print("✅ Posted OAuth callback notification with userInfo: \(userInfo)")
        return true
    }
    
    // MARK: - Subscription Deep Link Handler
    private func handleSubscriptionDeepLink(_ url: URL) -> Bool {
        print("💳 Processing subscription deep link: \(url)")
        
        // Check the host, not path components
        guard let host = url.host else {
            print("⚠️ Invalid subscription deep link")
            return false
        }
        
        switch host {
        case "subscription-success":
            handleSubscriptionSuccess(url)
            return true
            
        case "subscription-cancelled":
            handleSubscriptionCancelled(url)
            return true
            
        case "subscription-manage":
            handleSubscriptionManage(url)
            return true
            
        default:
            print("⚠️ Unknown subscription action: \(host)")
            print("⚠️ Unknown subscription action: \(host)")
            return false
        }
    }
    
    // MARK: - Subscription Deep Link Handlers
    
    private func handleSubscriptionSuccess(_ url: URL) {
        print("🎉 Subscription activated successfully!")
        
        // Extract session_id if provided
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let sessionId = components?.queryItems?.first(where: { $0.name == "session_id" })?.value
        
        print("📋 Subscription Success - Session ID: \(sessionId ?? "none")")
        
        DispatchQueue.main.async {
            // Post notification to refresh subscription status
            NotificationCenter.default.post(
                name: .subscriptionStatusChanged,
                object: nil,
                userInfo: ["session_id": sessionId ?? ""]
            )
            
            // Show success message
            self.showSubscriptionSuccessAlert()
        }
    }
    
    private func handleSubscriptionCancelled(_ url: URL) {
        print("🚪 User cancelled subscription checkout")
        
        DispatchQueue.main.async {
            // Optionally refresh status even on cancel
            NotificationCenter.default.post(
                name: .subscriptionStatusChanged,
                object: nil
            )
            
            print("ℹ️ User returned to app after cancelling subscription")
        }
    }
    
    private func handleSubscriptionManage(_ url: URL) {
        print("⚙️ User returned from subscription management")
        
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let merchantId = components?.queryItems?.first(where: { $0.name == "merchant_id" })?.value
        
        print("📋 Subscription Management Parameters:")
        print("  - Merchant ID: \(merchantId ?? "none")")
        
        DispatchQueue.main.async {
            // Refresh subscription status in case changes were made
            NotificationCenter.default.post(
                name: .subscriptionStatusChanged,
                object: nil,
                userInfo: ["merchant_id": merchantId ?? ""]
            )
            
            print("🔄 Refreshing subscription status after management")
        }
    }
    
    // MARK: - Helper Methods
    
    private func showSubscriptionSuccessAlert() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            print("⚠️ Could not find root view controller for alert")
            return
        }
        
        let alert = UIAlertController(
            title: "🎉 Subscription Activated!",
            message: "Your ShulPad subscription is now active. You can start using the kiosk immediately.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Great!", style: .default) { _ in
            print("✅ User acknowledged subscription success")
        })
        
        // Present the alert on the topmost view controller
        var presentingViewController = rootViewController
        while let presented = presentingViewController.presentedViewController {
            presentingViewController = presented
        }
        
        presentingViewController.present(alert, animated: true) {
            print("📱 Subscription success alert presented")
        }
    }
    
    // MARK: - Application Lifecycle Events
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        print("📱 App became active")
        
        // Refresh subscription status when app becomes active
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NotificationCenter.default.post(name: .refreshSubscriptionStatus, object: nil)
        }
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        print("📱 App will resign active")
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        print("📱 App entered background")
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        print("📱 App will enter foreground")
    }
}

// MARK: - Notification Names
extension Notification.Name {
    // Existing OAuth notifications
    static let squareOAuthCallback = Notification.Name("SquareOAuthCallback")
    static let squareAuthenticationSuccessful = Notification.Name("SquareAuthenticationSuccessful")
    static let forceReturnToOnboarding = Notification.Name("ForceReturnToOnboarding")
    
    // New subscription notifications
    static let subscriptionStatusChanged = Notification.Name("SubscriptionStatusChanged")
    static let refreshSubscriptionStatus = Notification.Name("RefreshSubscriptionStatus")
}
