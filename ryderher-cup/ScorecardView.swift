import SwiftUI

/// Traditional golf scorecard: holes across, players/teams down, OUT/IN/TOT.
struct ScorecardView: View {
  @EnvironmentObject private var sessionManager: SessionManager
  let matchId: UUID

  @State private var match: TournamentMatch?
  @State private var loadError: String?
  @State private var isLoading = true

  private let front = Array(1 ... 9)
  private let back = Array(10 ... 18)
  private let cellWidth: CGFloat = 28
  private let nameWidth: CGFloat = 92

  var body: some View {
    Group {
      if isLoading && match == nil {
        ProgressView()
      } else if let loadError, match == nil {
        ContentUnavailableView(
          "Could not load scorecard",
          systemImage: "exclamationmark.triangle",
          description: Text(loadError)
        )
      } else if let match {
        ScrollView([.horizontal, .vertical]) {
          VStack(alignment: .leading, spacing: 20) {
            header(match)
            nineBlock(title: "Out", holes: front, match: match, includeRunningTotal: false)
            nineBlock(title: "In", holes: back, match: match, includeRunningTotal: true)

            if let result = match.result, match.scoresVisible {
              Text(
                "Match: Hookers \(fmt(result.hookersPoints)) – Slicers \(fmt(result.slicersPoints))"
                  + (result.isProvisional ? " (live)" : "")
              )
              .font(.subheadline.weight(.semibold))
            }
          }
          .padding()
        }
      }
    }
    .navigationTitle("Scorecard")
    .navigationBarTitleDisplayMode(.inline)
    .task { await load() }
    .refreshable { await load() }
  }

  private func header(_ match: TournamentMatch) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(match.label)
        .font(.title3.weight(.bold))
      if let format = match.format {
        Text(format.title)
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
      if let course = match.course {
        Text(course.name)
          .font(.subheadline)
        if let tee = course.tee {
          Text("\(tee.name) tees")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
      if match.format?.supportsPinkBall == true {
        let remaining = match.pinkBallsRemaining ?? TournamentMatch.pinkBallsPerMatch
        let lost = match.pinkBallsLost ?? 0
        VStack(alignment: .leading, spacing: 4) {
          HStack(spacing: 6) {
            Circle()
              .fill(Color.pink)
              .frame(width: 8, height: 8)
            if let total = match.pinkBallScore?.totalNet {
              Text("Pink ball net \(total)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.pink)
              Text("· \(match.pinkBallScore?.holesCounted ?? 0) holes")
                .font(.caption)
                .foregroundStyle(.secondary)
            } else {
              Text("Pink ball")
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.pink)
            }
          }
          Text(
            lost == 0
              ? "\(remaining) of \(TournamentMatch.pinkBallsPerMatch) balls left"
              : "\(remaining) left · lost on \(lostHoleList(match))"
              + (match.pinkBallScore?.eliminated == true ? " · eliminated" : "")
          )
          .font(.caption)
          .foregroundStyle(.secondary)
        }
        .padding(.top, 4)
      }
    }
  }

  private func nineBlock(
    title: String,
    holes: [Int],
    match: TournamentMatch,
    includeRunningTotal: Bool
  ) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title)
        .font(.headline)

      VStack(spacing: 0) {
        row {
          labelCell("Hole", bold: true)
          ForEach(holes, id: \.self) { h in
            valueCell("\(h)", bold: true)
          }
          valueCell(title.uppercased(), bold: true)
          if includeRunningTotal {
            valueCell("TOT", bold: true)
          }
        }

        Divider()

        row {
          labelCell("Par")
          ForEach(holes, id: \.self) { h in
            valueCell("\(match.par(forHole: h))", bold: true)
          }
          valueCell("\(parTotal(holes: holes, match: match))", bold: true)
          if includeRunningTotal {
            valueCell("\(parTotal(holes: Array(1 ... 18), match: match))", bold: true)
          }
        }

        row {
          labelCell("HCP", muted: true)
          ForEach(holes, id: \.self) { h in
            let si = match.holeInfo(h)?.strokeIndex
            valueCell(si.map(String.init) ?? "—", muted: true)
          }
          valueCell("", muted: true)
          if includeRunningTotal {
            valueCell("", muted: true)
          }
        }

        if holes.first == 1 {
          VStack(alignment: .leading, spacing: 2) {
            Text("● under a score = that player/side gets a stroke (HCP 1 = hardest)")
            if match.format?.supportsPinkBall == true {
              Text("Pink row = carrier net · ✕ = ball lost · TOT = pink ball total")
            }
          }
          .font(.caption2)
          .foregroundStyle(.secondary)
          .padding(.top, 4)
          .frame(maxWidth: .infinity, alignment: .leading)
        }

        Divider().padding(.vertical, 2)

        if match.format?.usesTeamBall == true {
          scoreRow(
            name: "Hookers",
            subtitle: relativeCaption(match.relativeStrokes(side: "hookers")),
            holes: holes,
            match: match,
            includeRunningTotal: includeRunningTotal,
            scoreAt: { sideScore(side: "hookers", hole: $0, match: match) },
            strokesAt: { match.strokesReceived(side: "hookers", hole: $0) }
          )
          scoreRow(
            name: "Slicers",
            subtitle: relativeCaption(match.relativeStrokes(side: "slicers")),
            holes: holes,
            match: match,
            includeRunningTotal: includeRunningTotal,
            scoreAt: { sideScore(side: "slicers", hole: $0, match: match) },
            strokesAt: { match.strokesReceived(side: "slicers", hole: $0) }
          )
        } else {
          ForEach(match.players) { player in
            scoreRow(
              name: shortName(player.profile.displayName),
              subtitle: relativeCaption(match.relativeStrokes(profileId: player.profileId)),
              holes: holes,
              match: match,
              includeRunningTotal: includeRunningTotal,
              scoreAt: { playerScore(profileId: player.profileId, hole: $0, match: match) },
              strokesAt: { match.strokesReceived(profileId: player.profileId, hole: $0) },
              pinkCarrierAt: { match.pinkBall(forHole: $0)?.carrierProfileId == player.profileId },
              pinkLostAt: {
                let pb = match.pinkBall(forHole: $0)
                return pb?.carrierProfileId == player.profileId && (pb?.lost == true)
              }
            )
          }

          if match.format?.supportsPinkBall == true {
            pinkBallSummaryRow(
              holes: holes,
              match: match,
              includeRunningTotal: includeRunningTotal
            )
          }
        }
      }
      .padding(10)
      .background(Color(.secondarySystemBackground))
      .clipShape(RoundedRectangle(cornerRadius: 12))
    }
  }

  private func scoreRow(
    name: String,
    subtitle: String?,
    holes: [Int],
    match: TournamentMatch,
    includeRunningTotal: Bool,
    scoreAt: @escaping (Int) -> Int?,
    strokesAt: @escaping (Int) -> Int,
    pinkCarrierAt: ((Int) -> Bool)? = nil,
    pinkLostAt: ((Int) -> Bool)? = nil
  ) -> some View {
    row {
      VStack(alignment: .leading, spacing: 1) {
        HStack(spacing: 4) {
          Text(name)
            .font(.caption.weight(.medium))
            .lineLimit(1)
          if let subtitle {
            Text(subtitle)
              .font(.caption2)
              .foregroundStyle(BrandColors.primary)
          }
        }
      }
      .frame(width: nameWidth, alignment: .leading)

      ForEach(holes, id: \.self) { h in
        let score = scoreAt(h)
        let strokes = strokesAt(h)
        let isPink = pinkCarrierAt?(h) == true
        let lostPink = pinkLostAt?(h) == true
        valueCell(
          score.map(String.init) ?? "·",
          relativeToPar: score.map { $0 - match.par(forHole: h) },
          strokesOnHole: strokes,
          isPinkCarrier: isPink,
          pinkLost: lostPink
        )
      }

      let nine = sumScores(holes: holes, scoreAt: scoreAt)
      valueCell(nine.map(String.init) ?? "—", bold: true)

      if includeRunningTotal {
        let total = sumScores(holes: Array(1 ... 18), scoreAt: scoreAt)
        valueCell(total.map(String.init) ?? "—", bold: true)
      }
    }
  }

  private func pinkBallSummaryRow(
    holes: [Int],
    match: TournamentMatch,
    includeRunningTotal: Bool
  ) -> some View {
    row {
      HStack(spacing: 4) {
        Circle()
          .fill(Color.pink)
          .frame(width: 6, height: 6)
        Text("Pink")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(Color.pink)
      }
      .frame(width: nameWidth, alignment: .leading)

      ForEach(holes, id: \.self) { h in
        pinkHoleCell(hole: h, match: match)
      }

      let nine = pinkNetTotal(holes: holes, match: match)
      valueCell(nine.map(String.init) ?? "—", bold: true, isPinkCarrier: true)

      if includeRunningTotal {
        let total = match.pinkBallScore?.totalNet
        valueCell(total.map(String.init) ?? "—", bold: true, isPinkCarrier: true)
      }
    }
  }

  @ViewBuilder
  private func pinkHoleCell(hole: Int, match: TournamentMatch) -> some View {
    if let holeNet = match.pinkBallNet(forHole: hole),
       let player = match.players.first(where: { $0.profileId == holeNet.carrierProfileId }) {
      VStack(spacing: 0) {
        Text(holeNet.counts ? (holeNet.netStrokes.map(String.init) ?? "·") : "·")
          .font(.caption.weight(.semibold).monospacedDigit())
          .foregroundStyle(holeNet.counts ? Color.pink : Color.secondary)
        HStack(spacing: 1) {
          Text(initials(player.profile.displayName))
            .font(.system(size: 7, weight: .bold).monospaced())
            .foregroundStyle(Color.pink.opacity(0.85))
          if holeNet.lost {
            Text("✕")
              .font(.system(size: 7, weight: .bold))
              .foregroundStyle(.red)
          }
        }
        .frame(height: 9)
      }
      .frame(width: cellWidth, height: 28)
      .background(Color.pink.opacity(holeNet.lost ? 0.22 : 0.12))
      .clipShape(RoundedRectangle(cornerRadius: 4))
      .opacity(holeNet.counts ? 1 : 0.45)
    } else {
      Text("·")
        .font(.caption)
        .foregroundStyle(.tertiary)
        .frame(width: cellWidth, height: 28)
    }
  }

  private func pinkNetTotal(holes: [Int], match: TournamentMatch) -> Int? {
    let values = holes.compactMap { hole -> Int? in
      guard let net = match.pinkBallNet(forHole: hole), net.counts else { return nil }
      return net.netStrokes
    }
    guard !values.isEmpty else { return nil }
    return values.reduce(0, +)
  }

  private func relativeCaption(_ relative: Int) -> String? {
    relative > 0 ? "+\(relative)" : nil
  }

  private func lostHoleList(_ match: TournamentMatch) -> String {
    let holes = (match.pinkBallHoles ?? [])
      .filter(\.lost)
      .map(\.holeNumber)
      .sorted()
    return holes.map(String.init).joined(separator: ", ")
  }

  private func initials(_ name: String) -> String {
    let parts = name.split(separator: " ")
    if parts.count >= 2 {
      return "\(parts[0].prefix(1))\(parts.last!.prefix(1))"
    }
    return String(name.prefix(2)).uppercased()
  }

  private func row<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
    HStack(spacing: 0, content: content)
      .padding(.vertical, 3)
  }

  private func labelCell(_ text: String, bold: Bool = false, muted: Bool = false) -> some View {
    Text(text)
      .font(bold ? .caption.weight(.semibold) : .caption)
      .foregroundStyle(muted ? .secondary : .primary)
      .frame(width: nameWidth, alignment: .leading)
  }

  private func valueCell(
    _ text: String,
    bold: Bool = false,
    muted: Bool = false,
    relativeToPar: Int? = nil,
    strokesOnHole: Int = 0,
    isPinkCarrier: Bool = false,
    pinkLost: Bool = false
  ) -> some View {
    VStack(spacing: 1) {
      Text(text)
        .font((bold ? Font.caption.weight(.semibold) : Font.caption).monospacedDigit())
        .foregroundStyle(scoreColor(relativeToPar, muted: muted, isPinkCarrier: isPinkCarrier))
      if pinkLost {
        Text("lost")
          .font(.system(size: 7, weight: .bold))
          .foregroundStyle(.red)
          .frame(height: 5)
      } else if strokesOnHole > 0 {
        HStack(spacing: 1) {
          ForEach(0..<min(strokesOnHole, 2), id: \.self) { _ in
            Circle()
              .fill(BrandColors.primary)
              .frame(width: 4, height: 4)
          }
        }
        .frame(height: 5)
      } else if isPinkCarrier {
        Circle()
          .fill(Color.pink)
          .frame(width: 4, height: 4)
          .frame(height: 5)
      } else {
        Color.clear.frame(height: 5)
      }
    }
    .frame(width: cellWidth, height: 28)
    .background {
      if pinkLost {
        RoundedRectangle(cornerRadius: 4)
          .fill(Color.pink.opacity(0.28))
      } else if isPinkCarrier {
        RoundedRectangle(cornerRadius: 4)
          .fill(Color.pink.opacity(0.16))
      } else if strokesOnHole > 0 {
        RoundedRectangle(cornerRadius: 4)
          .fill(BrandColors.primary.opacity(0.10))
      } else if let relativeToPar, relativeToPar <= -2 {
        Circle().fill(Color.green.opacity(0.18))
      }
    }
    .multilineTextAlignment(.center)
  }

  private func scoreColor(_ relative: Int?, muted: Bool, isPinkCarrier: Bool = false) -> Color {
    if muted { return .secondary }
    if isPinkCarrier { return Color.pink }
    guard let relative else { return .primary }
    if relative < 0 { return .green }
    if relative > 0 { return .primary }
    return .primary
  }

  private func playerScore(profileId: UUID, hole: Int, match: TournamentMatch) -> Int? {
    match.holeScores?.first {
      $0.holeNumber == hole && $0.profileId == profileId
    }?.grossStrokes
  }

  private func sideScore(side: String, hole: Int, match: TournamentMatch) -> Int? {
    match.holeScores?.first {
      $0.holeNumber == hole && $0.side == side
    }?.grossStrokes
  }

  private func sumScores(holes: [Int], scoreAt: (Int) -> Int?) -> Int? {
    let values = holes.compactMap(scoreAt)
    guard !values.isEmpty else { return nil }
    return values.reduce(0, +)
  }

  private func parTotal(holes: [Int], match: TournamentMatch) -> Int {
    holes.reduce(0) { $0 + match.par(forHole: $1) }
  }

  private func shortName(_ name: String) -> String {
    let parts = name.split(separator: " ")
    if parts.count >= 2 {
      return "\(parts[0].prefix(1)). \(parts.last!)"
    }
    return name
  }

  private func fmt(_ value: Double) -> String {
    value == floor(value) ? String(Int(value)) : String(format: "%.1f", value)
  }

  private func load() async {
    isLoading = true
    loadError = nil
    defer { isLoading = false }
    do {
      let token = try sessionManager.requireToken()
      match = try await ApiClient.shared.fetchMatch(token: token, id: matchId)
    } catch {
      loadError = error.localizedDescription
    }
  }
}
