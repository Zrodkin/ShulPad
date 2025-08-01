import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var donationViewModel: DonationViewModel
    @EnvironmentObject private var kioskStore: KioskStore
    @State private var navigateToDonation = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                homePageContent
            }
            .contentShape(Rectangle())
            .onTapGesture {
                navigateToDonation = true
            }
            .onAppear {
                donationViewModel.resetDonation()
            }
            .navigationDestination(isPresented: $navigateToDonation) {
                DonationSelectionView()
            }
        }
        .id("homeNavigation")
    }
    
    private var homePageContent: some View {
        GeometryReader { geometry in
            ZStack {
                // Background image
                if let backgroundImage = kioskStore.backgroundImage {
                    Image(uiImage: backgroundImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                } else {
                    // Fallback gradient or color
                    LinearGradient(
                        colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
                
                // Dark overlay
                Color.black.opacity(0.3)
                
                // Text content - properly centered
                VStack(spacing: 10) {
                    Text(kioskStore.headline.isEmpty ? "Tap to Donate" : kioskStore.headline)
                        .font(.system(size: kioskStore.headlineTextSize, weight: .bold))
                        .foregroundColor(.white)
                        .shadow(radius: 10)
                        .multilineTextAlignment(.center)
                    
                    if !kioskStore.subtext.isEmpty {
                        Text(kioskStore.subtext)
                            .font(.system(size: kioskStore.subtextTextSize))
                            .foregroundColor(.white.opacity(0.9))
                            .shadow(radius: 5)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 40)
                .position(
                    x: geometry.size.width / 2,
                    y: calculateTextPosition(in: geometry.size)
                )
            }
            .ignoresSafeArea()
        }
    }
    
    // Calculate text position based on settings
    private func calculateTextPosition(in size: CGSize) -> CGFloat {
        let basePosition: CGFloat
        
        switch kioskStore.textVerticalPosition {
        case .top:
            basePosition = size.height * 0.25
        case .center:
            basePosition = size.height * 0.5
        case .bottom:
            basePosition = size.height * 0.75
        }
        
        // Apply fine tuning
        return basePosition + kioskStore.textVerticalFineTuning
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
