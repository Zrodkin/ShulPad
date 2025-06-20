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
  
    // Handle OAuth callback via custom URL scheme
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        print("📱 AppDelegate received URL: \(url.absoluteString)")

        // Handle Square OAuth callback via custom URL scheme
        if url.scheme == "shulpad" {
            print("🔗 Received callback with URL: \(url)")
            
            // Check if this is our oauth-complete callback
            if url.host == "oauth-complete" {
                print("✅ Processing oauth-complete callback in AppDelegate")
                
                // Parse all URL parameters (matching SceneDelegate logic)
                let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                let queryItems = components?.queryItems ?? []
                
                // Extract parameters
                let success = queryItems.first(where: { $0.name == "success" })?.value == "true"
                let error = queryItems.first(where: { $0.name == "error" })?.value
                let merchantId = queryItems.first(where: { $0.name == "merchant_id" })?.value
                let locationId = queryItems.first(where: { $0.name == "location_id" })?.value
                let locationName = queryItems.first(where: { $0.name == "location_name" })?.value
                
                // Debug logging
                print("📊 OAuth Parameters (AppDelegate):")
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
                
                print("✅ AppDelegate posted squareOAuthCallback notification with userInfo: \(userInfo)")
                return true
            }
            
            // For other shulpad:// URLs, just post the notification with the URL
            NotificationCenter.default.post(
                name: .squareOAuthCallback,
                object: url
            )
            return true
        }
        
        print("⚠️ URL not handled: \(url)")
        return false
    }
}

// Add a notification name for the OAuth callback
extension Notification.Name {
    static let squareOAuthCallback = Notification.Name("SquareOAuthCallback")
    static let squareAuthenticationSuccessful = Notification.Name("SquareAuthenticationSuccessful")
    static let forceReturnToOnboarding = Notification.Name("ForceReturnToOnboarding")
}
