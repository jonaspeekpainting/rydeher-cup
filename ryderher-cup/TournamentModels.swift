import Foundation

enum MatchFormat: String, Codable, CaseIterable, Identifiable {
  case bestBallMatch = "best_ball_match"
  case scramble
  case shamble
  case singlesMatch = "singles_match"
  case alternateShot = "alternate_shot"

  var id: String { rawValue }

  var title: String {
    switch self {
    case .bestBallMatch: return "2v2 Best Ball"
    case .scramble: return "Scramble"
    case .shamble: return "Shamble"
    case .singlesMatch: return "1v1 Match Play"
    case .alternateShot: return "Alternate Shot"
    }
  }

  var usesTeamBall: Bool {
    self == .scramble || self == .alternateShot
  }
}

enum ScoringVisibility: String, Codable, CaseIterable {
  case live
  case releaseOnComplete = "release_on_complete"

  var title: String {
    switch self {
    case .live: return "Live scoring"
    case .releaseOnComplete: return "Release when complete"
    }
  }
}

enum MatchStatus: String, Codable {
  case setup
  case inProgress = "in_progress"
  case complete
}

struct TournamentSession: Codable, Identifiable, Hashable {
  let id: UUID
  let day: String
  let roundNumber: Int
  let sessionDate: String
  let label: String
  let sortOrder: Int

  enum CodingKeys: String, CodingKey {
    case id, day, label
    case roundNumber = "round_number"
    case sessionDate = "session_date"
    case sortOrder = "sort_order"
  }
}

struct MatchPlayer: Codable, Identifiable, Hashable {
  let id: UUID
  let profileId: UUID
  let side: String?
  let profile: UserProfile

  enum CodingKeys: String, CodingKey {
    case id, side, profile
    case profileId = "profile_id"
  }
}

struct HoleScore: Codable, Hashable {
  let holeNumber: Int
  let profileId: UUID?
  let side: String?
  let grossStrokes: Int
  let updatedAt: String

  enum CodingKeys: String, CodingKey {
    case side
    case holeNumber = "hole_number"
    case profileId = "profile_id"
    case grossStrokes = "gross_strokes"
    case updatedAt = "updated_at"
  }
}

struct MatchHoleOutcome: Codable, Hashable {
  let holeNumber: Int
  let winnerSide: String?

  enum CodingKeys: String, CodingKey {
    case holeNumber = "hole_number"
    case winnerSide = "winner_side"
  }
}

struct MatchResult: Codable, Hashable {
  let hookersPoints: Double
  let slicersPoints: Double
  let isProvisional: Bool
  let holesWonHookers: Int
  let holesWonSlicers: Int
  let holesHalved: Int

  enum CodingKeys: String, CodingKey {
    case hookersPoints = "hookers_points"
    case slicersPoints = "slicers_points"
    case isProvisional = "is_provisional"
    case holesWonHookers = "holes_won_hookers"
    case holesWonSlicers = "holes_won_slicers"
    case holesHalved = "holes_halved"
  }
}

struct TournamentMatch: Codable, Identifiable, Hashable {
  let id: UUID
  let label: String
  let sortOrder: Int
  let createdAt: String
  let sessionId: UUID?
  let format: MatchFormat?
  let courseId: UUID?
  let teeId: UUID?
  let scoringVisibility: ScoringVisibility
  let status: MatchStatus
  let updatedAt: String
  let players: [MatchPlayer]
  let holeScores: [HoleScore]?
  let holeOutcomes: [MatchHoleOutcome]?
  let result: MatchResult?
  let canScore: Bool
  let scoresVisible: Bool

  enum CodingKeys: String, CodingKey {
    case id, label, format, players, result, status
    case sortOrder = "sort_order"
    case createdAt = "created_at"
    case sessionId = "session_id"
    case courseId = "course_id"
    case teeId = "tee_id"
    case scoringVisibility = "scoring_visibility"
    case updatedAt = "updated_at"
    case holeScores = "hole_scores"
    case holeOutcomes = "hole_outcomes"
    case canScore = "can_score"
    case scoresVisible = "scores_visible"
  }
}

struct StandingsMatchRow: Codable, Identifiable, Hashable {
  let id: UUID
  let label: String
  let format: MatchFormat?
  let status: MatchStatus
  let scoringVisibility: ScoringVisibility
  let hookersPoints: Double?
  let slicersPoints: Double?
  let isProvisional: Bool?
  let countsTowardStandings: Bool

  enum CodingKeys: String, CodingKey {
    case id, label, format, status
    case scoringVisibility = "scoring_visibility"
    case hookersPoints = "hookers_points"
    case slicersPoints = "slicers_points"
    case isProvisional = "is_provisional"
    case countsTowardStandings = "counts_toward_standings"
  }
}

struct StandingsSession: Codable, Identifiable, Hashable {
  var id: UUID { session.id }
  let session: TournamentSession
  let hookersPoints: Double
  let slicersPoints: Double
  let matches: [StandingsMatchRow]

  enum CodingKeys: String, CodingKey {
    case session, matches
    case hookersPoints = "hookers_points"
    case slicersPoints = "slicers_points"
  }
}

struct CupStandings: Codable, Hashable {
  let hookersPoints: Double
  let slicersPoints: Double
  let sessions: [StandingsSession]
  let unassignedMatches: [StandingsMatchRow]

  enum CodingKeys: String, CodingKey {
    case sessions
    case hookersPoints = "hookers_points"
    case slicersPoints = "slicers_points"
    case unassignedMatches = "unassigned_matches"
  }
}

struct CourseTee: Decodable, Identifiable, Hashable {
  let id: UUID
  let courseId: UUID
  let name: String
  let color: String?
  let rating: Double?
  let slope: Int?
  let totalYardage: Int?

  enum CodingKeys: String, CodingKey {
    case id, name, color, rating, slope
    case courseId = "course_id"
    case totalYardage = "total_yardage"
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    id = try c.decode(UUID.self, forKey: .id)
    courseId = try c.decode(UUID.self, forKey: .courseId)
    name = try c.decode(String.self, forKey: .name)
    color = try c.decodeIfPresent(String.self, forKey: .color)
    if let r = try? c.decodeIfPresent(Double.self, forKey: .rating) {
      rating = r
    } else if let s = try c.decodeIfPresent(String.self, forKey: .rating) {
      rating = Double(s)
    } else {
      rating = nil
    }
    slope = try c.decodeIfPresent(Int.self, forKey: .slope)
    totalYardage = try c.decodeIfPresent(Int.self, forKey: .totalYardage)
  }
}

struct CourseSummary: Decodable, Identifiable, Hashable {
  let id: UUID
  let externalId: String
  let name: String
  let city: String?
  let state: String?
  let tees: [CourseTee]?

  enum CodingKeys: String, CodingKey {
    case id, name, city, state, tees
    case externalId = "external_id"
  }
}

struct CourseSearchHit: Codable, Identifiable, Hashable {
  var id: String { externalId }
  let externalId: String
  let name: String
  let city: String?
  let state: String?

  enum CodingKeys: String, CodingKey {
    case name, city, state
    case externalId = "external_id"
  }
}

struct TeamRosterEntry: Codable, Identifiable, Hashable {
  let id: UUID
  let displayName: String
  let email: String?
  let sortOrder: Int
  let profile: UserProfile?

  enum CodingKeys: String, CodingKey {
    case id, email, profile
    case displayName = "display_name"
    case sortOrder = "sort_order"
  }
}

struct TournamentTeam: Codable, Identifiable, Hashable {
  let id: UUID
  let slug: String
  let name: String
  let roster: [TeamRosterEntry]
}
