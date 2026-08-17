import SwiftUI

struct MatchUpsTabView: View {
  @EnvironmentObject private var sessionManager: SessionManager
  @State private var sessions: [TournamentSession] = []
  @State private var matches: [TournamentMatch] = []
  @State private var loadError: String?
  @State private var isLoading = true

  private var myUserId: UUID? {
    sessionManager.profile?.id
  }

  private var isAdmin: Bool {
    sessionManager.profile?.isAdmin == true
  }

  /// Players only see matches they are in; admins see all.
  /// Completed matches drop off this tab — they live on the scoreboard.
  private var visibleMatches: [TournamentMatch] {
    matches.filter { match in
      guard match.status != .complete else { return false }
      if isAdmin { return true }
      guard let myUserId else { return false }
      return match.players.contains { $0.profileId == myUserId }
    }
  }

  private var liveMatches: [TournamentMatch] {
    visibleMatches
      .filter { $0.status == .inProgress }
      .sorted { $0.sortOrder < $1.sortOrder }
  }

  private var upcomingMatches: [TournamentMatch] {
    visibleMatches
      .filter { $0.status == .setup }
      .sorted { $0.sortOrder < $1.sortOrder }
  }

  var body: some View {
    Group {
      if isLoading && matches.isEmpty {
        ProgressView()
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else if let loadError, matches.isEmpty {
        ContentUnavailableView(
          "Could not load match ups",
          systemImage: "exclamationmark.triangle",
          description: Text(loadError)
        )
      } else if visibleMatches.isEmpty {
        ContentUnavailableView(
          "No active match ups",
          systemImage: "person.line.dotted.person",
          description: Text(
            isAdmin
              ? "Create matches in Admin, or wait for a round to start."
              : "You’ll only see matches you’re playing. Completed matches move to the Scoreboard."
          )
        )
      } else {
        ScrollView {
          VStack(alignment: .leading, spacing: 20) {
            BrandSectionHeader(title: "Your match ups")

            ForEach(liveMatches) { match in
              NavigationLink {
                MatchDetailView(matchId: match.id)
              } label: {
                LiveMatchBattleCard(match: match)
              }
              .buttonStyle(.plain)
            }

            if !upcomingMatches.isEmpty {
              VStack(alignment: .leading, spacing: 10) {
                BrandSectionHeader(title: "Upcoming")

                ForEach(upcomingMatches) { match in
                  NavigationLink {
                    MatchDetailView(matchId: match.id)
                  } label: {
                    UpcomingMatchCard(match: match, sessionLabel: sessionLabel(for: match))
                  }
                  .buttonStyle(.plain)
                }
              }
            }
          }
          .padding()
        }
        .background(BrandScreenBackground())
      }
    }
    .navigationTitle("Match Ups")
    .toolbarBackground(BrandColors.canvas, for: .navigationBar)
    .task { await load() }
    .refreshable { await load() }
  }

  private func sessionLabel(for match: TournamentMatch) -> String? {
    guard let sessionId = match.sessionId else { return nil }
    return sessions.first { $0.id == sessionId }?.label
  }

  private func load() async {
    isLoading = true
    loadError = nil
    defer { isLoading = false }
    do {
      let token = try sessionManager.requireToken()
      async let sessionsTask = ApiClient.shared.fetchSessions(token: token)
      async let matchesTask = ApiClient.shared.fetchMatches(token: token)
      sessions = try await sessionsTask
      matches = try await matchesTask
    } catch {
      loadError = error.localizedDescription
    }
  }
}

/// Live match hero: hole-by-hole winners + running score.
struct LiveMatchBattleCard: View {
  let match: TournamentMatch
  var showsCallToAction: Bool = true
  /// Hole used for pink-ball assignment. Defaults to the next unscored hole.
  var pinkBallHole: Int? = nil

  private var holesUpText: String {
    guard let result = match.result else { return "AS" }
    let diff = result.holesWonHookers - result.holesWonSlicers
    if diff == 0 { return "AS" }
    if diff > 0 { return "\(diff) UP" }
    return "\(abs(diff)) UP"
  }

  private var leadingSide: String? {
    guard let result = match.result else { return nil }
    let diff = result.holesWonHookers - result.holesWonSlicers
    if diff > 0 { return "hookers" }
    if diff < 0 { return "slicers" }
    return nil
  }

  private var activePinkBallHole: Int {
    pinkBallHole ?? match.currentHoleNumber
  }

  /// After the opening rotation (holes 1–N), pink ball follows that lineup order.
  private var currentPinkBallCarrier: MatchPlayer? {
    guard match.format?.supportsPinkBall == true else { return nil }
    let hole = activePinkBallHole
    guard hole > match.pinkBallRotationLength else { return nil }
    guard let carrierId = match.assignedPinkBallCarrier(forHole: hole) else { return nil }
    return match.players.first { $0.profileId == carrierId }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        Label("LIVE", systemImage: "circle.fill")
          .font(.caption.weight(.bold))
          .foregroundStyle(.white)
          .padding(.horizontal, 10)
          .padding(.vertical, 5)
          .background(Color.red)
          .clipShape(Capsule())

        Spacer()

        if let format = match.format {
          Text(format.title)
            .font(.caption.weight(.medium))
            .foregroundStyle(.white.opacity(0.85))
        }
      }

      Text(match.label)
        .font(.title3.weight(.bold))
        .foregroundStyle(.white)

      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 4) {
          Text("Hookers")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.7))
          playerNamesColumn(side: "hookers", alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        VStack(spacing: 2) {
          Text(holesUpText)
            .font(.title2.weight(.heavy).monospacedDigit())
            .foregroundStyle(.white)
          if let leading = leadingSide {
            Text(leading == "hookers" ? "Hookers" : "Slicers")
              .font(.caption2.weight(.bold))
              .foregroundStyle(.white.opacity(0.8))
          } else {
            Text("All square")
              .font(.caption2.weight(.bold))
              .foregroundStyle(.white.opacity(0.8))
          }
          if let result = match.result {
            Text("\(result.holesWonHookers) – \(result.holesWonSlicers)")
              .font(.caption.monospacedDigit())
              .foregroundStyle(.white.opacity(0.75))
          }
        }

        VStack(alignment: .trailing, spacing: 4) {
          Text("Slicers")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.7))
          playerNamesColumn(side: "slicers", alignment: .trailing)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
      }

      if let carrier = currentPinkBallCarrier {
        HStack(spacing: 8) {
          Circle()
            .fill(Color.pink)
            .frame(width: 8, height: 8)
          Text("Pink ball · \(shortPlayerName(carrier.profile.displayName))")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
          Spacer(minLength: 0)
          Text("Hole \(activePinkBallHole)")
            .font(.caption.weight(.medium))
            .foregroundStyle(.white.opacity(0.75))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.pink.opacity(0.28))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
          "Pink ball on hole \(activePinkBallHole): \(shortPlayerName(carrier.profile.displayName))"
        )
      }

      HoleBattleStrip(match: match)

      if showsCallToAction, match.canScore {
        HStack {
          Image(systemName: "square.and.pencil")
          Text("Tap to score · Hole \(match.currentHoleNumber)")
          Spacer()
          Image(systemName: "chevron.right")
            .font(.caption.weight(.semibold))
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.white.opacity(0.9))
      }
    }
    .padding(16)
    .background(BrandColors.liveGradient)
    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    .shadow(color: BrandColors.primary.opacity(0.45), radius: 12, y: 6)
  }

  @ViewBuilder
  private func playerNamesColumn(side: String, alignment: HorizontalAlignment) -> some View {
    let players = match.players.filter { $0.side == side }
    if players.isEmpty {
      Text("TBD")
        .font(.subheadline.weight(.medium))
        .foregroundStyle(.white)
    } else {
      VStack(alignment: alignment, spacing: 2) {
        ForEach(players) { player in
          let hasPink = currentPinkBallCarrier?.profileId == player.profileId
          HStack(spacing: 5) {
            if alignment == .trailing { Spacer(minLength: 0) }
            if hasPink, alignment == .trailing {
              pinkBallNameBadge()
            }
            Text(shortPlayerName(player.profile.displayName))
              .font(.subheadline.weight(.medium))
              .foregroundStyle(.white)
              .multilineTextAlignment(alignment == .trailing ? .trailing : .leading)
            if hasPink, alignment == .leading {
              pinkBallNameBadge()
            }
            if alignment == .leading { Spacer(minLength: 0) }
          }
        }
      }
      .fixedSize(horizontal: false, vertical: true)
    }
  }

  private func pinkBallNameBadge() -> some View {
    Text("PINK")
      .font(.system(size: 9, weight: .bold))
      .foregroundStyle(.white)
      .padding(.horizontal, 5)
      .padding(.vertical, 2)
      .background(Color.pink)
      .clipShape(Capsule())
      .accessibilityLabel("Has the pink ball")
  }

  private func shortPlayerName(_ name: String) -> String {
    PlayerNameFormatting.shortLastName(
      name,
      among: match.players.map(\.profile.displayName)
    )
  }
}

struct HoleBattleStrip: View {
  let match: TournamentMatch

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Hole by hole")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.white.opacity(0.7))

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 6) {
          ForEach(1 ... 18, id: \.self) { hole in
            holeCell(hole)
          }
        }
      }
    }
  }

  private func holeCell(_ hole: Int) -> some View {
    let outcome = match.holeOutcomes?.first { $0.holeNumber == hole }
    let played = outcome != nil
      || (match.holeScores?.contains { $0.holeNumber == hole } ?? false)

    return VStack(spacing: 4) {
      Text("\(hole)")
        .font(.caption2.weight(.bold).monospacedDigit())
        .foregroundStyle(.white.opacity(0.7))

      Circle()
        .fill(fill(for: outcome, played: played))
        .frame(width: 22, height: 22)
        .overlay {
          if let outcome {
            Text(symbol(for: outcome))
              .font(.system(size: 9, weight: .bold))
              .foregroundStyle(.white)
          } else if !played {
            Text("·")
              .foregroundStyle(.white.opacity(0.35))
          }
        }
    }
    .frame(width: 28)
  }

  private func fill(for outcome: MatchHoleOutcome?, played: Bool) -> Color {
    guard played else {
      return Color.white.opacity(0.12)
    }
    guard let outcome else {
      return Color.white.opacity(0.2)
    }
    switch outcome.winnerSide {
    case "hookers":
      return BrandColors.hookers
    case "slicers":
      return BrandColors.slicers
    default:
      return Color.white.opacity(0.35)
    }
  }

  private func symbol(for outcome: MatchHoleOutcome) -> String {
    switch outcome.winnerSide {
    case "hookers": return "H"
    case "slicers": return "S"
    default: return "="
    }
  }
}

private struct UpcomingMatchCard: View {
  let match: TournamentMatch
  let sessionLabel: String?

  var body: some View {
    BrandCard(padding: 14) {
      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Text(match.label)
            .font(.headline)
            .foregroundStyle(BrandColors.ink)
          Spacer()
          Text("Upcoming")
            .font(.caption2.weight(.bold))
            .foregroundStyle(BrandColors.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(BrandColors.primary.opacity(0.10))
            .clipShape(Capsule())
        }

        if let format = match.format {
          Text(format.title)
            .font(.caption)
            .foregroundStyle(BrandColors.inkMuted)
        }

        if let sessionLabel {
          Text(sessionLabel)
            .font(.caption2)
            .foregroundStyle(BrandColors.inkMuted.opacity(0.85))
        }

        Rectangle()
          .fill(BrandColors.hairline)
          .frame(height: 1)
          .padding(.vertical, 2)

        Text(pairingSummary)
          .font(.subheadline)
          .foregroundStyle(BrandColors.ink.opacity(0.85))
      }
    }
  }

  private var pairingSummary: String {
    let names = match.players.map(\.profile.displayName)
    let hookers = match.players
      .filter { $0.side == "hookers" }
      .map { PlayerNameFormatting.shortLastName($0.profile.displayName, among: names) }
    let slicers = match.players
      .filter { $0.side == "slicers" }
      .map { PlayerNameFormatting.shortLastName($0.profile.displayName, among: names) }
    let left = hookers.isEmpty ? "TBD" : hookers.joined(separator: " / ")
    let right = slicers.isEmpty ? "TBD" : slicers.joined(separator: " / ")
    return "\(left)  vs  \(right)"
  }
}
