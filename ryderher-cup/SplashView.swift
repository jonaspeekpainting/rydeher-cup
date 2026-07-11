import SwiftUI

struct SplashView: View {
  var body: some View {
    ZStack {
      BrandColors.splashBackground
        .ignoresSafeArea()

      Image("BrandLogo")
        .resizable()
        .scaledToFit()
        .padding(.horizontal, 48)
        .accessibilityLabel("RyderHer Cup")
    }
  }
}

#Preview {
  SplashView()
}
