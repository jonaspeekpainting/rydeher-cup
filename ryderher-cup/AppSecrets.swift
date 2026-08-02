import Foundation

enum AppSecrets {
  /// - `ryderher-cup` scheme (Debug): local API
  /// - `ryderher-cup Live` scheme (DebugLive): production API, still debuggable
  /// - Archive / Release / TestFlight: production API
  #if USE_LIVE_API
  static let apiBaseURL = URL(string: "https://rydeher-cup.vercel.app")!
  #elseif DEBUG
  /// Local API (`npm run dev` in ryderher-cup-api). Simulator: `127.0.0.1`. Device: your Mac LAN IP.
  static let apiBaseURL = URL(string: "http://192.168.0.177:3000")!
  #else
  static let apiBaseURL = URL(string: "https://rydeher-cup.vercel.app")!
  #endif
}
