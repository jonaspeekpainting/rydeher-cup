import SwiftUI

struct AppRootView: View {
  @EnvironmentObject private var sessionManager: SessionManager
  @Environment(\.scenePhase) private var scenePhase

  var body: some View {
    Group {
      if sessionManager.isLoading {
        ProgressView("Loading…")
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .background(Color(.systemGroupedBackground))
      } else if sessionManager.session == nil {
        AuthFlowView()
      } else if sessionManager.biometricLocked {
        BiometricLockView()
      } else {
        MainTabView()
      }
    }
    .animation(.easeInOut(duration: 0.2), value: sessionManager.isLoading)
    .animation(.easeInOut(duration: 0.2), value: sessionManager.session != nil)
    .animation(.easeInOut(duration: 0.2), value: sessionManager.biometricLocked)
    .onChange(of: scenePhase) { _, newPhase in
      if newPhase == .background {
        sessionManager.lockForBackgroundIfNeeded()
      }
    }
  }
}
