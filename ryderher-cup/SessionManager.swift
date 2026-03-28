import Combine
import Foundation
import Supabase

@MainActor
final class SessionManager: ObservableObject {
  @Published private(set) var session: Session?
  @Published private(set) var profile: UserProfile?
  @Published private(set) var isLoading = true
  @Published var authError: String?
  @Published var biometricLocked = false

  let client: SupabaseClient

  private var authListenerTask: Task<Void, Never>?
  private var suppressBiometricLockOnce = false

  init() {
    client = SupabaseClient(
      supabaseURL: AppSecrets.supabaseURL,
      supabaseKey: AppSecrets.supabaseAnonKey
    )
    authListenerTask = Task { [weak self] in
      await self?.listenToAuth()
    }
  }

  deinit {
    authListenerTask?.cancel()
  }

  private func listenToAuth() async {
    for await (event, session) in client.auth.authStateChanges {
      self.session = session

      switch event {
      case .initialSession:
        if let session {
          await refreshProfile(userId: session.user.id)
          if BiometricPreferences.lockEnabled {
            biometricLocked = true
          }
        } else {
          profile = nil
          biometricLocked = false
        }
      case .signedIn:
        if let session {
          await refreshProfile(userId: session.user.id)
          if suppressBiometricLockOnce {
            biometricLocked = false
            suppressBiometricLockOnce = false
          }
        }
      case .signedOut:
        profile = nil
        biometricLocked = false
      case .tokenRefreshed, .userUpdated:
        if let session {
          await refreshProfile(userId: session.user.id)
        }
      default:
        break
      }

      isLoading = false
    }
  }

  func refreshProfile(userId: UUID) async {
    do {
      let response: PostgrestResponse<UserProfile> = try await client.from("profiles")
        .select()
        .eq("id", value: userId.uuidString)
        .single()
        .execute()
      profile = response.value
    } catch {
      profile = nil
      authError = error.localizedDescription
    }
  }

  func signIn(email: String, password: String) async {
    authError = nil
    suppressBiometricLockOnce = true
    do {
      try await client.auth.signIn(email: email, password: password)
    } catch {
      suppressBiometricLockOnce = false
      authError = error.localizedDescription
    }
  }

  struct SignupPayload: Encodable {
    let email: String
    let password: String
    let code: String
  }

  struct EdgeErrorBody: Decodable {
    let error: String
  }

  func signUp(email: String, password: String, tournamentCode: String) async {
    authError = nil
    suppressBiometricLockOnce = true
    do {
      let payload = SignupPayload(
        email: email.trimmingCharacters(in: .whitespacesAndNewlines),
        password: password,
        code: tournamentCode.trimmingCharacters(in: .whitespacesAndNewlines)
      )
      try await client.functions.invoke(
        "signup-with-code",
        options: FunctionInvokeOptions(body: payload)
      )
      try await client.auth.signIn(email: payload.email, password: password)
    } catch {
      suppressBiometricLockOnce = false
      authError = parseSignupError(error)
    }
  }

  private func parseSignupError(_ error: Error) -> String {
    if let fn = error as? FunctionsError, case .httpError(_, let data) = fn {
      if let body = try? JSONDecoder().decode(EdgeErrorBody.self, from: data) {
        return body.error
      }
      return String(data: data, encoding: .utf8) ?? fn.localizedDescription
    }
    return error.localizedDescription
  }

  func signOut() async {
    authError = nil
    do {
      try await client.auth.signOut()
      biometricLocked = false
    } catch {
      authError = error.localizedDescription
    }
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
    let response: PostgrestResponse<[UserProfile]> = try await client.from("profiles")
      .select()
      .order("display_name", ascending: true)
      .execute()
    return response.value
  }
}
