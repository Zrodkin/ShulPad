import SwiftUI

struct TimeoutSettingsView: View {
    @EnvironmentObject private var kioskStore: KioskStore
    @State private var timeoutDuration: String = "15"
    
    // Auto-save timer
    @State private var autoSaveTimer: Timer?
    
    let timeoutOptions = [
        ("10", "10 seconds"),
        ("15", "15 seconds"),
        ("25", "25 seconds"),
        ("30", "30 seconds"),
        ("45", "45 seconds")
    ]
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                // Page header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "clock.fill")
                            .font(.title2)
                            .foregroundStyle(.blue)
                        
                        Text("Timeout Settings")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Spacer()
                    }
                    
                    Text("Configure how long the kiosk waits before automatically resetting to the home screen")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                
                // Main content - just the timeout duration card
                VStack(spacing: 20) {
                    SettingsCard(title: "Auto-Reset Duration", icon: "timer.circle.fill") {
                        VStack(spacing: 24) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Select how long to wait for user interaction before returning to the home screen")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            
                            // Show custom value notice if user has a value not in the new options
                            if !timeoutOptions.contains(where: { $0.0 == timeoutDuration }) {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Image(systemName: "info.circle.fill")
                                            .foregroundStyle(.blue)
                                        
                                        Text("Current Setting: \(formatTimeoutDuration(timeoutDuration))")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                    }
                                    
                                    Text("Your current timeout setting will be preserved. Select a new option below to change it.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(12)
                                .background(Color.blue.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            
                            // Timeout options
                            VStack(spacing: 12) {
                                ForEach(timeoutOptions, id: \.0) { option in
                                    TimeoutOptionCard(
                                        value: option.0,
                                        label: option.1,
                                        isSelected: timeoutDuration == option.0,
                                        isRecommended: option.0 == "15",
                                        onSelect: {
                                            timeoutDuration = option.0
                                            autoSaveSettings()
                                        }
                                    )
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            timeoutDuration = kioskStore.timeoutDuration
        }
    }
    
    // MARK: - Helper Functions
    
    private func formatTimeoutDuration(_ duration: String) -> String {
        guard let seconds = Int(duration) else { return "\(duration) seconds" }
        
        if seconds < 60 {
            return "\(seconds) seconds"
        } else if seconds == 60 {
            return "1 minute"
        } else if seconds < 3600 && seconds % 60 == 0 {
            return "\(seconds / 60) minutes"
        } else {
            return "\(seconds) seconds"
        }
    }
    
    // MARK: - Auto-Save Functions
    
    private func autoSaveSettings() {
        kioskStore.timeoutDuration = timeoutDuration
        kioskStore.saveSettings()
    }
}

// MARK: - Supporting Views

struct TimeoutOptionCard: View {
    let value: String
    let label: String
    let isSelected: Bool
    let isRecommended: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.blue : Color(.separator), lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    if isSelected {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 12, height: 12)
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    
                    if isRecommended {
                        Text("Recommended")
                            .font(.caption)
                            .foregroundStyle(.blue)
                            .fontWeight(.medium)
                    }
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.blue)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue.opacity(0.05) : Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct TimeoutSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        TimeoutSettingsView()
            .environmentObject(KioskStore())
    }
}
