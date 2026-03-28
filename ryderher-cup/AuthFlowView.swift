import SwiftUI

private enum AuthRoute: Hashable {
  case signIn
  case signUp
}

struct AuthFlowView: View {
  @State private var path = NavigationPath()

  var body: some View {
    NavigationStack(path: $path) {
      WelcomeView(
        onSignIn: { path.append(AuthRoute.signIn) },
        onSignUp: { path.append(AuthRoute.signUp) }
      )
      .navigationDestination(for: AuthRoute.self) { route in
        switch route {
        case .signIn:
          SignInView()
        case .signUp:
          SignUpView()
        }
      }
    }
  }
}
