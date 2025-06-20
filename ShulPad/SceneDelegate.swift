import UIKit
import SwiftUI

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Create the services in the correct dependency order
        let authService = SquareAuthService()
        let catalogService = SquareCatalogService(authService: authService)
        let readerService = SquareReaderService(authService: authService)
        let paymentService = SquarePaymentService(authService: authService, catalogService: catalogService)
        
        // Connect the reader service to the payment service
        paymentService.setReaderService(readerService)
        
        // Create the SwiftUI view that provides the window contents
        let contentView = ContentView()
            .environmentObject(DonationViewModel())
            .environmentObject(OrganizationStore())
            .environmentObject(KioskStore())
            .environmentObject(authService)
            .environmentObject(catalogService)
            .environmentObject(paymentService)
            .environmentObject(readerService)

        // Use a UIHostingController as window root view controller
        if let windowScene = scene as? UIWindowScene {
            let window = UIWindow(windowScene: windowScene)
            window.rootViewController = UIHostingController(rootView: contentView)
            self.window = window
            window.makeKeyAndVisible()
        }
        
        // Handle any URLs that were passed at launch
        if let urlContext = connectionOptions.urlContexts.first {
            self.scene(scene, openURLContexts: [urlContext])
        }
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else {
            print("❌ No URL in openURLContexts")
            return
        }
        
        print("📱 SceneDelegate received URL: \(url.absoluteString)")
        
        // Only handle our custom scheme
        guard url.scheme == "shulpad" else {
            print("⚠️ Ignoring URL with scheme: \(url.scheme ?? "nil")")
            return
        }
        
        // Check if this is the oauth-complete callback
        if url.host == "oauth-complete" {
            print("✅ Processing oauth-complete callback")
            
            // Parse all URL parameters
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let queryItems = components?.queryItems ?? []
            
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
            
            // Build notification userInfo
            var userInfo: [String: Any] = ["success": success]
            if let error = error { userInfo["error"] = error }
            if let merchantId = merchantId { userInfo["merchant_id"] = merchantId }
            if let locationId = locationId { userInfo["location_id"] = locationId }
            if let locationName = locationName { userInfo["location_name"] = locationName }
            
            // Post notification to app
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .squareOAuthCallback,
                    object: url,
                    userInfo: userInfo
                )
                print("✅ Posted squareOAuthCallback notification with userInfo: \(userInfo)")
            }
        } else {
            print("⚠️ Unhandled shulpad URL host: \(url.host ?? "nil")")
            
            // For other URLs, just post the notification with the URL
            NotificationCenter.default.post(
                name: .squareOAuthCallback,
                object: url
            )
        }
    }
}
