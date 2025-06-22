//
//  SubscriptionManagementView.swift
//  ShulPad
//
//  Created by Zalman Rodkin on 6/22/25.
//

// SubscriptionManagementView.swift
import SwiftUI
import SafariServices

struct SubscriptionManagementView: View {
    @StateObject private var subscriptionStore = SubscriptionStore()
    @EnvironmentObject private var authService: SquareAuthService
    @State private var showingWebCheckout = false
    @State private var showingWebManagement = false
    @State private var showingCancelAlert = false
    @State private var cancelError: String?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                
                if subscriptionStore.isLoading {
                    loadingSection
                } else if subscriptionStore.hasActiveSubscription, let subscription = subscriptionStore.subscription {
                    activeSubscriptionSection(subscription)
                } else {
                    noSubscriptionSection
                }
                
                if let error = subscriptionStore.error {
                    errorSection(error)
                }
            }
            .padding()
        }
        .navigationTitle("Subscription")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            subscriptionStore.refreshSubscriptionStatus()
        }
        .sheet(isPresented: $showingWebCheckout) {
            if let checkoutURL = subscriptionStore.getCheckoutURL() {
                SafariView(url: checkoutURL)
            }
        }
        .sheet(isPresented: $showingWebManagement) {
            if let managementURL = subscriptionStore.getManagementURL() {
                SafariView(url: managementURL)
            }
        }
        .alert("Cancel Subscription", isPresented: $showingCancelAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Confirm", role: .destructive) {
                cancelSubscription()
            }
        } message: {
            Text("Are you sure you want to cancel your subscription? You'll lose access to premium features.")
        }
        .alert("Cancellation Failed", isPresented: .constant(cancelError != nil)) {
            Button("OK") { cancelError = nil }
        } message: {
            if let error = cancelError {
                Text(error)
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "creditcard.and.123")
                .font(.system(size: 50))
                .foregroundColor(.blue)
            
            Text("ShulPad Subscription")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Manage your subscription and billing")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top)
    }
    
    // MARK: - Loading Section
    private var loadingSection: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading subscription details...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    // MARK: - Active Subscription Section
    private func activeSubscriptionSection(_ subscription: SubscriptionDetails) -> some View {
        VStack(spacing: 20) {
            // Status Card
            VStack(spacing: 16) {
                HStack {
                    Text("Current Plan")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Text(subscription.status.uppercased())
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(subscription.status == "active" ? Color.green : Color.orange)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
                
                Divider()
                
                VStack(spacing: 12) {
                    subscriptionDetailRow("Plan Type", value: subscription.planType.capitalized)
                    subscriptionDetailRow("Devices", value: "\(subscription.deviceCount)")
                    subscriptionDetailRow("Price", value: "$\(Int(subscription.totalPrice))/\(subscription.planType == "monthly" ? "month" : "year")")
                    subscriptionDetailRow("Next Billing", value: formatDate(subscription.nextBillingDate))
                    
                    if let cardLastFour = subscription.cardLastFour {
                        subscriptionDetailRow("Payment Method", value: "•••• \(cardLastFour)")
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
            
            // Action Buttons
            VStack(spacing: 12) {
                Button(action: {
                    showingWebManagement = true
                }) {
                    HStack {
                        Image(systemName: "pencil")
                        Text("Manage Subscription")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                
                Button(action: {
                    showingCancelAlert = true
                }) {
                    HStack {
                        Image(systemName: "xmark.circle")
                        Text("Cancel Subscription")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .foregroundColor(.red)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.red, lineWidth: 1)
                    )
                }
            }
        }
    }
    
    // MARK: - No Subscription Section
    private var noSubscriptionSection: some View {
        VStack(spacing: 20) {
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 40))
                    .foregroundColor(.orange)
                
                Text("No Active Subscription")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Text("You need an active subscription to use ShulPad's kiosk features. Subscribe now to get started!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            
            Button(action: {
                showingWebCheckout = true
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Subscribe Now")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            
            // Features list
            VStack(alignment: .leading, spacing: 8) {
                Text("What's included:")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .padding(.bottom, 4)
                
                featureRow("Accept donations with Square readers")
                featureRow("Custom donation amounts")
                featureRow("Automatic receipt generation")
                featureRow("Real-time analytics")
                featureRow("Multi-device support")
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
    }
    
    // MARK: - Error Section
    private func errorSection(_ error: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 30))
                .foregroundColor(.orange)
            
            Text("Error Loading Subscription")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(error)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Try Again") {
                subscriptionStore.refreshSubscriptionStatus()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    // MARK: - Helper Views
    private func subscriptionDetailRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
    
    private func featureRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(.green)
                .padding(.top, 2)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
    
    // MARK: - Helper Functions
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            return displayFormatter.string(from: date)
        }
        return dateString
    }
    
    private func cancelSubscription() {
        subscriptionStore.cancelSubscription { success, error in
            if success {
                // Successfully cancelled
                print("✅ Subscription cancelled successfully")
            } else {
                self.cancelError = error
            }
        }
    }
}

// MARK: - SafariView for Web Checkout
struct SafariView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let safariVC = SFSafariViewController(url: url)
        safariVC.preferredControlTintColor = UIColor.systemBlue
        return safariVC
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

// MARK: - Preview
struct SubscriptionManagementView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SubscriptionManagementView()
                .environmentObject(SquareAuthService())
        }
    }
}
