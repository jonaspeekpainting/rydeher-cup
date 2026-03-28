import LocalAuthentication
import SwiftUI

struct SettingsView: View {
  @EnvironmentObject private var sessionManager: SessionManager
  @Environment(\.dismiss) private var dismiss

  private var biometricAvailable: Bool {
    LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
  }

  var body: some View {
    Form {
      Section {
        if let profile = sessionManager.profile {
          LabeledContent("Signed in as", value: profile.displayName)
          Text(profile.email)
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
      }

      Section {
        Toggle(
          "Biometric lock",
          isOn: Binding(
            get: { BiometricPreferences.lockEnabled },
            set: { BiometricPreferences.lockEnabled = $0 }
          )
        )
        .disabled(!biometricAvailable)
        if !biometricAvailable {
          Text("Biometrics are not available on this device.")
            .font(.footnote)
            .foregroundStyle(.secondary)
        } else {
          Text("When enabled, the app will ask for Face ID or Touch ID when you return after leaving the app.")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
      } header: {
        Text("Security")
      }

      Section {
        Button("Sign out", role: .destructive) {
          Task {
            await sessionManager.signOut()
            dismiss()
          }
        }
      }
    }
    .navigationTitle("Settings")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button("Done") { dismiss() }
      }
    }
  }
}
