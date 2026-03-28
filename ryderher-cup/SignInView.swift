import SwiftUI

struct SignInView: View {
  @EnvironmentObject private var sessionManager: SessionManager
  @State private var email = ""
  @State private var password = ""
  @State private var isSubmitting = false

  var body: some View {
    Form {
      Section {
        TextField("Email", text: $email)
          .textContentType(.username)
          .textInputAutocapitalization(.never)
          .keyboardType(.emailAddress)
        SecureField("Password", text: $password)
          .textContentType(.password)
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
            await sessionManager.signIn(email: email, password: password)
          }
        } label: {
          if isSubmitting {
            ProgressView()
              .frame(maxWidth: .infinity)
          } else {
            Text("Sign in")
              .frame(maxWidth: .infinity)
          }
        }
        .disabled(email.isEmpty || password.isEmpty || isSubmitting)
      }
    }
    .navigationTitle("Sign in")
    .navigationBarTitleDisplayMode(.inline)
    .scrollDismissesKeyboard(.interactively)
  }
}
