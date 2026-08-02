import SwiftUI

struct WelcomeView: View {
  let onSignIn: () -> Void
  let onSignUp: () -> Void

  var body: some View {
    VStack(spacing: 0) {
      Spacer(minLength: 40)

      BrandLogoMark(maxWidth: 260, showsWordmark: true)
        .padding(.horizontal, 36)

      Text("Tournament hub for scores, pairings, and updates.")
        .font(.body)
        .foregroundStyle(BrandColors.onPrimary.opacity(0.78))
        .multilineTextAlignment(.center)
        .padding(.horizontal, 36)
        .padding(.top, 16)

      Spacer()

      VStack(spacing: 12) {
        Button(action: onSignUp) {
          Text("Create account")
        }
        .buttonStyle(BrandPrimaryButtonStyle())

        Button(action: onSignIn) {
          Text("Sign in")
        }
        .buttonStyle(BrandSecondaryButtonStyle())
      }
      .padding(.horizontal, 28)
      .padding(.bottom, 40)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(BrandColors.primary.ignoresSafeArea())
    .toolbar(.hidden, for: .navigationBar)
  }
}
