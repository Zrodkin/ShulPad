// ==========================================
// ENHANCED SUBSCRIPTION MANAGEMENT VIEW
// SubscriptionManagementView.swift
// ==========================================

import SwiftUI

struct SubscriptionManagementView: View {
    @StateObject private var subscriptionStore = SubscriptionStore()
    @EnvironmentObject var authService: SquareAuthService
    @State private var showingWebCheckout = false
    @State private var showingCancelAlert = false
    @State private var showingPauseAlert = false
    @State private var showingPlanChangeSheet = false
    @State private var selectedPlan: String = "monthly"
    @State private var selectedDeviceCount: Int = 1
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if subscriptionStore.isLoading {
                        loadingSection
                    } else if let subscription = subscriptionStore.subscription {
                        activeSubscriptionSection(subscription)
                    } else if let error = subscriptionStore.error {
                        errorSection(error)
                    } else {
                        noSubscriptionSection
                    }
                }
                .padding()
            }
            .navigationTitle("Subscription")
            .refreshable {
                subscriptionStore.refreshSubscriptionStatus()
            }
        }
        .onAppear {
            subscriptionStore.setAuthService(authService)
            subscriptionStore.refreshSubscriptionStatus()
        }
        .sheet(isPresented: $showingWebCheckout) {
            if let url = subscriptionStore.getCheckoutURL(planType: selectedPlan, deviceCount: selectedDeviceCount) {
                WebView(url: url)
            }
        }
        .sheet(isPresented: $showingPlanChangeSheet) {
            PlanChangeView(
                currentPlan: subscriptionStore.subscription?.planType ?? "monthly",
                currentDeviceCount: subscriptionStore.subscription?.deviceCount ?? 1,
                onPlanChange: { newPlan, newDeviceCount in
                    subscriptionStore.changePlan(newPlanType: newPlan, newDeviceCount: newDeviceCount) { success, error in
                        if success {
                            showingPlanChangeSheet = false
                        }
                        // Handle error if needed
                    }
                }
            )
        }
        .alert("Cancel Subscription", isPresented: $showingCancelAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Confirm", role: .destructive) {
                subscriptionStore.cancelSubscription { success, error in
                    // Handle result
                }
            }
        } message: {
            Text("Are you sure you want to cancel your subscription? You'll continue to have access until the end of your current billing period.")
        }
        .alert("Pause Subscription", isPresented: $showingPauseAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Pause") {
                subscriptionStore.pauseSubscription { success, error in
                    // Handle result
                }
            }
        } message: {
            Text("Your subscription will be paused and you won't be charged until you resume it.")
        }
    }
    
    // MARK: - View Sections
    
    private var loadingSection: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading subscription details...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
    
    private func activeSubscriptionSection(_ subscription: SubscriptionDetails) -> some View {
        VStack(spacing: 20) {
            // Status Card
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Active Subscription")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    StatusBadge(status: subscription.status)
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    DetailRow(label: "Plan", value: subscription.planType.capitalized)
                    DetailRow(label: "Devices", value: "\(subscription.deviceCount)")
                    DetailRow(label: "Price", value: String(format: "$%.2f/%@", subscription.totalPrice, subscription.planType == "yearly" ? "year" : "month"))
                    
                    if let nextBilling = subscription.nextBillingDate {
                        DetailRow(label: "Next Billing", value: formatDate(nextBilling))
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // Action Buttons
            VStack(spacing: 12) {
                if subscription.isActive {
                    Button("Change Plan") {
                        showingPlanChangeSheet = true
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    
                    Button("Pause Subscription") {
                        showingPauseAlert = true
                    }
                    .buttonStyle(SecondaryButtonStyle())
                } else if subscription.isPaused {
                    Button("Resume Subscription") {
                        subscriptionStore.resumeSubscription { success, error in
                            // Handle result
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                
                Button("Cancel Subscription") {
                    showingCancelAlert = true
                }
                .buttonStyle(DestructiveButtonStyle())
            }
            
            // Management Link
            if let managementURL = subscriptionStore.getManagementURL() {
                Link("Manage in Browser", destination: managementURL)
                    .font(.footnote)
                    .foregroundColor(.blue)
            }
        }
    }
    
    private var noSubscriptionSection: some View {
        VStack(spacing: 20) {
            VStack(spacing: 12) {
                Image(systemName: "creditcard.circle")
                    .font(.system(size: 50))
                    .foregroundColor(.blue)
                
                Text("No Active Subscription")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Subscribe to unlock all ShulPad features and start accepting donations!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            
            Button("Subscribe Now") {
                showingWebCheckout = true
            }
            .buttonStyle(PrimaryButtonStyle())
            
            // Features List
            FeaturesList()
        }
    }
    
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
            
            Button("Retry") {
                subscriptionStore.refreshSubscriptionStatus()
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding()
    }
}

// MARK: - Helper Views and Components

struct StatusBadge: View {
    let status: String
    
    var body: some View {
        Text(status.capitalized)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .foregroundColor(textColor)
            .cornerRadius(8)
    }
    
    private var backgroundColor: Color {
        switch status.lowercased() {
        case "active": return .green
        case "paused": return .orange
        case "canceled": return .red
        default: return .gray
        }
    }
    
    private var textColor: Color {
        return .white
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

struct FeaturesList: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What's included:")
                .font(.subheadline)
                .fontWeight(.semibold)
                .padding(.bottom, 4)
            
            FeatureRow(text: "Accept donations with Square readers")
            FeatureRow(text: "Custom donation amounts")
            FeatureRow(text: "Automatic receipt generation")
            FeatureRow(text: "Real-time analytics")
            FeatureRow(text: "Multi-device support")
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}



// MARK: - Helper Functions

private func formatDate(_ dateString: String) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    
    if let date = formatter.date(from: dateString) {
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    return dateString
}
