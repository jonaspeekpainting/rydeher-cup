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

  /// Pink ball side game runs only on 2v2 best ball.
  var supportsPinkBall: Bool {
    self == .bestBallMatch
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

/// "E", "+3", "-2" for a score relative to par.
func scoreToParText(_ value: Int?) -> String? {
  guard let value else { return nil }
  if value == 0 { return "E" }
  return value > 0 ? "+\(value)" : "\(value)"
}

struct PinkBallHole: Codable, Hashable {
  let holeNumber: Int
  let carrierProfileId: UUID
  let lost: Bool
  let lostCount: Int

  enum CodingKeys: String, CodingKey {
    case lost
    case holeNumber = "hole_number"
    case carrierProfileId = "carrier_profile_id"
    case lostCount = "lost_count"
  }
}

struct PinkBallHoleNet: Codable, Hashable, Identifiable {
  var id: Int { holeNumber }
  let holeNumber: Int
  let carrierProfileId: UUID
  let lost: Bool
  let lostCount: Int
  let grossStrokes: Int?
  let netStrokes: Int?
  let counts: Bool

  enum CodingKeys: String, CodingKey {
    case lost, counts
    case holeNumber = "hole_number"
    case carrierProfileId = "carrier_profile_id"
    case lostCount = "lost_count"
    case grossStrokes = "gross_strokes"
    case netStrokes = "net_strokes"
  }
}

struct PinkBallScore: Codable, Hashable {
  let totalNet: Int?
  let totalToPar: Int?
  let holesCounted: Int
  let ballsLost: Int
  let ballsRemaining: Int
  let eliminated: Bool
  let eliminatedOnHole: Int?
  let holeNets: [PinkBallHoleNet]

  enum CodingKeys: String, CodingKey {
    case eliminated
    case totalNet = "total_net"
    case totalToPar = "total_to_par"
    case holesCounted = "holes_counted"
    case ballsLost = "balls_lost"
    case ballsRemaining = "balls_remaining"
    case eliminatedOnHole = "eliminated_on_hole"
    case holeNets = "hole_nets"
  }

  var toParText: String? { scoreToParText(totalToPar) }
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
  let playingHandicaps: PlayingHandicapSnapshot?
  let updatedAt: String
  let players: [MatchPlayer]
  let holeScores: [HoleScore]?
  let holeOutcomes: [MatchHoleOutcome]?
  let result: MatchResult?
  let course: MatchCourseInfo?
  let canScore: Bool
  let scoresVisible: Bool
  let pinkBallHoles: [PinkBallHole]?
  let pinkBallsRemaining: Int?
  let pinkBallsLost: Int?
  let pinkBallScore: PinkBallScore?

  enum CodingKeys: String, CodingKey {
    case id, label, format, players, result, status, course
    case sortOrder = "sort_order"
    case createdAt = "created_at"
    case sessionId = "session_id"
    case courseId = "course_id"
    case teeId = "tee_id"
    case scoringVisibility = "scoring_visibility"
    case playingHandicaps = "playing_handicaps"
    case updatedAt = "updated_at"
    case holeScores = "hole_scores"
    case holeOutcomes = "hole_outcomes"
    case canScore = "can_score"
    case scoresVisible = "scores_visible"
    case pinkBallHoles = "pink_ball_holes"
    case pinkBallsRemaining = "pink_balls_remaining"
    case pinkBallsLost = "pink_balls_lost"
    case pinkBallScore = "pink_ball_score"
  }

  static let pinkBallsPerMatch = 3

  /// Opening holes that set the pink-ball rotation (one unique player each).
  var pinkBallRotationLength: Int { players.count }

  func pinkBall(forHole hole: Int) -> PinkBallHole? {
    pinkBallHoles?.first { $0.holeNumber == hole }
  }

  func pinkBallNet(forHole hole: Int) -> PinkBallHoleNet? {
    pinkBallScore?.holeNets.first { $0.holeNumber == hole }
  }

  /// True while the group is still choosing the opening rotation.
  func canSelectPinkBallCarrier(forHole hole: Int) -> Bool {
    format?.supportsPinkBall == true
      && hole >= 1
      && hole <= pinkBallRotationLength
  }

  /// Unique carriers already used on other opening-rotation holes.
  func usedPinkBallCarriers(excludingHole hole: Int) -> Set<UUID> {
    let n = pinkBallRotationLength
    return Set(
      (pinkBallHoles ?? [])
        .filter { $0.holeNumber != hole && $0.holeNumber >= 1 && $0.holeNumber <= n }
        .map(\.carrierProfileId)
    )
  }

  /// Players still available to pick for an opening-rotation hole.
  func selectablePinkBallCarriers(forHole hole: Int) -> [MatchPlayer] {
    guard canSelectPinkBallCarrier(forHole: hole) else { return [] }
    let used = usedPinkBallCarriers(excludingHole: hole)
    return players.filter { !used.contains($0.profileId) }
  }

  /// Opening rotation order once holes 1…N each have a unique carrier.
  func pinkBallRotationOrder() -> [UUID]? {
    let n = pinkBallRotationLength
    guard n > 0 else { return nil }
    var order: [UUID] = []
    var seen = Set<UUID>()
    for h in 1 ... n {
      guard let carrier = pinkBall(forHole: h)?.carrierProfileId,
            seen.insert(carrier).inserted
      else { return nil }
      order.append(carrier)
    }
    return order
  }

  /// Carrier for this hole: chosen on 1…N, then locked to the rotation.
  func assignedPinkBallCarrier(forHole hole: Int) -> UUID? {
    guard format?.supportsPinkBall == true, !players.isEmpty else { return nil }
    let n = pinkBallRotationLength
    if hole <= n {
      return pinkBall(forHole: hole)?.carrierProfileId
        ?? selectablePinkBallCarriers(forHole: hole).first?.profileId
    }
    guard let rotation = pinkBallRotationOrder() else { return nil }
    return rotation[(hole - 1) % n]
  }

  /// Suggested / locked carrier for the current hole.
  func suggestedPinkBallCarrier(forHole hole: Int) -> UUID? {
    assignedPinkBallCarrier(forHole: hole)
  }

  func par(forHole hole: Int) -> Int {
    course?.holes.first(where: { $0.holeNumber == hole })?.par ?? 4
  }

  func holeInfo(_ hole: Int) -> MatchCourseHole? {
    course?.holes.first(where: { $0.holeNumber == hole })
  }

  /// Stroke index for a hole (1 = hardest). Falls back to hole number.
  func strokeIndex(forHole hole: Int) -> Int {
    holeInfo(hole)?.strokeIndex ?? hole
  }

  /// Strokes this player (or their side, for team-ball formats) receives on a hole.
  func strokesReceived(profileId: UUID, hole: Int) -> Int {
    guard let snap = playingHandicaps else { return 0 }
    let si = strokeIndex(forHole: hole)
    if format?.usesTeamBall == true {
      guard let player = players.first(where: { $0.profileId == profileId }),
            let side = player.side,
            let sideSnap = snap.sides.first(where: { $0.side == side })
      else { return 0 }
      return MatchHandicapMath.strokesOnHole(
        relativeStrokes: sideSnap.relativeStrokes,
        strokeIndex: si
      )
    }
    guard let ph = snap.players.first(where: { $0.profileId == profileId }) else {
      return 0
    }
    return MatchHandicapMath.strokesOnHole(
      relativeStrokes: ph.relativeStrokes,
      strokeIndex: si
    )
  }

  func strokesReceived(side: String, hole: Int) -> Int {
    guard let snap = playingHandicaps,
          let sideSnap = snap.sides.first(where: { $0.side == side })
    else { return 0 }
    return MatchHandicapMath.strokesOnHole(
      relativeStrokes: sideSnap.relativeStrokes,
      strokeIndex: strokeIndex(forHole: hole)
    )
  }

  func relativeStrokes(profileId: UUID) -> Int {
    guard let snap = playingHandicaps else { return 0 }
    if format?.usesTeamBall == true {
      guard let player = players.first(where: { $0.profileId == profileId }),
            let side = player.side,
            let sideSnap = snap.sides.first(where: { $0.side == side })
      else { return 0 }
      return sideSnap.relativeStrokes
    }
    return snap.players.first(where: { $0.profileId == profileId })?.relativeStrokes ?? 0
  }

  func relativeStrokes(side: String) -> Int {
    playingHandicaps?.sides.first(where: { $0.side == side })?.relativeStrokes ?? 0
  }

  /// First hole that doesn’t yet have a full set of scores (1–18).
  var currentHoleNumber: Int {
    for hole in 1 ... 18 {
      if !isHoleComplete(hole) {
        return hole
      }
    }
    return 18
  }

  /// The match play result is final (clinched or all holes in) yet the match is
  /// still open for scoring, so remaining holes can feed the side games.
  var isClinchedButOpen: Bool {
    guard status == .inProgress, let result, !result.isProvisional else {
      return false
    }
    return true
  }

  /// Match-play style summary of a decided result, e.g. "Hookers win 3&2".
  var decidedResultText: String? {
    guard let result, !result.isProvisional else { return nil }
    let diff = result.holesWonHookers - result.holesWonSlicers
    if diff == 0 { return "Halved" }
    let holesPlayed =
      result.holesWonHookers + result.holesWonSlicers + result.holesHalved
    let remaining = max(0, 18 - holesPlayed)
    let winner = diff > 0 ? "Hookers" : "Slicers"
    let up = abs(diff)
    if remaining == 0 {
      return "\(winner) win \(up) up"
    }
    return "\(winner) win \(up)&\(remaining)"
  }

  func isHoleComplete(_ hole: Int) -> Bool {
    let scores = holeScores ?? []
    if format?.usesTeamBall == true {
      let hasHookers = scores.contains { $0.holeNumber == hole && $0.side == "hookers" }
      let hasSlicers = scores.contains { $0.holeNumber == hole && $0.side == "slicers" }
      return hasHookers && hasSlicers
    }
    guard !players.isEmpty else { return false }
    return players.allSatisfy { player in
      scores.contains { $0.holeNumber == hole && $0.profileId == player.profileId }
    }
  }
}

/// Playing-handicap snapshot stored when a match starts / is created.
struct PlayingHandicapSnapshot: Codable, Hashable {
  let format: String
  let fieldMinimum: Int
  let players: [PlayerPlayingHandicap]
  let sides: [SidePlayingHandicap]
}

struct PlayerPlayingHandicap: Codable, Hashable {
  let profileId: UUID
  let side: String
  let courseHandicap: Int
  let allowanceStrokes: Int
  let relativeStrokes: Int
}

struct SidePlayingHandicap: Codable, Hashable {
  let side: String
  let courseHandicaps: [Int]
  let allowanceStrokes: Int
  let relativeStrokes: Int
  let profileIds: [UUID]
}

enum MatchHandicapMath {
  /// Matches API `strokesOnHole`: relative strokes off the low player/side,
  /// allocated to hardest holes first (stroke index 1 = hardest).
  static func strokesOnHole(relativeStrokes: Int, strokeIndex: Int) -> Int {
    guard relativeStrokes > 0, strokeIndex >= 1, strokeIndex <= 18 else { return 0 }
    let full = relativeStrokes / 18
    let rem = relativeStrokes % 18
    return full + (strokeIndex <= rem ? 1 : 0)
  }

  static func difficultyLabel(strokeIndex: Int) -> String {
    switch strokeIndex {
    case 1: return "Hardest hole"
    case 2, 3: return "Very hard"
    case 16, 17, 18: return "Easiest"
    default: return "HCP \(strokeIndex)"
    }
  }
}

struct MatchCourseHole: Codable, Hashable, Identifiable {
  var id: Int { holeNumber }
  let holeNumber: Int
  let par: Int
  let strokeIndex: Int?
  let yardage: Int?

  enum CodingKeys: String, CodingKey {
    case par, yardage
    case holeNumber = "hole_number"
    case strokeIndex = "stroke_index"
  }
}

struct MatchCourseTee: Codable, Hashable {
  let id: UUID
  let name: String
  let color: String?
  let rating: Double?
  let slope: Int?
}

struct MatchCourseInfo: Codable, Hashable {
  let id: UUID
  let name: String
  let city: String?
  let state: String?
  let tee: MatchCourseTee?
  let holes: [MatchCourseHole]
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
  let holesWonHookers: Int?
  let holesWonSlicers: Int?
  let holesHalved: Int?

  enum CodingKeys: String, CodingKey {
    case id, label, format, status
    case scoringVisibility = "scoring_visibility"
    case hookersPoints = "hookers_points"
    case slicersPoints = "slicers_points"
    case isProvisional = "is_provisional"
    case countsTowardStandings = "counts_toward_standings"
    case holesWonHookers = "holes_won_hookers"
    case holesWonSlicers = "holes_won_slicers"
    case holesHalved = "holes_halved"
  }

  /// Match-play result for the scoreboard, e.g. "Slicers: 3 & 2".
  /// Falls back to the winning side alone when the API omits hole margins.
  var matchPlayScoreText: String? {
    guard countsTowardStandings, isProvisional == false else { return nil }

    if let margin = matchPlayMarginText {
      return margin
    }

    guard let hookersPoints, let slicersPoints else { return nil }
    if hookersPoints == slicersPoints { return "Halved" }
    return hookersPoints > slicersPoints ? "Hookers win" : "Slicers win"
  }

  private var matchPlayMarginText: String? {
    guard let holesWonHookers, let holesWonSlicers, let holesHalved else {
      return nil
    }

    let diff = holesWonHookers - holesWonSlicers
    if diff == 0 { return "Halved" }

    let holesPlayed = holesWonHookers + holesWonSlicers + holesHalved
    let remaining = max(0, 18 - holesPlayed)
    let winner = diff > 0 ? "Hookers" : "Slicers"
    let up = abs(diff)
    if remaining == 0 {
      return "\(winner): \(up) up"
    }
    return "\(winner): \(up) & \(remaining)"
  }
}

struct StandingsSession: Codable, Identifiable, Hashable {
  var id: UUID { session.id }
  let session: TournamentSession
  let hookersPoints: Double
  let slicersPoints: Double
  let matches: [StandingsMatchRow]
  let pinkBallStandings: [PinkBallMatchStanding]
  let pinkBallLeader: PinkBallMatchStanding?

  enum CodingKeys: String, CodingKey {
    case session, matches
    case hookersPoints = "hookers_points"
    case slicersPoints = "slicers_points"
    case pinkBallStandings = "pink_ball_standings"
    case pinkBallLeader = "pink_ball_leader"
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    session = try c.decode(TournamentSession.self, forKey: .session)
    hookersPoints = try c.decode(Double.self, forKey: .hookersPoints)
    slicersPoints = try c.decode(Double.self, forKey: .slicersPoints)
    matches = try c.decode([StandingsMatchRow].self, forKey: .matches)
    pinkBallStandings = try c.decodeIfPresent([PinkBallMatchStanding].self, forKey: .pinkBallStandings) ?? []
    pinkBallLeader = try c.decodeIfPresent(PinkBallMatchStanding.self, forKey: .pinkBallLeader)
  }
}

struct PinkBallMatchStanding: Codable, Identifiable, Hashable {
  var id: UUID { matchId }
  let matchId: UUID
  let matchLabel: String
  let totalNet: Int?
  let totalToPar: Int?
  let holesCounted: Int
  let eliminated: Bool
  let eliminatedOnHole: Int?
  let rank: Int?
  let isLeader: Bool

  enum CodingKeys: String, CodingKey {
    case eliminated, rank
    case matchId = "match_id"
    case matchLabel = "match_label"
    case totalNet = "total_net"
    case totalToPar = "total_to_par"
    case holesCounted = "holes_counted"
    case eliminatedOnHole = "eliminated_on_hole"
    case isLeader = "is_leader"
  }

  var toParText: String? { scoreToParText(totalToPar) }

  /// "Out on 12 · +5" — where the last ball went and how they stood there.
  var outSummary: String? {
    guard eliminated else { return nil }
    var bits = ["Out"]
    if let hole = eliminatedOnHole {
      bits.append("last ball on hole \(hole)")
    }
    if let toPar = toParText {
      bits.append("\(toPar) there")
    }
    return bits.joined(separator: " · ")
  }
}

struct CupStandings: Codable, Hashable {
  let hookersPoints: Double
  let slicersPoints: Double
  let sessions: [StandingsSession]
  let unassignedMatches: [StandingsMatchRow]
  let skins: SkinsStandings?
  let winnings: WinningsStandings?

  enum CodingKeys: String, CodingKey {
    case sessions, skins, winnings
    case hookersPoints = "hookers_points"
    case slicersPoints = "slicers_points"
    case unassignedMatches = "unassigned_matches"
  }
}

struct SkinLeader: Codable, Identifiable, Hashable {
  var id: UUID { profileId }
  let profileId: UUID
  let displayName: String
  let teamSlug: String?
  let skins: Int
  let amount: Double?

  enum CodingKeys: String, CodingKey {
    case skins, amount
    case profileId = "profile_id"
    case displayName = "display_name"
    case teamSlug = "team_slug"
  }
}

struct SkinAward: Codable, Identifiable, Hashable {
  var id: String {
    "\(sessionId?.uuidString ?? "none")-\(holeNumber)-\(profileId.uuidString)"
  }
  let sessionId: UUID?
  let sessionLabel: String?
  let holeNumber: Int
  let profileId: UUID
  let displayName: String
  let teamSlug: String?
  let grossStrokes: Int
  let amount: Double?

  enum CodingKeys: String, CodingKey {
    case amount
    case sessionId = "session_id"
    case sessionLabel = "session_label"
    case holeNumber = "hole_number"
    case profileId = "profile_id"
    case displayName = "display_name"
    case teamSlug = "team_slug"
    case grossStrokes = "gross_strokes"
  }
}

struct SkinsStandings: Codable, Hashable {
  let leaders: [SkinLeader]
  let awards: [SkinAward]
  let holesAwarded: Int
  let holesTiedOrEmpty: Int
  let pot: Double?
  let payoutPerSkin: Double?

  enum CodingKeys: String, CodingKey {
    case leaders, awards, pot
    case holesAwarded = "holes_awarded"
    case holesTiedOrEmpty = "holes_tied_or_empty"
    case payoutPerSkin = "payout_per_skin"
  }
}

struct PlayerSessionWinnings: Codable, Identifiable, Hashable {
  var id: UUID { sessionId }
  let sessionId: UUID
  let sessionLabel: String
  let matchWinnings: Double
  let pinkBallWinnings: Double
  let skinsWinnings: Double
  let totalWinnings: Double

  enum CodingKeys: String, CodingKey {
    case sessionId = "session_id"
    case sessionLabel = "session_label"
    case matchWinnings = "match_winnings"
    case pinkBallWinnings = "pink_ball_winnings"
    case skinsWinnings = "skins_winnings"
    case totalWinnings = "total_winnings"
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    sessionId = try c.decode(UUID.self, forKey: .sessionId)
    sessionLabel = try c.decode(String.self, forKey: .sessionLabel)
    matchWinnings = try c.decode(Double.self, forKey: .matchWinnings)
    pinkBallWinnings = try c.decodeIfPresent(Double.self, forKey: .pinkBallWinnings) ?? 0
    skinsWinnings = try c.decode(Double.self, forKey: .skinsWinnings)
    totalWinnings = try c.decode(Double.self, forKey: .totalWinnings)
  }
}

struct PlayerWinnings: Codable, Identifiable, Hashable {
  var id: UUID { profileId }
  let profileId: UUID
  let displayName: String
  let teamSlug: String?
  let matchWinnings: Double
  let pinkBallWinnings: Double
  let skinsWinnings: Double
  let totalWinnings: Double
  let bySession: [PlayerSessionWinnings]

  enum CodingKeys: String, CodingKey {
    case profileId = "profile_id"
    case displayName = "display_name"
    case teamSlug = "team_slug"
    case matchWinnings = "match_winnings"
    case pinkBallWinnings = "pink_ball_winnings"
    case skinsWinnings = "skins_winnings"
    case totalWinnings = "total_winnings"
    case bySession = "by_session"
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    profileId = try c.decode(UUID.self, forKey: .profileId)
    displayName = try c.decode(String.self, forKey: .displayName)
    teamSlug = try c.decodeIfPresent(String.self, forKey: .teamSlug)
    matchWinnings = try c.decode(Double.self, forKey: .matchWinnings)
    pinkBallWinnings = try c.decodeIfPresent(Double.self, forKey: .pinkBallWinnings) ?? 0
    skinsWinnings = try c.decode(Double.self, forKey: .skinsWinnings)
    totalWinnings = try c.decode(Double.self, forKey: .totalWinnings)
    bySession = try c.decode([PlayerSessionWinnings].self, forKey: .bySession)
  }
}

struct WinningsStandings: Codable, Hashable {
  let matchWin: Double
  let matchPush: Double
  let matchLose: Double
  let pinkBallWin: Double
  let skinsPot: Double
  let players: [PlayerWinnings]

  enum CodingKeys: String, CodingKey {
    case players
    case matchWin = "match_win"
    case matchPush = "match_push"
    case matchLose = "match_lose"
    case pinkBallWin = "pink_ball_win"
    case skinsPot = "skins_pot"
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    matchWin = try c.decode(Double.self, forKey: .matchWin)
    matchPush = try c.decode(Double.self, forKey: .matchPush)
    matchLose = try c.decode(Double.self, forKey: .matchLose)
    pinkBallWin = try c.decodeIfPresent(Double.self, forKey: .pinkBallWin) ?? 50
    skinsPot = try c.decode(Double.self, forKey: .skinsPot)
    players = try c.decode([PlayerWinnings].self, forKey: .players)
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
