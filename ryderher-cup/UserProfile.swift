import Foundation

struct UserProfile: Codable, Identifiable, Hashable {
  let id: UUID
  let email: String
  let displayName: String
  let isAdmin: Bool

  enum CodingKeys: String, CodingKey {
    case id, email
    case displayName = "display_name"
    case isAdmin = "is_admin"
  }
}
