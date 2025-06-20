//
//  KioskLayoutConstants.swift
//  CharityPad123
//
//  Created by Zalman Rodkin on 5/29/25.
//

import SwiftUI

struct KioskLayoutConstants {
    // Consistent spacing and positioning
    static let topContentOffset: CGFloat = 10         // Distance from top to main content
    static let titleBottomSpacing: CGFloat = 40       // Space below main title
    static let contentHorizontalPadding: CGFloat = 20 // Side margins
    static let maxContentWidth: CGFloat = 800         // Max width for content
    static let buttonSpacing: CGFloat = 16            // Space between buttons
    static let bottomSafeArea: CGFloat = 40           // Space from bottom
    
    // Font sizes (keeping your existing sizes)
    static let titleFontSize: CGFloat = 50
    static let titleFontSizeCompact: CGFloat = 32
    static let buttonFontSize: CGFloat = 24
    static let buttonFontSizeCompact: CGFloat = 20
    
    // Button dimensions
    static let buttonHeight: CGFloat = 80
    static let buttonHeightCompact: CGFloat = 60
    
    // MARK: - Text positioning presets (NEW)
    enum VerticalTextPosition: String, CaseIterable {
        case top = "top"
        case center = "center"
        case bottom = "bottom"
        
        var displayName: String {
            switch self {
            case .top: return "Top"
            case .center: return "Center"
            case .bottom: return "Bottom"
            }
        }
        
        var description: String {
            switch self {
            case .top: return "Near the top of screen"
            case .center: return "Center of screen (default)"
            case .bottom: return "Lower on screen"
            }
        }
    }
    
    // MARK: - Text customization constants (NEW)
    static let headlineSizeRange: ClosedRange<Double> = 60...120
    static let subtextSizeRange: ClosedRange<Double> = 20...50
    static let defaultHeadlineSize: Double = 90
    static let defaultSubtextSize: Double = 30

    // MARK: - Dynamic positioning calculation (NEW)
    static func calculateVerticalOffset(
        position: VerticalTextPosition,
        fineTuning: Double,
        screenHeight: CGFloat
    ) -> CGFloat {
        let baseOffset: CGFloat
        
        switch position {
        case .top:
            baseOffset = -(screenHeight * 0.15) // Move up from center
        case .center:
            baseOffset = 0 // Default center position
        case .bottom:
            baseOffset = screenHeight * 0.15   // Move down from center
        }
        
        // Apply fine-tuning (-50 to +50 points)
        return baseOffset + CGFloat(fineTuning)
    }
}
