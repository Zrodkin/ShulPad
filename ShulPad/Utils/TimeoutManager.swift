//
//  TimeoutManager.swift
//  CharityPad123
//
//  Created by Zalman Rodkin on 6/9/25.
//

import SwiftUI
import Combine

/// Manager for handling automatic timeouts and returning to home view
class TimeoutManager: ObservableObject {
    @Published var isActive = false
    private var timer: Timer?
    private var timeoutDuration: TimeInterval
    private var onTimeout: (() -> Void)?
    
    init(timeoutDuration: TimeInterval = 15.0) {  
        self.timeoutDuration = timeoutDuration
    }
    
    /// Set the timeout callback
    func setTimeoutCallback(_ callback: @escaping () -> Void) {
        self.onTimeout = callback
    }
    
    /// Start the timeout timer
    func startTimeout() {
        print("🕐 Starting timeout timer for \(timeoutDuration) seconds")
        stopTimeout() // Clear any existing timer
        isActive = true
        
        timer = Timer.scheduledTimer(withTimeInterval: timeoutDuration, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                print("⏰ Timeout reached - triggering callback")
                self.isActive = false
                self.onTimeout?()
            }
        }
    }
    
    /// Reset the timeout timer (restart from beginning)
    func resetTimeout() {
        if isActive {
            print("🔄 Resetting timeout timer")
            startTimeout()
        }
    }
    
    /// Stop the timeout timer
    func stopTimeout() {
        print("🛑 Stopping timeout timer")
        timer?.invalidate()
        timer = nil
        isActive = false
    }
    
    /// Update the timeout duration
    func updateDuration(_ newDuration: TimeInterval) {
        timeoutDuration = newDuration
        if isActive {
            startTimeout() // Restart with new duration if active
        }
    }
    
    deinit {
        stopTimeout()
    }
}
