//
//  PermissionTestView.swift
//  ShulPad
//
//  Created by Zalman Rodkin on 6/20/25.
//

import SwiftUI
import CoreLocation

// A simple, self-contained view to test permissions.
struct PermissionTestView: View {
    @StateObject private var model = PermissionTestViewModel()

    var body: some View {
        VStack(spacing: 20) {
            Text("Permission Status")
                .font(.largeTitle)

            // Display the raw status value from CoreLocation
            Text("CLAuthorizationStatus: \(model.authStatus.rawValue)")
                .font(.headline)
                .padding()
                .background(Color.secondary.opacity(0.2))
                .cornerRadius(10)

            // Display a human-readable description of the status
            Text(model.statusDescription)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            // A button to trigger the permission request
            Button("Request Location Permission") {
                model.requestPermission()
            }
            .font(.headline)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .padding()
    }
}

// A view model to contain all the CoreLocation logic.
@MainActor
class PermissionTestViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var authStatus: CLAuthorizationStatus
    @Published var statusDescription: String = "Not yet requested."
    
    private let locationManager: CLLocationManager

    override init() {
        locationManager = CLLocationManager()
        authStatus = locationManager.authorizationStatus
        super.init()
        locationManager.delegate = self
        updateStatusDescription()
    }

    func requestPermission() {
        print("--- TEST: Requesting location permission... ---")
        locationManager.requestWhenInUseAuthorization()
        print("--- TEST: Call to request permission has been made. ---")
    }
    
    // This delegate method is called by iOS when the permission status changes.
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        self.authStatus = manager.authorizationStatus
        print("--- TEST: locationManagerDidChangeAuthorization fired! New status raw value: \(authStatus.rawValue) ---")
        updateStatusDescription()
    }
    
    private func updateStatusDescription() {
        switch authStatus {
        case .notDetermined:
            statusDescription = "Permission has not been requested yet."
        case .restricted:
            statusDescription = "Permission is restricted (e.g., by parental controls)."
        case .denied:
            statusDescription = "Permission was explicitly denied. Please enable it in Settings."
        case .authorizedAlways:
            statusDescription = "Permission granted: Always."
        case .authorizedWhenInUse:
            statusDescription = "Permission granted: When In Use."
        @unknown default:
            statusDescription = "Unknown status."
        }
    }
}
