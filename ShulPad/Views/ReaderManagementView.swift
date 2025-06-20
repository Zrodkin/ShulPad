// Simplified ReaderManagementView.swift using Square's built-in settings

import SwiftUI
import SquareMobilePaymentsSDK

struct ReaderManagementView: View {
    @EnvironmentObject var squareAuthService: SquareAuthService
    @EnvironmentObject var squarePaymentService: SquarePaymentService
    @State private var showingSquareAuth = false
    @State private var isOpeningSettings = false
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                // Page header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "creditcard.wireless.fill")
                            .font(.title2)
                            .foregroundStyle(.blue)
                        
                        Text("Square Reader Management")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Spacer()
                    }
                    
                    Text("Manage your Square card readers for in-person payments")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                
                // Main content
                VStack(spacing: 20) {
                    // Authentication Status Section
                    authenticationStatusSection
                    
                    if squareAuthService.isAuthenticated {
                        // Simple Reader Management Section
                        readerManagementSection
                    }
                }
                .padding(.horizontal, 24)
            }
        }
        .background(Color(.systemGroupedBackground))
        .sheet(isPresented: $showingSquareAuth) {
            SquareAuthorizationView()
        }
    }
    
    // MARK: - View Components
    
    private var authenticationStatusSection: some View {
        SettingsCard(title: "Connection Status", icon: "wifi.circle.fill") {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(squareAuthService.isAuthenticated ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                        .frame(width: 48, height: 48)
                    
                    Circle()
                        .fill(squareAuthService.isAuthenticated ? Color.green : Color.red)
                        .frame(width: 12, height: 12)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(squareAuthService.isAuthenticated ? "Connected to Square" : "Not connected to Square")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(squareAuthService.isAuthenticated ? .green : .red)
                    
                    if !squareAuthService.isAuthenticated {
                        Text("Connect to Square to manage card readers")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                if !squareAuthService.isAuthenticated {
                    Button("Connect to Square") {
                        showingSquareAuth = true
                    }
                    .buttonStyle(ModernSecondaryButtonStyle())
                }
            }
        }
    }
    
    private var readerManagementSection: some View {
        SettingsCard(title: "Card Readers", icon: "creditcard.wireless.fill") {
            VStack(spacing: 20) {
                // Connection Status
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(squarePaymentService.isReaderConnected ?
                                  Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: "creditcard.wireless.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(squarePaymentService.isReaderConnected ? .green : .orange)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Reader Status")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text(squarePaymentService.connectionStatus)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                }
                
                Divider()
                
                // Main Action Button - Open Square's Settings
                Button(action: {
                    openSquareReaderSettings()
                }) {
                    HStack {
                        Image(systemName: "gear.circle.fill")
                            .font(.title3)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Manage Readers")
                                .fontWeight(.semibold)
                            
                            Text("Pair, configure, and test your Square readers")
                                .font(.caption)
                                .opacity(0.8)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "arrow.right")
                            .font(.caption)
                            .opacity(0.6)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 20)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(!squareAuthService.isAuthenticated || isOpeningSettings)
                .opacity(squareAuthService.isAuthenticated ? 1.0 : 0.5)
                
                // Info text
                VStack(spacing: 8) {
                    Text("Use Square's built-in reader management to:")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("•")
                            Text("Pair new Square readers")
                        }
                        HStack {
                            Text("•")
                            Text("Test existing connections")
                        }
                        HStack {
                            Text("•")
                            Text("Update reader firmware")
                        }
                        HStack {
                            Text("•")
                            Text("Configure reader settings")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)
            }
        }
    }
    
    // MARK: - Actions
    
    private func openSquareReaderSettings() {
        guard squareAuthService.isAuthenticated else {
            print("❌ Cannot open reader settings - not authenticated")
            return
        }
        
        isOpeningSettings = true
        
        // Find the current view controller
        guard let windowScene = UIApplication.shared.connectedScenes
            .filter({ $0.activationState == .foregroundActive })
            .compactMap({ $0 as? UIWindowScene })
            .first,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            print("❌ Could not find root view controller")
            isOpeningSettings = false
            return
        }

        // Find the top-most presented view controller
        var topController = rootViewController
        while let presented = topController.presentedViewController {
            topController = presented
        }

        print("🎛️ Opening Square's built-in reader settings...")
        
        // Present Square's native settings UI
        MobilePaymentsSDK.shared.settingsManager.presentSettings(
            with: topController,
            completion: { [self] _ in
                DispatchQueue.main.async {
                    print("✅ Square settings dismissed")
                    self.isOpeningSettings = false
                    
                    // Refresh reader connection status after settings are dismissed
                    self.squarePaymentService.connectToReader()
                }
            }
        )
    }
}

// MARK: - Supporting Components

struct ModernSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .fontWeight(.medium)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(.secondarySystemBackground))
            .foregroundStyle(.primary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct ReaderManagementView_Previews: PreviewProvider {
    static var previews: some View {
        ReaderManagementView()
            .environmentObject(SquareAuthService())
            .environmentObject(SquarePaymentService(authService: SquareAuthService(), catalogService: SquareCatalogService(authService: SquareAuthService())))
    }
}
