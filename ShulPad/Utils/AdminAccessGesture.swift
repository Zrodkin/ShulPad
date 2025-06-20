//
//  AdminAccessGesture.swift
//  ShulPad
//
//  Created by Zalman Rodkin on 6/19/25.
//

import SwiftUI

struct AdminAccessGesture: ViewModifier {
    @AppStorage("isInAdminMode") private var isInAdminMode: Bool = true
    @State private var isLongPressing = false
    @State private var longPressProgress: Double = 0.0
    @State private var longPressStartTime = Date()
    @State private var longPressTimer: Timer? = nil
    @State private var showGuidedAccessAlert = false
    
    func body(content: Content) -> some View {
        content
            .overlay(adminOverlay)
            .simultaneousGesture(longPressGesture)
            .alert("Exit Kiosk Mode", isPresented: $showGuidedAccessAlert) {
                Button("Cancel", role: .cancel) {
                    resetLongPress()
                }
                Button("Exit", role: .destructive) {
                    UIAccessibility.requestGuidedAccessSession(enabled: false) { success in
                        if success {
                            isInAdminMode = true
                        }
                        resetLongPress()
                    }
                }
            } message: {
                Text("This device is in Guided Access mode. You'll need to enter the Guided Access passcode to exit.")
            }
    }
    
    // Admin overlay
    private var adminOverlay: some View {
        Group {
            if isLongPressing {
                Color.black.opacity(0.5)
                    .edgesIgnoringSafeArea(.all)
                    .overlay(
                        VStack {
                            ProgressView(value: longPressProgress)
                                .progressViewStyle(LinearProgressViewStyle(tint: .white))
                                .frame(width: 200)
                                .padding()
                            
                            Text("Hold to exit kiosk mode...")
                                .foregroundColor(.white)
                                .font(.headline)
                        }
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(10)
                    )
            }
        }
    }
    
    // Long press gesture
    private var longPressGesture: some Gesture {
        LongPressGesture(minimumDuration: 2.0)
            .onEnded { _ in
                // Start long press
                isLongPressing = true
                longPressStartTime = Date()
                
                // Cancel any existing timer
                longPressTimer?.invalidate()
                
                // Start a new timer
                longPressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
                    let elapsed = Date().timeIntervalSince(longPressStartTime)
                    longPressProgress = min(elapsed / 3.0, 1.0)
                    
                    // Check if we've reached the end
                    if elapsed >= 3.0 {
                        timer.invalidate()
                        longPressTimer = nil
                        
                        // Check if we're in guided access mode
                        if UIAccessibility.isGuidedAccessEnabled {
                            showGuidedAccessAlert = true
                        } else {
                            // Not in guided access, exit kiosk mode
                            isInAdminMode = true // ← Direct assignment
                        }
                    }
                }
            }
    }
    
    // Function to reset all long press state
    private func resetLongPress() {
        isLongPressing = false
        longPressProgress = 0.0
        longPressTimer?.invalidate()
        longPressTimer = nil
    }
}

// Extension to make it easy to use
extension View {
    func adminAccess() -> some View {
        modifier(AdminAccessGesture())
    }
}
