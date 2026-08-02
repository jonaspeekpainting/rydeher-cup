import SwiftUI

struct BiometricLockView: View {
  @EnvironmentObject private var sessionManager: SessionManager
  @State private var isUnlocking = false

  var body: some View {
    VStack(spacing: 24) {
      Spacer()

      BrandLogoMark(maxWidth: 200)

      Image(systemName: BiometricAuth.biometricType == .faceID ? "faceid" : "lock.fill")
        .font(.system(size: 40))
        .foregroundStyle(BrandColors.onPrimary.opacity(0.9))
        .padding(.top, 8)

      Text("Unlock Ryde-Her Cup")
        .font(.title3.weight(.semibold))
        .foregroundStyle(BrandColors.onPrimary)

      Text(BiometricAuth.reasonMessage())
        .font(.body)
        .foregroundStyle(BrandColors.onPrimary.opacity(0.75))
        .multilineTextAlignment(.center)
        .padding(.horizontal, 32)

      if let err = sessionManager.authError {
        Text(err)
          .font(.footnote)
          .foregroundStyle(Color(red: 1, green: 0.72, blue: 0.72))
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
            .tint(BrandColors.onPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        } else {
          Text("Unlock")
        }
      }
      .buttonStyle(BrandPrimaryButtonStyle())
      .padding(.horizontal, 40)
      .padding(.top, 8)

      Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(BrandColors.primary.ignoresSafeArea())
    .task {
      await sessionManager.unlockWithBiometrics()
    }
  }
}
