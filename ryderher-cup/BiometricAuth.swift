import Foundation
import LocalAuthentication

enum BiometricPreferences {
  private static let key = "ryderher.biometricLockEnabled"

  static var lockEnabled: Bool {
    get { UserDefaults.standard.bool(forKey: key) }
    set { UserDefaults.standard.set(newValue, forKey: key) }
  }
}

enum BiometricAuth {
  static var biometricType: LABiometryType {
    let context = LAContext()
    _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    return context.biometryType
  }

  static func reasonMessage() -> String {
    switch biometricType {
    case .faceID:
      return "Unlock RyderHer Cup with Face ID."
    case .touchID:
      return "Unlock RyderHer Cup with Touch ID."
    default:
      return "Unlock RyderHer Cup."
    }
  }

  static func authenticate() async throws {
    let context = LAContext()
    context.localizedCancelTitle = "Use Passcode"
    var error: NSError?
    guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
      try await authenticateWithDevicePasscode()
      return
    }
    let success = try await context.evaluatePolicy(
      .deviceOwnerAuthenticationWithBiometrics,
      localizedReason: reasonMessage()
    )
    guard success else {
      throw BiometricAuthError.failed
    }
  }

  private static func authenticateWithDevicePasscode() async throws {
    let context = LAContext()
    let success = try await context.evaluatePolicy(
      .deviceOwnerAuthentication,
      localizedReason: "Unlock RyderHer Cup."
    )
    guard success else {
      throw BiometricAuthError.failed
    }
  }

  enum BiometricAuthError: Error {
    case failed
  }
}
