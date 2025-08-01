import SwiftUI
import PhotosUI

struct HomePageSettingsView: View {
    @EnvironmentObject private var kioskStore: KioskStore
    @State private var headline: String = ""
    @State private var subtext: String = ""
    @State private var homePageEnabled = true
    @State private var showingBackgroundImagePicker = false
    @State private var showToast = false
    @State private var toastMessage = "Settings saved"
    
    @State private var textVerticalPosition: KioskLayoutConstants.VerticalTextPosition = .center
    @State private var textVerticalFineTuning: Double = 0.0
    @State private var headlineTextSize: Double = KioskLayoutConstants.defaultHeadlineSize
    @State private var subtextTextSize: Double = KioskLayoutConstants.defaultSubtextSize
    
    // Layout section state
    @State private var isLayoutSectionExpanded = false
    @State private var showLayoutSaveToast = false
    
    // Track original values to detect changes
    @State private var originalTextVerticalPosition: KioskLayoutConstants.VerticalTextPosition = .center
    @State private var originalTextVerticalFineTuning: Double = 0.0
    @State private var originalHeadlineTextSize: Double = KioskLayoutConstants.defaultHeadlineSize
    @State private var originalSubtextTextSize: Double = KioskLayoutConstants.defaultSubtextSize
    
    // Auto-save timer
    @State private var autoSaveTimer: Timer?
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                // Page header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "house.fill")
                            .font(.title2)
                            .foregroundStyle(.blue)
                        
                        Text("Home Page Settings")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        // Enable/disable toggle
                        Toggle("Enabled", isOn: $homePageEnabled)
                            .toggleStyle(SwitchToggleStyle(tint: .blue))
                            .onChange(of: homePageEnabled) { _, newValue in
                                scheduleAutoSave()
                            }
                    }
                    
                    Text("Customize the appearance of your donation kiosk home screen")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                
                // Main content in cards
                VStack(spacing: 20) {
                    // Background Image & Preview Card
                    SettingsCard(title: "Background Image", icon: "photo.fill") {
                        VStack(spacing: 16) {
                            // Simple preview
                            PreviewContent(
                                backgroundImage: kioskStore.backgroundImage,
                                logoImage: kioskStore.logoImage,
                                headline: headline.isEmpty ? "Tap to Donate" : headline,
                                subtext: subtext,
                                textVerticalPosition: textVerticalPosition,
                                textVerticalFineTuning: textVerticalFineTuning,
                                headlineTextSize: calculatePreviewHeadlineSize(),
                                subtextTextSize: calculatePreviewSubtextSize(),
                                height: 300
                            )
                            
                            // Action buttons
                            HStack(spacing: 12) {
                                Button(action: {
                                    showingBackgroundImagePicker = true
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "photo.badge.plus")
                                            .font(.system(size: 16, weight: .medium))
                                        Text(kioskStore.backgroundImage == nil ? "Add Image" : "Change Image")
                                            .fontWeight(.medium)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color(.secondarySystemBackground))
                                    .foregroundStyle(.primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                                
                                if kioskStore.backgroundImage != nil {
                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            kioskStore.backgroundImage = nil
                                            autoSaveSettings()
                                        }
                                    }) {
                                        HStack(spacing: 8) {
                                            Image(systemName: "trash")
                                                .font(.system(size: 16, weight: .medium))
                                            Text("Remove")
                                                .fontWeight(.medium)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(Color.red.opacity(0.1))
                                        .foregroundStyle(.red)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                    }
                                }
                            }
                        }
                    }
                    
                    // Text Content Card
                    SettingsCard(title: "Text Content", icon: "textformat") {
                        VStack(spacing: 24) {
                            // Headline Section
                            VStack(alignment: .leading, spacing: 12) {
                                SectionHeader(title: "Main Headline", subtitle: "Primary text displayed on the home screen")
                                
                                TextField("Enter headline", text: $headline)
                                    .textFieldStyle(ModernTextFieldStyle())
                                    .onChange(of: headline) { _, _ in
                                        scheduleAutoSave()
                                    }
                            }
                            
                            // Subtext Section
                            VStack(alignment: .leading, spacing: 12) {
                                SectionHeader(title: "Supporting Text", subtitle: "Additional context or call-to-action")
                                
                                ZStack(alignment: .topLeading) {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(.secondarySystemBackground))
                                        .frame(minHeight: 100)
                                    
                                    TextEditor(text: $subtext)
                                        .padding(12)
                                        .background(Color.clear)
                                        .onChange(of: subtext) { _, _ in
                                            scheduleAutoSave()
                                        }
                                    
                                    if subtext.isEmpty {
                                        Text("Enter supporting text...")
                                            .foregroundStyle(.tertiary)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 20)
                                            .allowsHitTesting(false)
                                    }
                                }
                            }
                        }
                    }
                    
                    // Collapsible Layout & Positioning Section
                    CollapsibleLayoutSection(
                        isExpanded: $isLayoutSectionExpanded,
                        textVerticalPosition: $textVerticalPosition,
                        textVerticalFineTuning: $textVerticalFineTuning,
                        headlineTextSize: $headlineTextSize,
                        subtextTextSize: $subtextTextSize,
                        showSaveToast: $showLayoutSaveToast,
                        hasChanges: hasLayoutChanges,
                        onSave: saveLayoutSettings,
                        onRevertToDefault: revertLayoutToDefault,
                        backgroundImage: kioskStore.backgroundImage,
                        headline: headline.isEmpty ? "Sample Headline" : headline,
                        subtext: subtext
                    )
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            headline = kioskStore.headline
            subtext = kioskStore.subtext
            homePageEnabled = kioskStore.homePageEnabled
            textVerticalPosition = kioskStore.textVerticalPosition
            textVerticalFineTuning = kioskStore.textVerticalFineTuning
            headlineTextSize = kioskStore.headlineTextSize
            subtextTextSize = kioskStore.subtextTextSize
            
            // Store original values for change detection
            originalTextVerticalPosition = kioskStore.textVerticalPosition
            originalTextVerticalFineTuning = kioskStore.textVerticalFineTuning
            originalHeadlineTextSize = kioskStore.headlineTextSize
            originalSubtextTextSize = kioskStore.subtextTextSize
        }
        .sheet(isPresented: $showingBackgroundImagePicker) {
            ImagePicker(selectedImage: $kioskStore.backgroundImage, isPresented: $showingBackgroundImagePicker)
                .onDisappear {
                    if kioskStore.backgroundImage != nil {
                        autoSaveSettings()
                    }
                }
        }
        .overlay(
            Group {
                if showLayoutSaveToast {
                    ToastNotification(message: "Layout settings saved")
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: showLayoutSaveToast)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                showLayoutSaveToast = false
                            }
                        }
                }
            },
            alignment: .top
        )
    }
    
    // MARK: - Preview Calculation Methods
    
    private func calculateTextVerticalPosition(in size: CGSize) -> CGFloat {
        let basePosition: CGFloat
        
        switch textVerticalPosition {
        case .top:
            basePosition = size.height * 0.25
        case .center:
            basePosition = size.height * 0.5
        case .bottom:
            basePosition = size.height * 0.75
        }
        
        // Apply fine tuning correctly
        let scaledFineTuning = textVerticalFineTuning * (size.height / UIScreen.main.bounds.height)
        return basePosition + scaledFineTuning
    }
    
    private func calculatePreviewHeadlineSize() -> CGFloat {
        // Scale down the actual size for preview
        return headlineTextSize * 0.4
    }
    
    private func calculatePreviewSubtextSize() -> CGFloat {
        // Scale down the actual size for preview
        return subtextTextSize * 0.4
    }
    
    private func calculateTextSpacing() -> CGFloat {
        // Dynamic spacing based on text sizes
        return (headlineTextSize + subtextTextSize) * 0.1
    }
    
    // MARK: - Layout Settings Methods
    
    private var hasLayoutChanges: Bool {
        return textVerticalPosition != originalTextVerticalPosition ||
        textVerticalFineTuning != originalTextVerticalFineTuning ||
        headlineTextSize != originalHeadlineTextSize ||
        subtextTextSize != originalSubtextTextSize
    }
    
    private func saveLayoutSettings() {
        kioskStore.textVerticalPosition = textVerticalPosition
        kioskStore.textVerticalFineTuning = textVerticalFineTuning
        kioskStore.headlineTextSize = headlineTextSize
        kioskStore.subtextTextSize = subtextTextSize
        
        kioskStore.saveSettings()
        
        // Update original values after saving
        originalTextVerticalPosition = textVerticalPosition
        originalTextVerticalFineTuning = textVerticalFineTuning
        originalHeadlineTextSize = headlineTextSize
        originalSubtextTextSize = subtextTextSize
        
        showLayoutSaveToast = true
    }
    
    private func revertLayoutToDefault() {
        textVerticalPosition = .center
        textVerticalFineTuning = 0.0
        headlineTextSize = KioskLayoutConstants.defaultHeadlineSize
        subtextTextSize = KioskLayoutConstants.defaultSubtextSize
    }
    
    // MARK: - Auto-Save Functions
    
    private func scheduleAutoSave() {
        // Cancel existing timer
        autoSaveTimer?.invalidate()
        
        // Schedule new timer with 1 second delay
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
            autoSaveSettings()
        }
    }
    
    private func autoSaveSettings() {
        kioskStore.headline = headline
        kioskStore.subtext = subtext
        kioskStore.homePageEnabled = homePageEnabled
        
        kioskStore.saveSettings()
    }
    
    // MARK: - Preview Content Component
    
    struct PreviewContent: View {
        let backgroundImage: UIImage?
        let logoImage: UIImage?
        let headline: String
        let subtext: String
        let textVerticalPosition: KioskLayoutConstants.VerticalTextPosition
        let textVerticalFineTuning: Double
        let headlineTextSize: CGFloat
        let subtextTextSize: CGFloat
        let height: CGFloat
        
        var body: some View {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemBackground))
                    .frame(height: height)
                    .aspectRatio(16/9, contentMode: .fit)
                
                // Background image if available
                if let backgroundImage = backgroundImage {
                    Image(uiImage: backgroundImage)
                        .resizable()
                        .scaledToFill()
                        .frame(height: height)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                } else {
                    // Empty state for when no background image is set
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.secondarySystemBackground))
                        .frame(height: height)
                        .overlay(
                            VStack(spacing: 12) {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.system(size: 40))
                                    .foregroundStyle(.blue)
                                
                                VStack(spacing: 4) {
                                    Text("Add Background Image")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.primary)
                                    
                                    Text("Tap below to select from your photos")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color(.separator), lineWidth: 1)
                        )
                }
                
                // Only show overlay and text if we have a background image
                if backgroundImage != nil {
                    // Dark overlay
                    Rectangle()
                        .fill(.black.opacity(0.4))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    
                    // Text content positioned according to settings
                    GeometryReader { geometry in
                        VStack(spacing: calculateTextSpacing()) {
                            Text(headline)
                                .font(.system(size: headlineTextSize, weight: .bold))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .shadow(radius: 5)
                            
                            if !subtext.isEmpty {
                                Text(subtext)
                                    .font(.system(size: subtextTextSize))
                                    .foregroundColor(.white.opacity(0.9))
                                    .multilineTextAlignment(.center)
                                    .shadow(radius: 3)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .position(
                            x: geometry.size.width / 2,
                            y: calculateTextVerticalPosition(in: geometry.size)
                        )
                    }
                }
            }
        }
        
        // Consistent positioning calculation
        private func calculateTextVerticalPosition(in size: CGSize) -> CGFloat {
            let basePosition: CGFloat
            
            switch textVerticalPosition {
            case .top:
                basePosition = size.height * 0.25
            case .center:
                basePosition = size.height * 0.5
            case .bottom:
                basePosition = size.height * 0.75
            }
            
            // Apply fine tuning correctly
            let scaledFineTuning = textVerticalFineTuning * (size.height / UIScreen.main.bounds.height)
            return basePosition + scaledFineTuning
        }
        
        private func calculateTextSpacing() -> CGFloat {
            // Dynamic spacing based on text sizes and preview height
            return (headlineTextSize + subtextTextSize) * 0.1 * (height / 300)
        }
    }
    
    // MARK: - Collapsible Layout Section
    
    struct CollapsibleLayoutSection: View {
        @Binding var isExpanded: Bool
        @Binding var textVerticalPosition: KioskLayoutConstants.VerticalTextPosition
        @Binding var textVerticalFineTuning: Double
        @Binding var headlineTextSize: Double
        @Binding var subtextTextSize: Double
        @Binding var showSaveToast: Bool
        
        let hasChanges: Bool
        let onSave: () -> Void
        let onRevertToDefault: () -> Void
        let backgroundImage: UIImage?
        let headline: String
        let subtext: String
        
        // Live preview states
        @State private var isAdjustingPosition = false
        @State private var isAdjustingHeadlineSize = false
        @State private var isAdjustingSubtextSize = false
        
        // Store the values being adjusted for the preview
        @State private var previewTextVerticalFineTuning: Double = 0.0
        @State private var previewHeadlineTextSize: Double = 90.0
        @State private var previewSubtextTextSize: Double = 30.0
        
        // Store slider frame for consistent positioning
        @State private var positionSliderFrame: CGRect = .zero
        @State private var headlineSliderFrame: CGRect = .zero
        @State private var subtextSliderFrame: CGRect = .zero
        
        // Computed property to check if settings are not default
        private var isNotDefault: Bool {
            return textVerticalPosition != .center ||
            textVerticalFineTuning != 0.0 ||
            headlineTextSize != KioskLayoutConstants.defaultHeadlineSize ||
            subtextTextSize != KioskLayoutConstants.defaultSubtextSize
        }
        
        var body: some View {
            ZStack {
                // Main settings card
                VStack(alignment: .leading, spacing: 20) {
                    // Header with expand/collapse button
                    Button(action: {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            isExpanded.toggle()
                        }
                    }) {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.blue.opacity(0.1))
                                    .frame(width: 32, height: 32)
                                
                                Image(systemName: "rectangle.and.pencil.and.ellipsis")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(.blue)
                            }
                            
                            Text("Layout & Positioning")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.down")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.secondary)
                                .rotationEffect(.degrees(isExpanded ? 180 : 0))
                                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isExpanded)
                        }
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Collapsible content
                    if isExpanded {
                        VStack(spacing: 24) {
                            // Vertical Position Section
                            VStack(alignment: .leading, spacing: 16) {
                                SectionHeader(title: "Text Position", subtitle: "Choose where your text appears on screen")
                                
                                // Position presets
                                VStack(spacing: 12) {
                                    ForEach(KioskLayoutConstants.VerticalTextPosition.allCases, id: \.self) { position in
                                        PositionOptionCard(
                                            position: position,
                                            isSelected: textVerticalPosition == position,
                                            onSelect: {
                                                textVerticalPosition = position
                                            }
                                        )
                                    }
                                }
                                
                                // Fine-tuning slider with proper frame tracking
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Fine Adjustment")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    
                                    HStack {
                                        Text("Higher")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        
                                        Slider(
                                            value: $textVerticalFineTuning,
                                            in: -50...50,
                                            step: 5,
                                            onEditingChanged: { editing in
                                                isAdjustingPosition = editing
                                                if editing {
                                                    previewTextVerticalFineTuning = textVerticalFineTuning
                                                }
                                            }
                                        )
                                        .onChange(of: textVerticalFineTuning) { _, newValue in
                                            if isAdjustingPosition {
                                                previewTextVerticalFineTuning = newValue
                                            }
                                        }
                                        .background(
                                            GeometryReader { geometry in
                                                Color.clear
                                                    .onAppear {
                                                        positionSliderFrame = geometry.frame(in: .global)
                                                    }
                                                    .onChange(of: geometry.frame(in: .global)) { _, newFrame in
                                                        positionSliderFrame = newFrame
                                                    }
                                            }
                                        )
                                        
                                        Text("Lower")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    Text("Current: \(Int(textVerticalFineTuning)) points")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            
                            Divider()
                            
                            // Text Size Section
                            VStack(alignment: .leading, spacing: 16) {
                                SectionHeader(title: "Text Size", subtitle: "Adjust the size of your headline and supporting text")
                                
                                VStack(spacing: 16) {
                                    // Headline size with proper frame tracking
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Text("Headline Size")
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                            
                                            Spacer()
                                            
                                            Text("\(Int(headlineTextSize))pt")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        
                                        Slider(
                                            value: $headlineTextSize,
                                            in: KioskLayoutConstants.headlineSizeRange,
                                            step: 5,
                                            onEditingChanged: { editing in
                                                isAdjustingHeadlineSize = editing
                                                if editing {
                                                    previewHeadlineTextSize = headlineTextSize
                                                }
                                            }
                                        )
                                        .onChange(of: headlineTextSize) { _, newValue in
                                            if isAdjustingHeadlineSize {
                                                previewHeadlineTextSize = newValue
                                            }
                                        }
                                        .background(
                                            GeometryReader { geometry in
                                                Color.clear
                                                    .onAppear {
                                                        headlineSliderFrame = geometry.frame(in: .global)
                                                    }
                                                    .onChange(of: geometry.frame(in: .global)) { _, newFrame in
                                                        headlineSliderFrame = newFrame
                                                    }
                                            }
                                        )
                                    }
                                    
                                    // Subtext size with proper frame tracking
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Text("Supporting Text Size")
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                            
                                            Spacer()
                                            
                                            Text("\(Int(subtextTextSize))pt")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        
                                        Slider(
                                            value: $subtextTextSize,
                                            in: KioskLayoutConstants.subtextSizeRange,
                                            step: 2,
                                            onEditingChanged: { editing in
                                                isAdjustingSubtextSize = editing
                                                if editing {
                                                    previewSubtextTextSize = subtextTextSize
                                                }
                                            }
                                        )
                                        .onChange(of: subtextTextSize) { _, newValue in
                                            if isAdjustingSubtextSize {
                                                previewSubtextTextSize = newValue
                                            }
                                        }
                                        .background(
                                            GeometryReader { geometry in
                                                Color.clear
                                                    .onAppear {
                                                        subtextSliderFrame = geometry.frame(in: .global)
                                                    }
                                                    .onChange(of: geometry.frame(in: .global)) { _, newFrame in
                                                        subtextSliderFrame = newFrame
                                                    }
                                            }
                                        )
                                    }
                                }
                            }
                            
                            Divider()
                            
                            // Action buttons
                            HStack(spacing: 12) {
                                Button("Revert to Default") {
                                    onRevertToDefault()
                                }
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(isNotDefault ? Color.blue : Color(.systemGray4))
                                .foregroundStyle(isNotDefault ? .white : .secondary)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .animation(.easeOut(duration: 0.1), value: isNotDefault)
                                .disabled(!isNotDefault)
                                
                                Button("Save Layout") {
                                    onSave()
                                }
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(hasChanges ? Color.blue : Color(.systemGray4))
                                .foregroundStyle(hasChanges ? .white : .secondary)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .animation(.easeOut(duration: 0.1), value: hasChanges)
                                .disabled(!hasChanges)
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(24)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                
                // Live preview overlay positioned consistently above slider
                if isAdjustingPosition || isAdjustingHeadlineSize || isAdjustingSubtextSize {
                    LivePreviewOverlay(
                        backgroundImage: backgroundImage,
                        headline: headline,
                        subtext: subtext,
                        textVerticalPosition: textVerticalPosition,
                        textVerticalFineTuning: isAdjustingPosition ? previewTextVerticalFineTuning : textVerticalFineTuning,
                        headlineTextSize: isAdjustingHeadlineSize ? previewHeadlineTextSize : headlineTextSize,
                        subtextTextSize: isAdjustingSubtextSize ? previewSubtextTextSize : subtextTextSize
                    )
                    .position(
                        x: getActiveSliderCenter().x,
                        y: getActiveSliderCenter().y - 100
                    )
                    .transition(.opacity.combined(with: .scale))
                    .animation(.easeInOut(duration: 0.2), value: isAdjustingPosition || isAdjustingHeadlineSize || isAdjustingSubtextSize)
                }
            }
        }
        
        // Get the center position of the currently active slider
        private func getActiveSliderCenter() -> CGPoint {
            let activeFrame: CGRect
            
            if isAdjustingPosition {
                activeFrame = positionSliderFrame
            } else if isAdjustingHeadlineSize {
                activeFrame = headlineSliderFrame
            } else if isAdjustingSubtextSize {
                activeFrame = subtextSliderFrame
            } else {
                activeFrame = .zero
            }
            
            return CGPoint(
                x: activeFrame.midX,
                y: activeFrame.midY
            )
        }
    }
    
    // MARK: - Live Preview Overlay
    
    struct LivePreviewOverlay: View {
        let backgroundImage: UIImage?
        let headline: String
        let subtext: String
        let textVerticalPosition: KioskLayoutConstants.VerticalTextPosition
        let textVerticalFineTuning: Double
        let headlineTextSize: Double
        let subtextTextSize: Double
        
        var body: some View {
            ZStack {
                // Background - Made larger for better visibility
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
                    .frame(width: 180, height: 120)
                
                // Background image if available
                if let backgroundImage = backgroundImage {
                    Image(uiImage: backgroundImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 180, height: 120)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    // Dark overlay
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.black.opacity(0.4))
                        .frame(width: 180, height: 120)
                }
                
                // Text overlay - Larger text for better readability
                                VStack(spacing: 4) {
                                    Text(headline.isEmpty ? "Sample Headline" : headline)
                                        .font(.system(size: max(8, headlineTextSize * 0.18), weight: .bold))
                                        .foregroundColor(.white)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                        .shadow(radius: 2)
                                    
                                    if !subtext.isEmpty {
                                        Text(subtext)
                                            .font(.system(size: max(6, subtextTextSize * 0.18)))
                                            .foregroundColor(.white.opacity(0.9))
                                            .multilineTextAlignment(.center)
                                            .lineLimit(2)
                                            .shadow(radius: 1)
                                    }
                                }
                                .frame(width: 160, height: 100)
                                .offset(y: calculateTextOffset())
                            }
                            .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        
                        // Consistent text offset calculation with larger range
                        private func calculateTextOffset() -> CGFloat {
                            let range: CGFloat = 25 // Increased movement range for larger preview
                            
                            let baseOffset: CGFloat
                            switch textVerticalPosition {
                            case .top:
                                baseOffset = -range * 0.7
                            case .center:
                                baseOffset = 0
                            case .bottom:
                                baseOffset = range * 0.7
                            }
                            
                            // Apply fine tuning correctly
                            let fineTuningOffset = (textVerticalFineTuning * 0.3)
                            
                            return baseOffset + fineTuningOffset
                        }
                    }
                }
// Add this at the bottom of your file, after the ToastNotification struct
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Binding var isPresented: Bool
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 1
        
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.isPresented = false
            
            guard let result = results.first else { return }
            
            result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
                if let image = object as? UIImage {
                    DispatchQueue.main.async {
                        self?.parent.selectedImage = image
                    }
                }
            }
        }
    }
}
