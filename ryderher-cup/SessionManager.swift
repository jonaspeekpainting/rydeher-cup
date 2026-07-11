import Combine
import Foundation

struct AuthSession: Equatable {
  let userId: UUID
}

@MainActor
final class SessionManager: ObservableObject {
  @Published private(set) var session: AuthSession?
  @Published private(set) var profile: UserProfile?
  @Published private(set) var isLoading = true
  @Published var authError: String?
  @Published var biometricLocked = false

  private var token: String?
  private var suppressBiometricLockOnce = false

  init() {
    token = KeychainTokenStore.load()
    Task {
      await restoreSession()
    }
  }

  private func restoreSession() async {
    defer { isLoading = false }

    guard let token else {
      clearSession()
      return
    }

    do {
      let profile = try await ApiClient.shared.fetchProfile(token: token)
      applyAuthenticatedState(token: token, profile: profile)

      if BiometricPreferences.lockEnabled {
        biometricLocked = true
      }
    } catch {
      clearSession()
    }
  }

  func refreshProfile() async {
    guard let token else {
      profile = nil
      return
    }

    do {
      profile = try await ApiClient.shared.fetchProfile(token: token)
      authError = nil
    } catch {
      if case ApiClientError.unauthorized = error {
        clearSession()
      }
      authError = error.localizedDescription
    }
  }

  func signIn(email: String, password: String) async {
    authError = nil
    suppressBiometricLockOnce = true

    do {
      let response = try await ApiClient.shared.signIn(
        email: email.trimmingCharacters(in: .whitespacesAndNewlines),
        password: password
      )
      applyAuthenticatedState(token: response.token, profile: response.profile)
      if suppressBiometricLockOnce {
        biometricLocked = false
        suppressBiometricLockOnce = false
      }
    } catch {
      suppressBiometricLockOnce = false
      authError = error.localizedDescription
    }
  }

  func signUp(email: String, password: String, tournamentCode: String) async {
    authError = nil
    suppressBiometricLockOnce = true

    do {
      let response = try await ApiClient.shared.signUp(
        email: email.trimmingCharacters(in: .whitespacesAndNewlines),
        password: password,
        code: tournamentCode.trimmingCharacters(in: .whitespacesAndNewlines)
      )
      applyAuthenticatedState(token: response.token, profile: response.profile)
      if suppressBiometricLockOnce {
        biometricLocked = false
        suppressBiometricLockOnce = false
      }
    } catch {
      suppressBiometricLockOnce = false
      authError = error.localizedDescription
    }
  }

  func signOut() async {
    authError = nil
    clearSession()
    biometricLocked = false
  }

  func unlockWithBiometrics() async {
    authError = nil
    do {
      try await BiometricAuth.authenticate()
      biometricLocked = false
    } catch {
      authError = error.localizedDescription
    }
  }

  func lockForBackgroundIfNeeded() {
    guard session != nil, BiometricPreferences.lockEnabled else { return }
    biometricLocked = true
  }

  func fetchAllProfiles() async throws -> [UserProfile] {
    guard let token else {
      throw ApiClientError.unauthorized
    }
    return try await ApiClient.shared.fetchAllProfiles(token: token)
  }

  private func applyAuthenticatedState(token: String, profile: UserProfile) {
    self.token = token
    KeychainTokenStore.save(token)
    self.profile = profile
    session = AuthSession(userId: profile.id)
    authError = nil
  }

  private func clearSession() {
    token = nil
    KeychainTokenStore.delete()
    profile = nil
    session = nil
  }
}
