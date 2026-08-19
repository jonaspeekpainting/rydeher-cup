import LocalAuthentication
import SwiftUI

struct SettingsView: View {
  @EnvironmentObject private var sessionManager: SessionManager
  @Environment(\.dismiss) private var dismiss

  @State private var confirmDelete = false
  @State private var isDeleting = false
  @State private var deleteError: String?

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
          Text("On by default. The app asks for Face ID or Touch ID when you return after leaving the app.")
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
        .disabled(isDeleting)
      }

      Section {
        Button("Delete Account", role: .destructive) {
          confirmDelete = true
        }
        .disabled(isDeleting)
        Text("Permanently deletes your login and profile. This cannot be undone.")
          .font(.footnote)
          .foregroundStyle(.secondary)
      } header: {
        Text("Account")
      } footer: {
        if isDeleting {
          HStack(spacing: 8) {
            ProgressView()
            Text("Deleting account…")
          }
        }
      }
    }
    .navigationTitle("Settings")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button("Done") { dismiss() }
          .disabled(isDeleting)
      }
    }
    .interactiveDismissDisabled(isDeleting)
    .confirmationDialog(
      "Delete Account?",
      isPresented: $confirmDelete,
      titleVisibility: .visible
    ) {
      Button("Delete Account", role: .destructive) {
        Task { await performDelete() }
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text(
        "This permanently deletes your Ryde-Her Cup login and profile, including your email and GHIN number. Scores tied to your account may also be removed. You cannot undo this."
      )
    }
    .alert(
      "Could not delete account",
      isPresented: Binding(
        get: { deleteError != nil },
        set: { if !$0 { deleteError = nil } }
      )
    ) {
      Button("OK", role: .cancel) { deleteError = nil }
    } message: {
      Text(deleteError ?? "")
    }
  }

  private func performDelete() async {
    isDeleting = true
    defer { isDeleting = false }
    await sessionManager.deleteAccount()
    if sessionManager.session == nil {
      dismiss()
    } else {
      deleteError = sessionManager.authError ?? "Could not delete account."
    }
  }
}
