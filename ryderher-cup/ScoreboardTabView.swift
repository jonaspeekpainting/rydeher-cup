import SwiftUI

struct ScoreboardTabView: View {
  @EnvironmentObject private var sessionManager: SessionManager
  @Binding var showSettings: Bool
  @State private var standings: CupStandings?
  @State private var loadError: String?
  @State private var isLoading = true

  var body: some View {
    Group {
      if isLoading && standings == nil {
        ProgressView()
          .tint(BrandColors.primary)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else if let loadError, standings == nil {
        ContentUnavailableView(
          "Could not load scoreboard",
          systemImage: "exclamationmark.triangle",
          description: Text(loadError)
        )
      } else if let standings {
        ScrollView {
          VStack(alignment: .leading, spacing: 22) {
            CupScoreHero(
              hookersPoints: standings.hookersPoints,
              slicersPoints: standings.slicersPoints,
              title: "Cup standings",
              subtitle: "Boyne · Aug 20–22"
            )

            if let skins = standings.skins {
              SkinsLeaderboardSection(skins: skins)
            }

            if let winnings = standings.winnings {
              WinningsLeaderboardSection(winnings: winnings)
            }

            VStack(alignment: .leading, spacing: 12) {
              BrandSectionHeader(
                title: "Sessions",
                subtitle: "Tap a round for match-by-match detail"
              )

              ForEach(standings.sessions) { session in
                NavigationLink {
                  SessionMatchUpsView(sessionStandings: session)
                } label: {
                  SessionStandingsCard(session: session)
                }
                .buttonStyle(.plain)
              }
            }

            if !standings.unassignedMatches.isEmpty {
              VStack(alignment: .leading, spacing: 12) {
                BrandSectionHeader(title: "Other matches")
                ForEach(standings.unassignedMatches) { match in
                  NavigationLink {
                    MatchDetailView(matchId: match.id)
                  } label: {
                    BrandCard {
                      MatchStandingsRow(match: match)
                    }
                  }
                  .buttonStyle(.plain)
                }
              }
            }
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 12)
        }
        .background(BrandScreenBackground())
      } else {
        ContentUnavailableView(
          "Scoreboard",
          systemImage: "flag.checkered",
          description: Text("Cup standings will appear once matches are set.")
        )
      }
    }
    .navigationTitle("Scoreboard")
    .toolbarBackground(BrandColors.canvas, for: .navigationBar)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button {
          showSettings = true
        } label: {
          Image(systemName: "gearshape")
        }
        .accessibilityLabel("Settings")
      }
    }
    .task { await load() }
    .refreshable { await load() }
  }

  private func load() async {
    isLoading = true
    loadError = nil
    defer { isLoading = false }
    do {
      let token = try sessionManager.requireToken()
      standings = try await ApiClient.shared.fetchStandings(token: token)
    } catch {
      loadError = error.localizedDescription
    }
  }
}

private struct SkinsLeaderboardSection: View {
  let skins: SkinsStandings

  private var potSubtitle: String {
    if let pot = skins.pot, let per = skins.payoutPerSkin {
      return "Saturday PM singles · $\(Int(pot)) pot · $\(moneyText(per))/skin"
    }
    if let pot = skins.pot {
      return "Saturday PM singles · $\(Int(pot)) pot · outright low gross"
    }
    return "Saturday PM singles · outright low gross"
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      BrandSectionHeader(
        title: "Skins",
        subtitle: potSubtitle
      )

      BrandCard {
        if skins.leaders.isEmpty {
          Text("No skins yet. A skin pays when one player alone has the low gross on a hole.")
            .font(.subheadline)
            .foregroundStyle(BrandColors.inkMuted)
        } else {
          VStack(spacing: 0) {
            ForEach(Array(skins.leaders.enumerated()), id: \.element.id) { index, leader in
              if index > 0 {
                Divider()
                  .background(BrandColors.hairline)
              }
              SkinLeaderRow(rank: index + 1, leader: leader)
            }
          }
        }
      }

      if !skins.awards.isEmpty {
        NavigationLink {
          SkinsDetailView(skins: skins)
        } label: {
          HStack {
            Text("\(skins.holesAwarded) skin\(skins.holesAwarded == 1 ? "" : "s") awarded")
              .font(.subheadline.weight(.medium))
              .foregroundStyle(BrandColors.primary)
            Spacer()
            Image(systemName: "chevron.right")
              .font(.caption.weight(.semibold))
              .foregroundStyle(BrandColors.primary.opacity(0.45))
          }
          .padding(.horizontal, 4)
        }
        .buttonStyle(.plain)
      }
    }
  }
}

private struct WinningsLeaderboardSection: View {
  let winnings: WinningsStandings

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      BrandSectionHeader(
        title: "Winnings",
        subtitle: "Win $\(Int(winnings.matchWin)) · Push $\(Int(winnings.matchPush)) · Skins pot $\(Int(winnings.skinsPot))"
      )

      BrandCard {
        if winnings.players.isEmpty {
          Text("Winnings appear once matches start counting on the board.")
            .font(.subheadline)
            .foregroundStyle(BrandColors.inkMuted)
        } else {
          VStack(spacing: 0) {
            ForEach(Array(winnings.players.prefix(8).enumerated()), id: \.element.id) { index, player in
              if index > 0 {
                Divider()
                  .background(BrandColors.hairline)
              }
              WinningsLeaderRow(rank: index + 1, player: player)
            }
          }
        }
      }

      if !winnings.players.isEmpty {
        NavigationLink {
          WinningsDetailView(winnings: winnings)
        } label: {
          HStack {
            Text("All players · by round")
              .font(.subheadline.weight(.medium))
              .foregroundStyle(BrandColors.primary)
            Spacer()
            Image(systemName: "chevron.right")
              .font(.caption.weight(.semibold))
              .foregroundStyle(BrandColors.primary.opacity(0.45))
          }
          .padding(.horizontal, 4)
        }
        .buttonStyle(.plain)
      }
    }
  }
}

private struct WinningsLeaderRow: View {
  let rank: Int
  let player: PlayerWinnings

  var body: some View {
    HStack(spacing: 12) {
      Text("\(rank)")
        .font(.caption.weight(.bold).monospacedDigit())
        .foregroundStyle(BrandColors.inkMuted)
        .frame(width: 20, alignment: .trailing)

      Circle()
        .fill(BrandColors.team(player.teamSlug))
        .frame(width: 8, height: 8)

      VStack(alignment: .leading, spacing: 2) {
        Text(player.displayName)
          .font(.body.weight(.semibold))
          .foregroundStyle(BrandColors.ink)
        Text(breakdownLabel(player))
          .font(.caption)
          .foregroundStyle(BrandColors.inkMuted)
      }

      Spacer(minLength: 0)

      Text(currency(player.totalWinnings))
        .font(.title3.weight(.bold).monospacedDigit())
        .foregroundStyle(BrandColors.primary)
    }
    .padding(.vertical, 10)
  }

  private func breakdownLabel(_ player: PlayerWinnings) -> String {
    var parts: [String] = []
    if player.matchWinnings > 0 {
      parts.append("\(currency(player.matchWinnings)) matches")
    }
    if player.skinsWinnings > 0 {
      parts.append("\(currency(player.skinsWinnings)) skins")
    }
    return parts.isEmpty ? "—" : parts.joined(separator: " · ")
  }
}

struct WinningsDetailView: View {
  let winnings: WinningsStandings

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        BrandSectionHeader(
          title: "Player winnings",
          subtitle: "Match money each round + Saturday PM skins"
        )

        ForEach(winnings.players) { player in
          BrandCard {
            VStack(alignment: .leading, spacing: 10) {
              HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                  Text(player.displayName)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(BrandColors.ink)
                  if let team = teamLabel(player.teamSlug) {
                    Text(team)
                      .font(.caption)
                      .foregroundStyle(BrandColors.inkMuted)
                  }
                }
                Spacer()
                Text(currency(player.totalWinnings))
                  .font(.title3.weight(.bold).monospacedDigit())
                  .foregroundStyle(BrandColors.primary)
              }

              ForEach(player.bySession) { session in
                HStack {
                  Text(session.sessionLabel)
                    .font(.subheadline)
                    .foregroundStyle(BrandColors.ink)
                  Spacer()
                  if session.skinsWinnings > 0 {
                    Text("\(currency(session.matchWinnings)) + \(currency(session.skinsWinnings)) skins")
                      .font(.caption.monospacedDigit())
                      .foregroundStyle(BrandColors.inkMuted)
                  } else {
                    Text(currency(session.totalWinnings))
                      .font(.subheadline.weight(.medium).monospacedDigit())
                      .foregroundStyle(BrandColors.inkMuted)
                  }
                }
              }
            }
          }
        }
      }
      .padding(16)
    }
    .background(BrandScreenBackground())
    .navigationTitle("Winnings")
    .navigationBarTitleDisplayMode(.inline)
    .toolbarBackground(BrandColors.canvas, for: .navigationBar)
  }

  private func teamLabel(_ slug: String?) -> String? {
    switch slug {
    case "hookers": return "Hookers"
    case "slicers": return "Slicers"
    default: return nil
    }
  }
}

private struct SkinLeaderRow: View {
  let rank: Int
  let leader: SkinLeader

  var body: some View {
    HStack(spacing: 12) {
      Text("\(rank)")
        .font(.caption.weight(.bold).monospacedDigit())
        .foregroundStyle(BrandColors.inkMuted)
        .frame(width: 20, alignment: .trailing)

      Circle()
        .fill(BrandColors.team(leader.teamSlug))
        .frame(width: 8, height: 8)

      VStack(alignment: .leading, spacing: 2) {
        Text(leader.displayName)
          .font(.body.weight(.semibold))
          .foregroundStyle(BrandColors.ink)
        if let team = teamLabel(leader.teamSlug) {
          Text(team)
            .font(.caption)
            .foregroundStyle(BrandColors.inkMuted)
        }
      }

      Spacer(minLength: 0)

      VStack(alignment: .trailing, spacing: 2) {
        if let amount = leader.amount {
          Text(currency(amount))
            .font(.title3.weight(.bold).monospacedDigit())
            .foregroundStyle(BrandColors.primary)
        }
        Text("\(leader.skins) \(leader.skins == 1 ? "skin" : "skins")")
          .font(.caption)
          .foregroundStyle(BrandColors.inkMuted)
      }
    }
    .padding(.vertical, 10)
  }

  private func teamLabel(_ slug: String?) -> String? {
    switch slug {
    case "hookers": return "Hookers"
    case "slicers": return "Slicers"
    default: return nil
    }
  }
}

struct SkinsDetailView: View {
  let skins: SkinsStandings

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        BrandSectionHeader(
          title: "Skin winners",
          subtitle: skinsSubtitle
        )

        ForEach(skins.awards) { award in
          BrandCard {
            HStack(alignment: .firstTextBaseline) {
              VStack(alignment: .leading, spacing: 4) {
                Text(holeTitle(award))
                  .font(.subheadline.weight(.semibold))
                  .foregroundStyle(BrandColors.ink)
                Text(award.displayName)
                  .font(.body.weight(.medium))
                  .foregroundStyle(BrandColors.primary)
              }
              Spacer()
              VStack(alignment: .trailing, spacing: 2) {
                if let amount = award.amount {
                  Text(currency(amount))
                    .font(.title3.weight(.bold).monospacedDigit())
                    .foregroundStyle(BrandColors.ink)
                }
                Text("\(award.grossStrokes)")
                  .font(.caption.monospacedDigit())
                  .foregroundStyle(BrandColors.inkMuted)
              }
            }
          }
        }
      }
      .padding(16)
    }
    .background(BrandScreenBackground())
    .navigationTitle("Skins")
    .navigationBarTitleDisplayMode(.inline)
    .toolbarBackground(BrandColors.canvas, for: .navigationBar)
  }

  private var skinsSubtitle: String {
    if let per = skins.payoutPerSkin {
      return "Gross · no handicap · \(currency(per)) per skin"
    }
    return "Gross score · no handicap · ties push"
  }

  private func holeTitle(_ award: SkinAward) -> String {
    let session = award.sessionLabel ?? "Session"
    return "\(session) · Hole \(award.holeNumber)"
  }
}

private func currency(_ value: Double) -> String {
  if value == floor(value) {
    return "$\(Int(value))"
  }
  return String(format: "$%.2f", value)
}

private func moneyText(_ value: Double) -> String {
  if value == floor(value) {
    return String(Int(value))
  }
  return String(format: "%.2f", value)
}

private struct SessionStandingsCard: View {
  let session: StandingsSession

  private var leadingSide: String? {
    if session.hookersPoints > session.slicersPoints { return "hookers" }
    if session.slicersPoints > session.hookersPoints { return "slicers" }
    return nil
  }

  var body: some View {
    BrandCard {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .firstTextBaseline) {
          VStack(alignment: .leading, spacing: 3) {
            Text(session.session.label)
              .font(.body.weight(.semibold))
              .foregroundStyle(BrandColors.ink)
            Text("\(session.matches.count) match\(session.matches.count == 1 ? "" : "es")")
              .font(.caption)
              .foregroundStyle(BrandColors.inkMuted)
          }
          Spacer()
          Image(systemName: "chevron.right")
            .font(.caption.weight(.semibold))
            .foregroundStyle(BrandColors.primary.opacity(0.45))
        }

        HStack(spacing: 0) {
          miniScore(label: "H", value: session.hookersPoints, emphasized: leadingSide == "hookers")
          Text("–")
            .font(.title3.weight(.medium))
            .foregroundStyle(BrandColors.inkMuted)
            .frame(width: 28)
          miniScore(label: "S", value: session.slicersPoints, emphasized: leadingSide == "slicers")
        }

        if let leader = session.pinkBallLeader, leader.holesCounted > 0, !leader.eliminated || session.pinkBallStandings.allSatisfy(\.eliminated) {
          HStack(spacing: 8) {
            Circle()
              .fill(Color.pink)
              .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
              Text(leader.eliminated ? "Pink ball winner" : "Pink ball leader")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.pink)
              Text(shortMatchLabel(leader.matchLabel))
                .font(.caption.weight(.medium))
                .foregroundStyle(BrandColors.ink)
            }
            Spacer(minLength: 0)
            if let net = leader.totalNet {
              Text("Net \(net)")
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(Color.pink)
            }
          }
          .padding(10)
          .background(Color.pink.opacity(0.10))
          .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
      }
    }
  }

  private func shortMatchLabel(_ label: String) -> String {
    if let range = label.range(of: " · ") {
      return String(label[range.upperBound...])
    }
    return label
  }

  private func miniScore(label: String, value: Double, emphasized: Bool) -> some View {
    HStack(spacing: 8) {
      Text(label)
        .font(.caption2.weight(.bold))
        .foregroundStyle(BrandColors.onPrimary)
        .frame(width: 22, height: 22)
        .background(BrandColors.primary.opacity(emphasized ? 1 : 0.55))
        .clipShape(Circle())
      Text(pointsText(value))
        .font(.title2.weight(.bold).monospacedDigit())
        .foregroundStyle(emphasized ? BrandColors.primary : BrandColors.ink)
    }
    .frame(maxWidth: .infinity)
  }

  private func pointsText(_ value: Double) -> String {
    value == floor(value) ? String(Int(value)) : String(format: "%.1f", value)
  }
}

struct SessionMatchUpsView: View {
  let sessionStandings: StandingsSession

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        CupScoreHero(
          hookersPoints: sessionStandings.hookersPoints,
          slicersPoints: sessionStandings.slicersPoints,
          title: sessionStandings.session.label,
          subtitle: "Session score"
        )

        if !sessionStandings.pinkBallStandings.isEmpty {
          VStack(alignment: .leading, spacing: 12) {
            BrandSectionHeader(
              title: "Pink ball",
              subtitle: "Lowest net among best-ball groups wins"
            )

            BrandCard {
              let activeLeader = sessionStandings.pinkBallLeader
              if let leader = activeLeader, leader.holesCounted > 0, !leader.eliminated {
                VStack(alignment: .leading, spacing: 10) {
                  HStack {
                    Text("Leading match")
                      .font(.caption.weight(.semibold))
                      .foregroundStyle(Color.pink)
                    Spacer()
                    if let net = leader.totalNet {
                      Text("Net \(net)")
                        .font(.subheadline.weight(.bold).monospacedDigit())
                        .foregroundStyle(Color.pink)
                    }
                  }
                  Text(leader.matchLabel)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(BrandColors.ink)

                  Divider().background(BrandColors.hairline)

                  pinkBallRows(sessionStandings.pinkBallStandings)
                }
              } else if let leader = activeLeader, leader.eliminated,
                        sessionStandings.pinkBallStandings.allSatisfy(\.eliminated) {
                VStack(alignment: .leading, spacing: 10) {
                  HStack {
                    Text("Winner (all groups out)")
                      .font(.caption.weight(.semibold))
                      .foregroundStyle(Color.pink)
                    Spacer()
                    if let net = leader.totalNet {
                      Text("Net \(net)")
                        .font(.subheadline.weight(.bold).monospacedDigit())
                        .foregroundStyle(Color.pink)
                    }
                  }
                  Text(leader.matchLabel)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(BrandColors.ink)

                  Divider().background(BrandColors.hairline)

                  pinkBallRows(sessionStandings.pinkBallStandings)
                }
              } else if sessionStandings.pinkBallStandings.contains(where: { $0.holesCounted > 0 }) {
                VStack(alignment: .leading, spacing: 10) {
                  Text("No leader yet — eliminated groups are out until every group loses all 3 balls.")
                    .font(.subheadline)
                    .foregroundStyle(BrandColors.inkMuted)

                  Divider().background(BrandColors.hairline)

                  pinkBallRows(sessionStandings.pinkBallStandings)
                }
              } else {
                Text("Pink ball scores will appear once groups start counting holes.")
                  .font(.subheadline)
                  .foregroundStyle(BrandColors.inkMuted)
              }
            }
          }
        }

        BrandSectionHeader(title: "Match ups")

        if sessionStandings.matches.isEmpty {
          BrandCard {
            Text("No matches scheduled for this session yet.")
              .foregroundStyle(BrandColors.inkMuted)
          }
        } else {
          ForEach(sessionStandings.matches) { match in
            NavigationLink {
              MatchDetailView(matchId: match.id)
            } label: {
              BrandCard {
                MatchStandingsRow(match: match)
              }
            }
            .buttonStyle(.plain)
          }
        }
      }
      .padding(16)
    }
    .background(BrandScreenBackground())
    .navigationTitle(sessionStandings.session.label)
    .navigationBarTitleDisplayMode(.inline)
    .toolbarBackground(BrandColors.canvas, for: .navigationBar)
  }

  @ViewBuilder
  private func pinkBallRows(_ standings: [PinkBallMatchStanding]) -> some View {
    ForEach(standings.filter { $0.holesCounted > 0 }) { row in
      HStack {
        Text(row.rank.map(String.init) ?? "—")
          .font(.caption.weight(.bold).monospacedDigit())
          .foregroundStyle(BrandColors.inkMuted)
          .frame(width: 20, alignment: .trailing)
        Text(row.matchLabel)
          .font(.subheadline)
          .foregroundStyle(row.isLeader ? Color.pink : BrandColors.ink)
          .lineLimit(2)
        Spacer(minLength: 8)
        if row.eliminated {
          Text("Out")
            .font(.caption2.weight(.bold))
            .foregroundStyle(.red)
        }
        Text(row.totalNet.map { "Net \($0)" } ?? "—")
          .font(.caption.weight(.semibold).monospacedDigit())
          .foregroundStyle(BrandColors.inkMuted)
      }
    }
  }
}

struct MatchStandingsRow: View {
  let match: StandingsMatchRow

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(match.label)
        .font(.body.weight(.semibold))
        .foregroundStyle(BrandColors.ink)
        .multilineTextAlignment(.leading)

      HStack(spacing: 8) {
        if let format = match.format {
          Text(format.title)
            .font(.caption)
            .foregroundStyle(BrandColors.inkMuted)
        }
        statusBadge
        Spacer(minLength: 0)
        if match.countsTowardStandings,
           let hp = match.hookersPoints,
           let sp = match.slicersPoints {
          Text("\(formatPoints(hp))–\(formatPoints(sp))")
            .font(.subheadline.weight(.bold).monospacedDigit())
            .foregroundStyle(BrandColors.primary)
        } else if !match.countsTowardStandings, match.status != .complete {
          Text("Hidden until complete")
            .font(.caption)
            .foregroundStyle(BrandColors.primarySoft)
        }
      }
    }
  }

  @ViewBuilder
  private var statusBadge: some View {
    let (text, color): (String, Color) = {
      switch match.status {
      case .setup:
        return ("Setup", BrandColors.inkMuted)
      case .inProgress:
        return match.scoringVisibility == .live
          ? ("Live", Color.red.opacity(0.85))
          : ("In progress", BrandColors.primarySoft)
      case .complete:
        return ("Final", BrandColors.primary)
      }
    }()

    Text(text)
      .font(.caption2.weight(.bold))
      .foregroundStyle(color)
      .padding(.horizontal, 8)
      .padding(.vertical, 3)
      .background(color.opacity(0.12))
      .clipShape(Capsule())
  }

  private func formatPoints(_ value: Double) -> String {
    value == floor(value) ? String(Int(value)) : String(format: "%.1f", value)
  }
}
