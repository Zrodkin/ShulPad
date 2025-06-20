// ResilientBackendConfig.swift - Minimal addition
import Foundation

class ResilientBackendConfig {
    static let shared = ResilientBackendConfig()
    
    private var currentURL = SquareConfig.backendBaseURL
    
    private init() {}
    
    func getCurrentBackendURL() -> String {
        return currentURL
    }
    
    func refreshBackendURL() async {
        // Try current URL first
        if await testURL(currentURL) {
            return
        }
        
        // Try alternatives
        let alternatives = [
            SquareConfig.backendBaseURL,
            "https://api.shulpad.com"
        ]
        
        for url in alternatives {
            if await testURL(url) {
                currentURL = url
                print("✅ Updated backend URL to: \(url)")
                return
            }
        }
    }
    
    private func testURL(_ url: String) async -> Bool {
        guard let testURL = URL(string: "\(url)/api/config") else { return false }
        
        do {
            let (_, response) = try await URLSession.shared.data(from: testURL)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
}
