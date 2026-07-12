import SwiftUI

struct SignUpView: View {
  @EnvironmentObject private var sessionManager: SessionManager
  @State private var email = ""
  @State private var password = ""
  @State private var confirmPassword = ""
  @State private var tournamentCode = ""
  @State private var ghinNumber = ""
  @State private var handicapIndexText = ""
  @State private var isSubmitting = false

  private var passwordsMatch: Bool {
    password == confirmPassword && !password.isEmpty
  }

  private var handicapIndex: Double? {
    let trimmed = handicapIndexText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    return Double(trimmed)
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

      Section("Handicap") {
        TextField("GHIN number", text: $ghinNumber)
          .keyboardType(.numberPad)
          .textInputAutocapitalization(.never)
        TextField("Handicap Index (if GHIN lookup unavailable)", text: $handicapIndexText)
          .keyboardType(.decimalPad)
        Text("Enter your GHIN. If official lookup isn’t configured yet, also enter your Handicap Index.")
          .font(.footnote)
          .foregroundStyle(.secondary)
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
              tournamentCode: tournamentCode,
              ghinNumber: ghinNumber,
              handicapIndex: handicapIndex
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
            || tournamentCode.isEmpty || ghinNumber.isEmpty
            || handicapIndex == nil || isSubmitting
        )
      }
    }
    .navigationTitle("Create account")
    .navigationBarTitleDisplayMode(.inline)
    .scrollDismissesKeyboard(.interactively)
  }
}
