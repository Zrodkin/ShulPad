import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var donationViewModel: DonationViewModel
    @EnvironmentObject private var kioskStore: KioskStore
    @State private var navigateToDonation = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 🆕 SIMPLIFIED: Only show home page content since admin access is handled in ContentView
                homePageContent
            }
            .contentShape(Rectangle()) // Make the entire view tappable
            .onTapGesture {
                navigateToDonation = true
            }
            .onAppear {
                // Reset donation state when returning to home
                donationViewModel.resetDonation()
            }
            .navigationDestination(isPresented: $navigateToDonation) {
                DonationSelectionView()
            }
        }
        .id("homeNavigation") // Add an ID to the NavigationStack for consistent state
    }
    
    // Extract home page content to a computed property for cleaner code
    // CONSISTENT LAYOUT: Using standard positioning
    private var homePageContent: some View {
        GeometryReader { geometry in
            ZStack {
                // Background image with zoom and pan support
                if let backgroundImage = kioskStore.backgroundImage {
                    Image(uiImage: backgroundImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .scaleEffect(kioskStore.backgroundImageZoom)
                        .offset(
                            x: kioskStore.backgroundImagePanX,
                            y: kioskStore.backgroundImagePanY
                        )
                        .edgesIgnoringSafeArea(.all)
                } else {
                    Image("logoImage")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .edgesIgnoringSafeArea(.all)
                        .onAppear {
                            if UIImage(named: "logoImage") == nil {
                                print("Warning: 'logoImage' not found in asset catalog.")
                            }
                        }
                }
                
                Color.black.opacity(0.3)
                    .edgesIgnoringSafeArea(.all)
                
                // UPDATED: Dynamic text positioning
                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: KioskLayoutConstants.topContentOffset)
                    
                    VStack(spacing: 10) {
                        Text(kioskStore.headline)
                            .font(.system(size: kioskStore.headlineTextSize, weight: .bold))
                            .foregroundColor(.white)
                            .shadow(radius: 10)
                            .multilineTextAlignment(.center)
                        
                        if !kioskStore.subtext.isEmpty {
                            Text(kioskStore.subtext)
                                .font(.system(size: kioskStore.subtextTextSize))
                                .foregroundColor(.white)
                                .shadow(radius: 5)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(maxWidth: KioskLayoutConstants.maxContentWidth)
                    .padding(.horizontal, KioskLayoutConstants.contentHorizontalPadding)
                    .offset(y: KioskLayoutConstants.calculateVerticalOffset(
                        position: kioskStore.textVerticalPosition,
                        fineTuning: kioskStore.textVerticalFineTuning,
                        screenHeight: geometry.size.height
                    ))
                    
                    Spacer()
                        .frame(height: KioskLayoutConstants.bottomSafeArea)
                }
            }
            .contentShape(Rectangle())
        }
    }
}

// MARK: - Preview
struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
            .environmentObject(DonationViewModel())
            .environmentObject(KioskStore())
    }
}
