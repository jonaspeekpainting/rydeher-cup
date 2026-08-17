import Foundation

enum PlayerNameFormatting {
  /// Last token of a display name (e.g. "Tyler Schmalz" → "Schmalz").
  static func lastName(of full: String) -> String {
    let parts = full.split(whereSeparator: \.isWhitespace).map(String.init)
    return parts.last ?? full
  }

  /// Compact last-name form. When more than one name in `among` shares the same
  /// last name, returns "T. Schmalz"; otherwise just "Schmalz".
  static func shortLastName(_ full: String, among: [String] = []) -> String {
    let last = lastName(of: full)
    guard !last.isEmpty else { return full }

    let lastKey = last.lowercased()
    let duplicates = among.filter { lastName(of: $0).lowercased() == lastKey }
    guard duplicates.count > 1 else { return last }

    let parts = full.split(whereSeparator: \.isWhitespace)
    guard let first = parts.first, let initial = first.first else { return last }
    return "\(initial.uppercased()). \(last)"
  }
}
