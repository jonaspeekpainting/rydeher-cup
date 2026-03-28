import SwiftUI

struct BiometricLockView: View {
  @EnvironmentObject private var sessionManager: SessionManager
  @State private var isUnlocking = false

  var body: some View {
    VStack(spacing: 28) {
      Spacer()

      Image(systemName: BiometricAuth.biometricType == .faceID ? "faceid" : "lock.fill")
        .font(.system(size: 52))
        .symbolRenderingMode(.hierarchical)
        .foregroundStyle(.tint)

      Text("Unlock RyderHer Cup")
        .font(.title2.weight(.semibold))

      Text(BiometricAuth.reasonMessage())
        .font(.body)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 32)

      if let err = sessionManager.authError {
        Text(err)
          .font(.footnote)
          .foregroundStyle(.red)
          .multilineTextAlignment(.center)
          .padding(.horizontal)
      }

      Button {
        Task {
          isUnlocking = true
          defer { isUnlocking = false }
          await sessionManager.unlockWithBiometrics()
        }
      } label: {
        if isUnlocking {
          ProgressView()
            .frame(maxWidth: .infinity)
        } else {
          Text("Unlock")
            .font(.headline)
            .frame(maxWidth: .infinity)
        }
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.large)
      .padding(.horizontal, 40)
      .padding(.top, 8)

      Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(.systemGroupedBackground))
    .task {
      await sessionManager.unlockWithBiometrics()
    }
  }
}
