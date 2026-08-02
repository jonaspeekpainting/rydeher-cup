import SwiftUI

struct SignInView: View {
  @EnvironmentObject private var sessionManager: SessionManager
  @State private var email = ""
  @State private var password = ""
  @State private var isSubmitting = false

  var body: some View {
    ScrollView {
      VStack(spacing: 24) {
        BrandLogoMark(maxWidth: 180)
          .padding(.top, 12)

        VStack(alignment: .leading, spacing: 14) {
          authField("Email") {
            TextField("Email", text: $email)
              .textContentType(.username)
              .textInputAutocapitalization(.never)
              .keyboardType(.emailAddress)
              .foregroundStyle(BrandColors.onPrimary)
          }

          authField("Password") {
            SecureField("Password", text: $password)
              .textContentType(.password)
              .foregroundStyle(BrandColors.onPrimary)
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
              await sessionManager.signIn(email: email, password: password)
            }
          } label: {
            if isSubmitting {
              ProgressView()
                .tint(BrandColors.onPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            } else {
              Text("Sign in")
            }
          }
          .buttonStyle(
            BrandPrimaryButtonStyle(isEnabled: !email.isEmpty && !password.isEmpty && !isSubmitting)
          )
          .disabled(email.isEmpty || password.isEmpty || isSubmitting)
        }
        .padding(20)
        .background(BrandColors.primarySoft.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.horizontal, 20)
      }
      .padding(.bottom, 32)
    }
    .scrollDismissesKeyboard(.interactively)
    .background(BrandColors.primary.ignoresSafeArea())
    .navigationTitle("Sign in")
    .navigationBarTitleDisplayMode(.inline)
    .toolbarBackground(BrandColors.primary, for: .navigationBar)
    .toolbarBackground(.visible, for: .navigationBar)
    .toolbarColorScheme(.dark, for: .navigationBar)
  }

  private func authField<Content: View>(
    _ title: String,
    @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title)
        .font(.caption.weight(.semibold))
        .foregroundStyle(BrandColors.onPrimary.opacity(0.7))
      content()
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(BrandColors.primary.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .tint(BrandColors.onPrimary)
    }
  }
}
