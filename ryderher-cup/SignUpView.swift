import SwiftUI

struct SignUpView: View {
  @EnvironmentObject private var sessionManager: SessionManager
  @State private var email = ""
  @State private var password = ""
  @State private var confirmPassword = ""
  @State private var tournamentCode = ""
  @State private var isSubmitting = false

  private var passwordsMatch: Bool {
    password == confirmPassword && !password.isEmpty
  }

  private var canSubmit: Bool {
    !email.isEmpty && password.count >= 8 && passwordsMatch
      && !tournamentCode.isEmpty && !isSubmitting
  }

  var body: some View {
    ScrollView {
      VStack(spacing: 20) {
        BrandLogoMark(maxWidth: 160)
          .padding(.top, 8)

        Text("Use the email you were invited with and the tournament code from your organizer.")
          .font(.footnote)
          .foregroundStyle(BrandColors.onPrimary.opacity(0.75))
          .multilineTextAlignment(.center)
          .padding(.horizontal, 28)

        VStack(alignment: .leading, spacing: 14) {
          sectionLabel("Account")
          brandedField("Email") {
            TextField("Email", text: $email)
              .textContentType(.emailAddress)
              .textInputAutocapitalization(.never)
              .keyboardType(.emailAddress)
          }
          brandedField("Password (min 8)") {
            SecureField("Password", text: $password)
              .textContentType(.newPassword)
          }
          brandedField("Confirm password") {
            SecureField("Confirm password", text: $confirmPassword)
              .textContentType(.newPassword)
          }
          brandedField("Tournament code") {
            TextField("Tournament code", text: $tournamentCode)
              .textInputAutocapitalization(.never)
          }

          if !password.isEmpty, !passwordsMatch {
            Text("Passwords do not match.")
              .font(.footnote)
              .foregroundStyle(Color(red: 1, green: 0.78, blue: 0.45))
          }

          if let err = sessionManager.authError {
            Text(err)
              .font(.footnote)
              .foregroundStyle(Color(red: 1, green: 0.72, blue: 0.72))
          }

          Button {
            Task {
              isSubmitting = true
              defer { isSubmitting = false }
              await sessionManager.signUp(
                email: email,
                password: password,
                tournamentCode: tournamentCode
              )
            }
          } label: {
            if isSubmitting {
              ProgressView()
                .tint(BrandColors.onPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            } else {
              Text("Create account")
            }
          }
          .buttonStyle(BrandPrimaryButtonStyle(isEnabled: canSubmit))
          .disabled(!canSubmit)
        }
        .padding(20)
        .background(BrandColors.primarySoft.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.horizontal, 20)
      }
      .padding(.bottom, 40)
    }
    .scrollDismissesKeyboard(.interactively)
    .background(BrandColors.primary.ignoresSafeArea())
    .navigationTitle("Create account")
    .navigationBarTitleDisplayMode(.inline)
    .toolbarBackground(BrandColors.primary, for: .navigationBar)
    .toolbarBackground(.visible, for: .navigationBar)
    .toolbarColorScheme(.dark, for: .navigationBar)
  }

  private func sectionLabel(_ text: String) -> some View {
    Text(text.uppercased())
      .font(.caption2.weight(.bold))
      .tracking(0.8)
      .foregroundStyle(BrandColors.onPrimary.opacity(0.55))
      .padding(.top, 4)
  }

  private func brandedField<Content: View>(
    _ title: String,
    @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title)
        .font(.caption.weight(.semibold))
        .foregroundStyle(BrandColors.onPrimary.opacity(0.7))
      content()
        .foregroundStyle(BrandColors.onPrimary)
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(BrandColors.primary.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .tint(BrandColors.onPrimary)
    }
  }
}
