import SwiftUI

struct StripeSubscriptionView: View {
    @StateObject private var subscriptionStore = StripeSubscriptionStore()
    @EnvironmentObject var authService: SquareAuthService
    
    @State private var showingCheckout = false
    @State private var showingPortal = false
    @State private var checkoutURL: URL?
    @State private var portalURL: URL?
    
    var body: some View {
        ZStack {
            if subscriptionStore.isLoading {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGroupedBackground))
            } else {
                ScrollView {
                    VStack(spacing: 24) {
                        headerSection
                        
                        if subscriptionStore.hasSubscription {
                            activeSubscriptionSection
                        } else {
                            noSubscriptionSection
                        }
                        
                        if let error = subscriptionStore.error {
                            errorBanner(error)
                        }
                    }
                    .padding()
                }
                .background(Color(.systemGroupedBackground))
            }
        }
        .onAppear {
            // Set organization ID from Square auth service (merchant ID)
            if let merchantId = authService.merchantId {
                subscriptionStore.setOrganizationId(merchantId)
                subscriptionStore.checkSubscriptionStatus()
            }
        }
        .sheet(isPresented: $showingCheckout) {
            if let url = checkoutURL {
                NavigationView {
                    WebView(url: url)
                        .navigationTitle("Subscribe")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") {
                                    showingCheckout = false
                                    // Refresh status after closing
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                        subscriptionStore.checkSubscriptionStatus()
                                    }
                                }
                            }
                        }
                }
            }
        }
        .sheet(isPresented: $showingPortal) {
            if let url = portalURL {
                NavigationView {
                    WebView(url: url)
                        .navigationTitle("Manage Subscription")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") {
                                    showingPortal = false
                                    // Refresh status after closing
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                        subscriptionStore.checkSubscriptionStatus()
                                    }
                                }
                            }
                        }
                }
            }
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "creditcard.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("ShulPad Subscription")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Manage your monthly subscription")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.vertical)
    }
    
    // MARK: - No Subscription Section
    
    private var noSubscriptionSection: some View {
        VStack(spacing: 20) {
            VStack(spacing: 16) {
                Text("Start Your Free Trial")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("30 days free, then $49/month")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 12) {
                    Label("Accept donations with Square", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Label("Custom kiosk branding", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Label("Email receipts", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Label("Real-time analytics", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
                .font(.body)
                .padding(.vertical)
                
                Button(action: startCheckout) {
                    Text("Start Free Trial")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(16)
        }
    }
    
    // MARK: - Active Subscription Section
    
    private var activeSubscriptionSection: some View {
        VStack(spacing: 20) {
            // Status Card
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading) {
                        Text(subscriptionStore.statusDescription)
                            .font(.headline)
                            .foregroundColor(statusColor)
                        
                        if subscriptionStore.canUseKiosk {
                            Label("Kiosk access active", systemImage: "checkmark.circle.fill")
                                .font(.subheadline)
                                .foregroundColor(.green)
                        }
                    }
                    
                    Spacer()
                    
                    statusIcon
                }
                
                if subscriptionStore.isTrialing {
                    Text("No payment required during trial")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let periodEnd = subscriptionStore.currentPeriodEnd {
                    HStack {
                        Text(subscriptionStore.subscriptionStatus == "canceled" ? "Service ends:" : "Next billing:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(periodEnd, style: .date)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
            
            // Action Button
            if subscriptionStore.requiresAction {
                Button(action: startCheckout) {
                    Text("Resubscribe")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
            } else {
                Button(action: openPortal) {
                    Text("Manage Subscription")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                
                Text("Update payment method, download invoices, or cancel")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    // MARK: - Error Banner
    
    private func errorBanner(_ error: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle")
                .foregroundColor(.orange)
            Text(error)
                .font(.caption)
                .foregroundColor(.orange)
            Spacer()
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }
    
    // MARK: - Helpers
    
    private var statusColor: Color {
        switch subscriptionStore.subscriptionStatus {
        case "active": return .green
        case "trialing": return .blue
        case "canceled": return subscriptionStore.canUseKiosk ? .orange : .red
        default: return .gray
        }
    }
    
    private var statusIcon: some View {
        Image(systemName: iconName)
            .font(.title2)
            .foregroundColor(statusColor)
    }
    
    private var iconName: String {
        switch subscriptionStore.subscriptionStatus {
        case "active": return "checkmark.circle.fill"
        case "trialing": return "gift.fill"
        case "canceled": return "exclamationmark.circle.fill"
        default: return "questionmark.circle.fill"
        }
    }
    
    // MARK: - Actions
    
    private func startCheckout() {
        subscriptionStore.createCheckoutSession { url, error in
            if let url = url {
                checkoutURL = url
                showingCheckout = true
            }
        }
    }
    
    private func openPortal() {
        print("🔘 Manage Subscription button tapped")
        subscriptionStore.createPortalSession { url, error in
            print("📱 Portal session callback received")
            print("📱 URL: \(url?.absoluteString ?? "nil")")
            print("📱 Error: \(error ?? "nil")")
            if let url = url {
                portalURL = url
                showingPortal = true
            }
        }
    }
}
