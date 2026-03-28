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

  var body: some View {
    Form {
      Section {
        Text("Use the email you were invited with and the tournament code from your organizer.")
          .font(.footnote)
          .foregroundStyle(.secondary)
      }

      Section {
        TextField("Email", text: $email)
          .textContentType(.emailAddress)
          .textInputAutocapitalization(.never)
          .keyboardType(.emailAddress)
        SecureField("Password (min 8 characters)", text: $password)
          .textContentType(.newPassword)
        SecureField("Confirm password", text: $confirmPassword)
          .textContentType(.newPassword)
        TextField("Tournament code", text: $tournamentCode)
          .textInputAutocapitalization(.never)
      }

      if !password.isEmpty, !passwordsMatch {
        Section {
          Text("Passwords do not match.")
            .foregroundStyle(.orange)
            .font(.footnote)
        }
      }

      if let err = sessionManager.authError {
        Section {
          Text(err)
            .foregroundStyle(.red)
            .font(.footnote)
        }
      }

      Section {
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
              .frame(maxWidth: .infinity)
          } else {
            Text("Create account")
              .frame(maxWidth: .infinity)
          }
        }
        .disabled(
          email.isEmpty || password.count < 8 || !passwordsMatch
            || tournamentCode.isEmpty || isSubmitting
        )
      }
    }
    .navigationTitle("Create account")
    .navigationBarTitleDisplayMode(.inline)
    .scrollDismissesKeyboard(.interactively)
  }
}
