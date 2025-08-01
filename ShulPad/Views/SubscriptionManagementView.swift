// STEP 1: Replace your existing SubscriptionManagementView.swift with this enhanced version

// SubscriptionManagementView.swift - Enhanced with Clear Cancellation Status
import SwiftUI

struct SubscriptionManagementView: View {
    @StateObject private var subscriptionStore = SubscriptionStore()
    @EnvironmentObject var authService: SquareAuthService
    @State private var showingWebCheckout = false
    @State private var showingCancelAlert = false
    @State private var showingCancelSuccess = false
    @State private var cancelMessage = ""
    @State private var hasInitialized = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header section
                headerSection
                
                // Content sections
                if subscriptionStore.isLoading && subscriptionStore.subscription == nil {
                    loadingSection
                } else if let subscription = subscriptionStore.subscription {
                    enhancedSubscriptionStatusSection(subscription)
                } else if let error = subscriptionStore.error {
                    errorSection(error)
                } else {
                    noSubscriptionSection
                }
            }
            .padding(.bottom, 30)
        }
        .background(Color(.systemGroupedBackground))
        .refreshable {
            if !subscriptionStore.isLoading {
                subscriptionStore.refreshSubscriptionStatus()
            }
        }
        .onAppear {
            if !hasInitialized {
                hasInitialized = true
                subscriptionStore.setAuthService(authService)
                subscriptionStore.refreshSubscriptionStatus()
            }
        }
        .sheet(isPresented: $showingWebCheckout) {
            if let url = subscriptionStore.getCheckoutURL() {
                NavigationView {
                    WebView(url: url)
                        .navigationTitle("Subscribe")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") {
                                    showingWebCheckout = false
                                }
                            }
                        }
                }
            }
        }
        .alert("Confirm Cancellation", isPresented: $showingCancelAlert) {
            Button("Keep Subscription", role: .cancel) { }
            Button("Cancel Subscription", role: .destructive) {
                performCancellation()
            }
        } message: {
            Text("Your subscription will remain active until the end of your current billing period. You can resubscribe anytime.")
        }
        .alert("Subscription Status", isPresented: $showingCancelSuccess) {
            Button("OK") { }
        } message: {
            Text(cancelMessage)
        }
    }
    
    // MARK: - Enhanced Status Section with Clear Indicators
    @ViewBuilder
    private func enhancedSubscriptionStatusSection(_ subscription: SubscriptionDetails) -> some View {
        VStack(spacing: 20) {
            // Main Status Card with Enhanced Visual Indicators
            VStack(alignment: .leading, spacing: 16) {
                // Primary Status Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(getPrimaryStatusTitle(for: subscription))
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(getPrimaryStatusColor(for: subscription))
                            
                            if subscription.isCanceledButActive {
                                Text("Will end on \(formatServiceEndDate(subscription.serviceEndsDate))")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                    .fontWeight(.medium)
                            }
                        }
                        
                        Spacer()
                        
                        EnhancedStatusIndicator(subscription: subscription)
                    }
                    
                    // Subscription details
                    Text("\(subscription.planType.capitalized) Plan • \(subscription.deviceCount) Device\(subscription.deviceCount == 1 ? "" : "s")")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Cancellation Warning Banner (NEW)
                if subscription.isCanceledButActive {
                    cancellationWarningBanner(subscription)
                }
                
                // Status Message (enhanced)
                if let message = subscriptionStore.statusMessage {
                    statusMessageBanner(message)
                }
                
                Divider()
                
                // Subscription Details
                VStack(spacing: 12) {
                    DetailRow(
                        title: "Monthly Cost",
                        value: String(format: "$%.2f", subscription.totalPrice),
                        icon: "dollarsign.circle"
                    )
                    
                    if subscription.isCanceledButActive {
                        DetailRow(
                            title: "Service Ends",
                            value: formatBillingDate(subscription.serviceEndsDate),
                            icon: "calendar.badge.exclamationmark",
                            valueColor: .orange
                        )
                        
                        if let days = subscription.daysUntilServiceEnds {
                            DetailRow(
                                title: "Days Remaining",
                                value: "\(days) day\(days == 1 ? "" : "s")",
                                icon: "clock.circle",
                                valueColor: days <= 7 ? .red : .orange
                            )
                        }
                    } else {
                        DetailRow(
                            title: "Next Billing",
                            value: formatBillingDate(subscription.nextBillingDate),
                            icon: "calendar"
                        )
                    }
                }
            }
            .padding(16)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
            .padding(.horizontal, 20)
            
            // Enhanced Action Buttons
            enhancedActionButtons(subscription)
        }
    }
    
    // MARK: - NEW: Cancellation Warning Banner
    @ViewBuilder
    private func cancellationWarningBanner(_ subscription: SubscriptionDetails) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Subscription Cancelled")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                if let days = subscription.daysUntilServiceEnds {
                    if days > 0 {
                        Text("Your service continues for \(days) more day\(days == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Service ends today")
                            .font(.caption)
                            .foregroundColor(.red)
                            .fontWeight(.medium)
                    }
                }
            }
            
            Spacer()
            
            Button("Reactivate") {
                showingWebCheckout = true
            }
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(.blue)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
        }
        .padding(12)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Enhanced Action Buttons
    @ViewBuilder
    private func enhancedActionButtons(_ subscription: SubscriptionDetails) -> some View {
        VStack(spacing: 12) {
            if subscription.isCanceledButActive {
                // Reactivate button (primary action)
                Button("Reactivate Subscription") {
                    showingWebCheckout = true
                }
                .buttonStyle(PrimaryButtonStyle())
                
                // Secondary action - extend current service
                if let url = subscriptionStore.getManagementURL() {
                    Link("View Billing Details", destination: url)
                        .font(.subheadline)
                        .foregroundColor(.blue)
                        .padding(.top, 4)
                }
                
            } else if subscription.isActive {
                Button("Manage Plan & Billing") {
                    if let url = subscriptionStore.getManagementURL() {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                
                Button("Cancel Subscription") {
                    showingCancelAlert = true
                }
                .buttonStyle(DestructiveButtonStyle())
                
            } else if subscription.isPaused {
                Button("Resume Subscription") {
                    subscriptionStore.resumeSubscription { success, error in
                        // Handle result
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                
                Button("Cancel Subscription") {
                    showingCancelAlert = true
                }
                .buttonStyle(DestructiveButtonStyle())
                
            } else if subscription.isExpired {
                Button("Resubscribe Now") {
                    showingWebCheckout = true
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Helper Methods
    private func getPrimaryStatusTitle(for subscription: SubscriptionDetails) -> String {
        if subscription.isCanceledButActive {
            return "Active Until \(formatShortDate(subscription.serviceEndsDate))"
        }
        
        switch subscription.status {
        case "active": return "Active Subscription"
        case "paused": return "Paused Subscription"
        case "canceled": return subscription.isExpired ? "Subscription Expired" : "Subscription Cancelled"
        default: return "Subscription Status"
        }
    }
    
    private func getPrimaryStatusColor(for subscription: SubscriptionDetails) -> Color {
        if subscription.isCanceledButActive {
            return subscription.daysUntilServiceEnds ?? 0 <= 7 ? .red : .orange
        }
        
        switch subscription.status {
        case "active": return .green
        case "paused": return .orange
        case "canceled": return subscription.isExpired ? .red : .orange
        default: return .gray
        }
    }
    
    private func formatServiceEndDate(_ dateString: String?) -> String {
        guard let dateString = dateString else { return "Unknown" }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        if let date = formatter.date(from: dateString) {
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: date)
        }
        
        return dateString
    }
    
    private func formatShortDate(_ dateString: String?) -> String {
        guard let dateString = dateString else { return "Unknown" }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        if let date = formatter.date(from: dateString) {
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
        
        return dateString
    }
    
    private func formatBillingDate(_ dateString: String?) -> String {
        guard let dateString = dateString else { return "Unknown" }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        if let date = formatter.date(from: dateString) {
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: date)
        }
        
        return dateString
    }
    
    private func performCancellation() {
        guard !subscriptionStore.isLoading else { return }
        
        subscriptionStore.cancelSubscription { [self] success, message in
            DispatchQueue.main.async {
                self.cancelMessage = message ?? (success ? "Subscription cancelled successfully." : "Unable to cancel subscription.")
                self.showingCancelSuccess = true
            }
        }
    }
}

// MARK: - Enhanced Status Indicator
struct EnhancedStatusIndicator: View {
    let subscription: SubscriptionDetails
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(indicatorColor)
                .frame(width: 8, height: 8)
            
            Text(displayStatus)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(indicatorColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(indicatorColor.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var displayStatus: String {
        if subscription.isCanceledButActive {
            return "Ending Soon"
        } else {
            return subscription.status.capitalized
        }
    }
    
    private var indicatorColor: Color {
        if subscription.isCanceledButActive {
            return subscription.daysUntilServiceEnds ?? 0 <= 7 ? .red : .orange
        }
        
        switch subscription.status {
        case "active": return .green
        case "paused": return .orange
        case "canceled": return .red
        default: return .gray
        }
    }
}

// MARK: - Enhanced Detail Row with Optional Color
struct DetailRow: View {
    let title: String
    let value: String
    let icon: String
    var valueColor: Color = .primary
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(valueColor)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}



// MARK: - Supporting Views (headers, loading, etc.)
extension SubscriptionManagementView {
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Subscription")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Manage your ShulPad subscription")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    if !subscriptionStore.isLoading {
                        subscriptionStore.refreshSubscriptionStatus()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
                .disabled(subscriptionStore.isLoading)
            }
        }
        .padding(.horizontal, 20)
    }
    
    private var loadingSection: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading subscription details...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 150)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .padding(.horizontal, 20)
    }
    
    private var noSubscriptionSection: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                Image(systemName: "creditcard.circle")
                    .font(.system(size: 40))
                    .foregroundColor(.blue)
                
                VStack(spacing: 8) {
                    Text("No Active Subscription")
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    Text("Subscribe to ShulPad to unlock all features and start accepting donations.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }
            }
            .padding(20)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            
            Button("Subscribe Now") {
                showingWebCheckout = true
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(.horizontal, 20)
    }
    
    private func errorSection(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 30))
                .foregroundColor(.orange)
            
            VStack(spacing: 8) {
                Text("Unable to Load Subscription")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(error)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
            
            Button("Try Again") {
                subscriptionStore.refreshSubscriptionStatus()
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .padding(.horizontal, 20)
    }
    
    @ViewBuilder
    private func statusMessageBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: subscriptionStore.urgencyLevel.systemName)
                .foregroundColor(Color(subscriptionStore.urgencyLevel.color))
                .font(.caption)
            
            Text(message)
                .font(.caption)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
        .padding(10)
        .background(Color(subscriptionStore.urgencyLevel.color).opacity(0.1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(subscriptionStore.urgencyLevel.color).opacity(0.3), lineWidth: 1)
        )
    }
}
