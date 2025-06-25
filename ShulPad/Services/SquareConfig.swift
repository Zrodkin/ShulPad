import Foundation
import UIKit

struct SquareConfig {
    // Square application credentials
    static let clientID = "sq0idp-kt-6g2MHFsJB4J8uT5P-Fw"
    static let clientSecret = "sq0csp-wAgHmDXhxsayglxOuFSmAJ3ZnhZDVF2EKQd--WZ0pMc"
    
    // 🆕 NEW: Dynamic backend configuration
    private static var _backendBaseURL: String?
    private static var _redirectURI: String?
    private static var _configLoaded = false
    
    // Default/fallback URLs
    private static let defaultBackendURL = "https://api.shulpad.com"
    private static let configEndpoint = "/api/config"
    
    // 🆕 NEW: Dynamic backend URL with fallback
    static var backendBaseURL: String {
        return _backendBaseURL ?? defaultBackendURL
    }
    
    static var redirectURI: String {
        return _redirectURI ?? "\(backendBaseURL)/api/square/callback"
    }
    
    // OAuth endpoints on your backend
    static let authorizeEndpoint = "/api/square/authorize"
    static let statusEndpoint = "/api/square/status"
    static let refreshEndpoint = "/api/square/refresh"
    static let disconnectEndpoint = "/api/square/disconnect"
    
    // Organization identifier
    static let organizationId = "default"
    
    // Production environment
    static let environment = "production"
    static let authorizeURL = "https://connect.squareup.com/oauth2/authorize"
    static let tokenURL = "https://connect.squareup.com/oauth2/token"
    static let revokeURL = "https://connect.squareup.com/oauth2/revoke"
    
    // OAuth scopes
    static let scopes = [
        "MERCHANT_PROFILE_READ",
        "PAYMENTS_WRITE",
        "PAYMENTS_WRITE_IN_PERSON",
        "PAYMENTS_READ",
        "ITEMS_READ",
        "ITEMS_WRITE",
        "ORDERS_WRITE",
        "CUSTOMERS_WRITE"
    ]
    
    // 🚀 NEW: Fast startup configuration (ADD THIS METHOD)
    static func setDefaultConfiguration() {
        // Set defaults immediately without network calls
        _backendBaseURL = defaultBackendURL
        _redirectURI = "\(defaultBackendURL)/api/square/callback"
        _configLoaded = false // Will load async later
        
        // Try to load cached values if available
        if let cachedBackendURL = UserDefaults.standard.string(forKey: "cachedBackendURL") {
            _backendBaseURL = cachedBackendURL
        }
        if let cachedRedirectURI = UserDefaults.standard.string(forKey: "cachedRedirectURI") {
            _redirectURI = cachedRedirectURI
        }
        
        print("⚡ Default configuration set - ready for immediate use")
    }
    
    // 🆕 NEW: Load configuration from backend
    static func loadConfiguration(completion: @escaping (Bool) -> Void) {
        // Don't load multiple times
        guard !_configLoaded else {
            completion(true)
            return
        }
        
        // 🚀 OPTIMIZED: Do this work off the main thread
        DispatchQueue.global(qos: .utility).async {
            guard let configURL = URL(string: "\(defaultBackendURL)\(configEndpoint)") else {
                DispatchQueue.main.async {
                    print("⚠️ Invalid config URL, using defaults")
                    _configLoaded = true
                    completion(true)
                }
                return
            }
            
            print("🌐 Loading dynamic configuration from: \(configURL)")
            
            var request = URLRequest(url: configURL)
            request.timeoutInterval = 3.0 // 🚀 OPTIMIZED: Even shorter timeout
            request.cachePolicy = .reloadIgnoringLocalCacheData
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                DispatchQueue.main.async {
                    defer {
                        _configLoaded = true
                        completion(true)
                    }
                    
                    if let error = error {
                        print("⚠️ Failed to load config, using defaults: \(error)")
                        loadCachedConfiguration() // Load from cache if available
                        return
                    }
                    
                    guard let data = data else {
                        print("⚠️ No config data received, using defaults")
                        loadCachedConfiguration()
                        return
                    }
                    
                    do {
                        if let config = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            // Update URLs if provided
                            if let backendURL = config["backendBaseURL"] as? String {
                                _backendBaseURL = backendURL
                                print("✅ Updated backend URL to: \(backendURL)")
                            }
                            
                            if let redirectURL = config["redirectURI"] as? String {
                                _redirectURI = redirectURL
                                print("✅ Updated redirect URI to: \(redirectURL)")
                            }
                            
                            // Save to UserDefaults for offline use
                            UserDefaults.standard.set(_backendBaseURL, forKey: "cachedBackendURL")
                            UserDefaults.standard.set(_redirectURI, forKey: "cachedRedirectURI")
                            
                            print("✅ Configuration loaded and cached successfully")
                        }
                    } catch {
                        print("⚠️ Failed to parse config: \(error)")
                        loadCachedConfiguration() // Fallback to cache
                    }
                }
            }.resume()
        }
    }
    
    // 🆕 NEW: Load cached configuration for offline use
    private static func loadCachedConfiguration() {
        if let cachedBackendURL = UserDefaults.standard.string(forKey: "cachedBackendURL") {
            _backendBaseURL = cachedBackendURL
            print("📱 Using cached backend URL: \(cachedBackendURL)")
        }
        if let cachedRedirectURI = UserDefaults.standard.string(forKey: "cachedRedirectURI") {
            _redirectURI = cachedRedirectURI
            print("📱 Using cached redirect URI: \(cachedRedirectURI)")
        }
    }
    
    // 🆕 NEW: Force reload configuration (for testing/debugging)
    static func reloadConfiguration(completion: @escaping (Bool) -> Void) {
        _configLoaded = false
        loadConfiguration(completion: completion)
    }
    
    // Generate OAuth URL (updated to use dynamic URLs)
    static func generateOAuthURL(completion: @escaping (URL?, Error?, String?) -> Void) {
        // Ensure configuration is loaded first
        loadConfiguration { _ in
            let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? "unknown-device"
            
            guard let url = URL(string: "\(backendBaseURL)\(authorizeEndpoint)?organization_id=\(organizationId)&device_id=\(deviceId)") else {
                completion(nil, NSError(domain: "com.charitypad", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid backend URL"]), nil)
                return
            }
            
            print("🔗 Requesting OAuth URL from: \(url)")
            
            URLSession.shared.dataTask(with: url) { data, response, error in
                if let error = error {
                    print("❌ Network error requesting OAuth URL: \(error.localizedDescription)")
                    completion(nil, error, nil)
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("📊 Backend status code: \(httpResponse.statusCode)")
                }
                
                guard let data = data else {
                    print("❌ No data received from backend")
                    completion(nil, NSError(domain: "com.charitypad", code: 2, userInfo: [NSLocalizedDescriptionKey: "No data received"]), nil)
                    return
                }
                
                let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode response"
                print("📄 Backend response: \(responseString)")
                
                do {
                    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                    if let authUrlString = json?["authUrl"] as? String, let authUrl = URL(string: authUrlString) {
                        if let state = json?["state"] as? String {
                            UserDefaults.standard.set(state, forKey: "squarePendingAuthState")
                            print("🔐 Stored OAuth state: \(state)")
                            completion(authUrl, nil, state)
                            return
                        }
                        print("🔗 Generated OAuth URL: \(authUrl)")
                        completion(authUrl, nil, nil)
                    } else if let error = json?["error"] as? String {
                        print("❌ Backend error: \(error)")
                        completion(nil, NSError(domain: "com.charitypad", code: 3, userInfo: [NSLocalizedDescriptionKey: error]), nil)
                    } else {
                        print("❌ Invalid response format")
                        completion(nil, NSError(domain: "com.charitypad", code: 4, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"]), nil)
                    }
                } catch {
                    print("❌ JSON parsing error: \(error.localizedDescription)")
                    completion(nil, error, nil)
                }
            }.resume()
        }
    }
}
