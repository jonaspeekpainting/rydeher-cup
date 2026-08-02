import Foundation

enum AppSecrets {
  /// DEBUG → local API. Release / TestFlight / App Store → hosted API.
  #if DEBUG
  /// Local API (`npm run dev` in ryderher-cup-api). Simulator: `127.0.0.1`. Device: your Mac LAN IP.
  static let apiBaseURL = URL(string: "http://192.168.0.177:3000")!
  #else
  static let apiBaseURL = URL(string: "https://rydeher-cup.vercel.app")!
  #endif
}
