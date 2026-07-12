import Foundation

struct UserProfile: Codable, Identifiable, Hashable {
  let id: UUID
  let email: String
  let displayName: String
  let isAdmin: Bool
  let ghinNumber: String?
  let handicapIndex: Double?
  let courseHandicap: Int?
  let handicapSource: String?
  let handicapUpdatedAt: String?
  let teamId: UUID?
  let teamSlug: String?

  enum CodingKeys: String, CodingKey {
    case id, email
    case displayName = "display_name"
    case isAdmin = "is_admin"
    case ghinNumber = "ghin_number"
    case handicapIndex = "handicap_index"
    case courseHandicap = "course_handicap"
    case handicapSource = "handicap_source"
    case handicapUpdatedAt = "handicap_updated_at"
    case teamId = "team_id"
    case teamSlug = "team_slug"
  }

  var teamLabel: String? {
    switch teamSlug {
    case "hookers": return "Hookers"
    case "slicers": return "Slicers"
    default: return nil
    }
  }
}
