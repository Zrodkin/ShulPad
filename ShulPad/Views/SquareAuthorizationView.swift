import SwiftUI
import SafariServices
import AuthenticationServices

struct SquareAuthorizationView: View {
    @EnvironmentObject private var squareAuthService: SquareAuthService
    @StateObject private var authSessionManager = AuthenticationSessionManager()
    @State private var authURL: URL?
    @Environment(\.presentationMode) var presentationMode
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Square logo
            Image("square-logo-white")
                .resizable()
                .scaledToFit()
                .frame(height: 60)
                .padding(.top, 40)
            
            if squareAuthService.isAuthenticated {
                // Show success view
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                        .padding()
                    
                    Text("Successfully connected to Square!")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("You'll be redirected to the dashboard in a moment...")
                        .foregroundColor(.gray)
                }
                .onAppear {
                    hasCompletedOnboarding = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            } else if let error = authSessionManager.authError ?? squareAuthService.authError {
                // Show error view
                VStack(spacing: 16) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.red)
                        .padding()
                    
                    Text("Connection Failed")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(error)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                    
                    Button(action: {
                        authSessionManager.authError = nil
                        squareAuthService.authError = nil
                        startAuth()
                    }) {
                        Text("Try Again")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                }
            } else if authSessionManager.isAuthenticating || squareAuthService.isAuthenticating {
                // Show connecting view
                VStack(spacing: 16) {
                    Text("Connecting to Square")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    ProgressView()
                        .padding()
                    
                    Text("Please complete the authorization in the browser...")
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                    
                    Button("Cancel") {
                        authSessionManager.cancelAuthentication()
                        squareAuthService.isAuthenticating = false
                    }
                    .foregroundColor(.red)
                    .padding(.top)
                }
            } else {
                // Show initial connect view
                VStack(spacing: 16) {
                    Text("Connect with Square")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("ShulPad needs to connect to your Square account to process payments.")
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button(action: startAuth) {
                        HStack {
                            Image("square-logo-icon")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                            
                            Text("Connect with Square")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.black)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .padding(.horizontal)
                }
            }
            
            Spacer()
        }
        .padding()
        .onAppear {
            // Check if already authenticated
            if squareAuthService.isAuthenticated {
                print("Already authenticated, completing onboarding")
                hasCompletedOnboarding = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
        .onReceive(squareAuthService.$isAuthenticated) { isAuthenticated in
            if isAuthenticated {
                print("Authentication successful")
                hasCompletedOnboarding = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }
    
    private func startAuth() {
        print("🔄 Starting Square OAuth flow with ASWebAuthenticationSession...")
        
        // Get authorization URL from your backend
        SquareConfig.generateOAuthURL { url, error, state in
            DispatchQueue.main.async {
                if let error = error {
                    authSessionManager.authError = "Failed to generate authorization URL: \(error.localizedDescription)"
                    return
                }
                
                guard let url = url else {
                    authSessionManager.authError = "Failed to generate authorization URL"
                    return
                }
                
                // Set state if available
                if let state = state {
                    print("📝 Setting pendingAuthState to: \(state)")
                    squareAuthService.pendingAuthState = state
                } else {
                    print("⚠️ WARNING: No state returned from generateOAuthURL")
                }
                
                // Start authentication session
                authSessionManager.startAuthentication(
                    with: url,
                    callbackURLScheme: "shulpad" // Your custom URL scheme
                ) { callbackURL, error in
                    handleAuthenticationResult(callbackURL: callbackURL, error: error)
                }
            }
        }
    }
    
    private func handleAuthenticationResult(callbackURL: URL?, error: Error?) {
        print("🔄 Processing authentication result...")
        
        if let error = error {
            print("❌ Authentication error: \(error)")
            if case ASWebAuthenticationSessionError.canceledLogin = error {
                // User cancelled - don't show error
                print("🚪 User cancelled authentication")
            } else {
                authSessionManager.authError = "Authentication failed: \(error.localizedDescription)"
            }
            return
        }
        
        guard let callbackURL = callbackURL else {
            print("❌ No callback URL received")
            authSessionManager.authError = "No callback URL received"
            return
        }
        
        print("✅ Received callback URL: \(callbackURL)")
        
        // Process the callback URL
        squareAuthService.handleOAuthCallback(url: callbackURL)
        
        // Start polling for authentication status
        if squareAuthService.pendingAuthState != nil {
            squareAuthService.startPollingForAuthStatus()
        } else {
            print("⚠️ No pending auth state, starting fallback polling")
            squareAuthService.checkAuthentication()
        }
    }
}
