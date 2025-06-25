//
//  PlanChangeView.swift
//  ShulPad
//
//  Created by Zalman Rodkin on 6/22/25.
//

import SwiftUI

struct PlanChangeView: View {
    let currentPlan: String
    let currentDeviceCount: Int
    let onPlanChange: (String, Int) -> Void
    
    @State private var selectedPlan: String
    @State private var selectedDeviceCount: Int
    @Environment(\.presentationMode) var presentationMode
    
    init(currentPlan: String, currentDeviceCount: Int, onPlanChange: @escaping (String, Int) -> Void) {
        self.currentPlan = currentPlan
        self.currentDeviceCount = currentDeviceCount
        self.onPlanChange = onPlanChange
        self._selectedPlan = State(initialValue: currentPlan)
        self._selectedDeviceCount = State(initialValue: currentDeviceCount)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Change Your Plan")
                    .font(.title)
                    .fontWeight(.semibold)
                
                // Plan Selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Plan Type")
                        .font(.headline)
                    
                    Picker("Plan", selection: $selectedPlan) {
                        Text("Monthly").tag("monthly")
                        Text("Yearly").tag("yearly")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                // Device Count
                VStack(alignment: .leading, spacing: 8) {
                    Text("Number of Devices")
                        .font(.headline)
                    
                    Stepper(value: $selectedDeviceCount, in: 1...10) {
                        Text("\(selectedDeviceCount) device\(selectedDeviceCount == 1 ? "" : "s")")
                    }
                }
                
                Spacer()
                
                Button("Update Plan") {
                    onPlanChange(selectedPlan, selectedDeviceCount)
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding()
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
}
