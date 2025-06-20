//
//  AuthenticationSessionManager.swift
//  ShulPad
//
//  Created by Zalman Rodkin on 6/19/25.
//

import SwiftUI
import AuthenticationServices

// MARK: - AuthenticationSession Manager
class AuthenticationSessionManager: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {
    @Published var isAuthenticating = false
    @Published var authError: String?
    
    private var authSession: ASWebAuthenticationSession?
    
    func startAuthentication(with url: URL, callbackURLScheme: String, completion: @escaping (URL?, Error?) -> Void) {
        print("🔐 Starting ASWebAuthenticationSession with URL: \(url)")
        print("🔗 Callback URL scheme: \(callbackURLScheme)")
        
        // Cancel any existing session
        authSession?.cancel()
        
        // Create new authentication session
        authSession = ASWebAuthenticationSession(
            url: url,
            callbackURLScheme: callbackURLScheme
        ) { [weak self] callbackURL, error in
            DispatchQueue.main.async {
                self?.isAuthenticating = false
                
                if let error = error {
                    // Check if user cancelled
                    if case ASWebAuthenticationSessionError.canceledLogin = error {
                        print("🚪 User cancelled authentication")
                        self?.authError = "Authentication was cancelled"
                    } else {
                        print("❌ Authentication error: \(error)")
                        self?.authError = "Authentication failed: \(error.localizedDescription)"
                    }
                    completion(nil, error)
                } else if let callbackURL = callbackURL {
                    print("✅ Authentication completed with callback URL: \(callbackURL)")
                    completion(callbackURL, nil)
                } else {
                    print("⚠️ Authentication completed but no callback URL")
                    completion(nil, NSError(domain: "AuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No callback URL received"]))
                }
            }
        }
        
        // Set presentation context provider
        authSession?.presentationContextProvider = self
        
        // Configure for better user experience
        authSession?.prefersEphemeralWebBrowserSession = false // Use Safari cookies/session
        
        // Start the session
        isAuthenticating = true
        authError = nil
        
        guard authSession?.start() == true else {
            print("❌ Failed to start ASWebAuthenticationSession")
            isAuthenticating = false
            authError = "Failed to start authentication session"
            completion(nil, NSError(domain: "AuthError", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to start authentication session"]))
            return
        }
        
        print("🚀 ASWebAuthenticationSession started successfully")
    }
    
    func cancelAuthentication() {
        print("🛑 Cancelling authentication session")
        authSession?.cancel()
        authSession = nil
        isAuthenticating = false
    }
    
    // MARK: - ASWebAuthenticationPresentationContextProviding
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Return the key window
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? UIWindow()
    }
}
