import SwiftUI

struct WelcomeView: View {
  let onSignIn: () -> Void
  let onSignUp: () -> Void

  var body: some View {
    VStack(spacing: 32) {
      Spacer(minLength: 24)

      VStack(spacing: 12) {
        Image(systemName: "figure.golf")
          .font(.system(size: 56))
          .symbolRenderingMode(.hierarchical)
          .foregroundStyle(.tint)

        Text("RyderHer Cup")
          .font(.largeTitle.weight(.bold))
          .multilineTextAlignment(.center)

        Text("Tournament hub for scores, pairings, and updates.")
          .font(.body)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
          .padding(.horizontal)
      }

      Spacer()

      VStack(spacing: 14) {
        Button(action: onSignUp) {
          Text("Create account")
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)

        Button(action: onSignIn) {
          Text("Sign in")
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
      }
      .padding(.horizontal, 24)
      .padding(.bottom, 32)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(.systemGroupedBackground))
    .toolbar(.hidden, for: .navigationBar)
  }
}
