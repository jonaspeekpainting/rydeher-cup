import SwiftUI

struct MatchDetailView: View {
  @EnvironmentObject private var sessionManager: SessionManager
  let matchId: UUID

  @State private var match: TournamentMatch?
  @State private var loadError: String?
  @State private var isLoading = true
  @State private var hole = 1
  @State private var playerScores: [UUID: Int] = [:]
  @State private var sideScores: [String: Int] = [:]
  @State private var pinkCarrierId: UUID?
  @State private var pinkBallLost = false
  @State private var errorMessage: String?
  @State private var isSaving = false
  @State private var isStarting = false
  @State private var didSetInitialHole = false

  private var currentPar: Int {
    match?.par(forHole: hole) ?? 4
  }

  private var currentHoleInfo: MatchCourseHole? {
    match?.holeInfo(hole)
  }

  var body: some View {
    Group {
      if isLoading && match == nil {
        ProgressView()
      } else if let loadError, match == nil {
        ContentUnavailableView(
          "Could not load match",
          systemImage: "exclamationmark.triangle",
          description: Text(loadError)
        )
      } else if let match {
        switch match.status {
        case .inProgress:
          liveScoringView(match)
        case .setup:
          upcomingDetail(match)
        case .complete:
          completedDetail(match)
        }
      }
    }
    .navigationTitle(match?.label ?? "Match")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      if match?.status == .inProgress || match?.status == .complete {
        ToolbarItem(placement: .topBarTrailing) {
          NavigationLink {
            ScorecardView(matchId: matchId)
          } label: {
            Image(systemName: "tablecells")
          }
        }
      }
    }
    .task { await load() }
    .refreshable { await load() }
  }

  // MARK: - In progress (live card + inline scoring)

  private func liveScoringView(_ match: TournamentMatch) -> some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        LiveMatchBattleCard(
          match: match,
          showsCallToAction: false,
          pinkBallHole: hole
        )

        scoringPanel(match)
      }
      .padding()
    }
  }

  private func scoringPanel(_ match: TournamentMatch) -> some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack {
        Text("Hole \(hole)")
          .font(.title2.weight(.bold))
        Spacer()
        HStack(spacing: 16) {
          Button {
            if hole > 1 {
              hole -= 1
              hydrateInputs(from: match)
            }
          } label: {
            Image(systemName: "chevron.left.circle.fill")
              .font(.title2)
          }
          .disabled(hole <= 1)

          Button {
            if hole < 18 {
              hole += 1
              hydrateInputs(from: match)
            }
          } label: {
            Image(systemName: "chevron.right.circle.fill")
              .font(.title2)
          }
          .disabled(hole >= 18)
        }
        .buttonStyle(.plain)
      }

      HStack(spacing: 12) {
        Label("Par \(currentPar)", systemImage: "flag.fill")
        if let si = currentHoleInfo?.strokeIndex {
          Text("·")
            .foregroundStyle(.tertiary)
          Text(MatchHandicapMath.difficultyLabel(strokeIndex: si))
            .foregroundStyle(.secondary)
          Text("(#\(si))")
            .foregroundStyle(.tertiary)
        }
        if let yards = currentHoleInfo?.yardage {
          Text("·")
            .foregroundStyle(.tertiary)
          Text("\(yards) yds")
            .foregroundStyle(.secondary)
        }
        Spacer()
      }
      .font(.subheadline)

      if let course = match.course {
        Text(course.name + (course.tee.map { " · \($0.name)" } ?? ""))
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      strokeAllocationCard(match)

      if match.format?.supportsPinkBall == true {
        pinkBallCard(match)
      }

      Divider()

      if match.format?.usesTeamBall == true {
        ForEach(["hookers", "slicers"], id: \.self) { side in
          let strokes = match.strokesReceived(side: side, hole: hole)
          ScoreStepperRow(
            title: side.capitalized,
            subtitle: strokeSubtitle(
              relative: match.relativeStrokes(side: side),
              onThisHole: strokes
            ),
            value: binding(forSide: side),
            par: currentPar,
            strokesOnHole: strokes
          )
        }
      } else {
        ForEach(match.players) { player in
          let strokes = match.strokesReceived(profileId: player.profileId, hole: hole)
          let isPinkCarrier =
            match.format?.supportsPinkBall == true
            && (pinkCarrierId ?? match.suggestedPinkBallCarrier(forHole: hole)) == player.profileId
          ScoreStepperRow(
            title: player.profile.displayName,
            subtitle: strokeSubtitle(
              side: player.side,
              relative: match.relativeStrokes(profileId: player.profileId),
              onThisHole: strokes,
              courseHandicap: match.playingHandicaps?.players
                .first(where: { $0.profileId == player.profileId })?.courseHandicap
            ),
            value: binding(forPlayer: player.profileId),
            par: currentPar,
            strokesOnHole: strokes,
            isPinkCarrier: isPinkCarrier
          )
        }
      }

      if let errorMessage {
        Text(errorMessage)
          .font(.footnote)
          .foregroundStyle(.red)
      }

      Button {
        Task { await save(match: match) }
      } label: {
        Group {
          if isSaving {
            ProgressView()
          } else {
            Text(hole < 18 ? "Save & next hole" : "Save hole \(hole)")
              .fontWeight(.semibold)
          }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
      }
      .buttonStyle(.borderedProminent)
      .tint(BrandColors.primary)
      .disabled(isSaving || !match.canScore)

      if !match.canScore {
        Text("You’re viewing this match — only players in it can enter scores.")
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
    }
    .padding(16)
    .background(Color(.secondarySystemBackground))
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
  }

  // MARK: - Setup / complete

  private func upcomingDetail(_ match: TournamentMatch) -> some View {
    List {
      Section("Match") {
        LabeledContent("Format", value: match.format?.title ?? "—")
        LabeledContent("Status", value: "Upcoming")
        LabeledContent("Scoring", value: match.scoringVisibility.title)
      }
      Section("Pairings") {
        ForEach(match.players) { player in
          HStack {
            Text(player.profile.displayName)
            Spacer()
            Text(player.side?.capitalized ?? "—")
              .foregroundStyle(.secondary)
          }
        }
      }
      if let course = match.course {
        Section("Course") {
          LabeledContent("Name", value: course.name)
          if let tee = course.tee {
            LabeledContent("Tee", value: tee.name)
          }
        }
      }
      if match.format?.supportsPinkBall == true {
        Section("Pink ball") {
          Text("After you start, pick a different pink-ball player on holes 1–4. From hole 5 on, that order repeats automatically.")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
      }
      if sessionManager.profile?.isAdmin == true {
        Section {
          Button {
            Task { await startMatch() }
          } label: {
            if isStarting {
              ProgressView()
                .frame(maxWidth: .infinity)
            } else {
              Text("Start match")
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
            }
          }
          .disabled(isStarting)
          if let errorMessage {
            Text(errorMessage)
              .font(.footnote)
              .foregroundStyle(.red)
          }
        }
      } else {
        Section {
          Text("Scoring opens when an admin starts the match.")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
      }
    }
    .listStyle(.insetGrouped)
  }

  private func startMatch() async {
    errorMessage = nil
    isStarting = true
    defer { isStarting = false }
    do {
      let token = try sessionManager.requireToken()
      let updated = try await ApiClient.shared.startMatch(token: token, id: matchId)
      match = updated
      hole = updated.currentHoleNumber
      didSetInitialHole = true
      hydrateInputs(from: updated)
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  private func completedDetail(_ match: TournamentMatch) -> some View {
    List {
      if let result = match.result {
        Section("Final") {
          LabeledContent(
            "Points",
            value: "\(fmt(result.hookersPoints)) – \(fmt(result.slicersPoints))"
          )
          LabeledContent(
            "Holes",
            value: "\(result.holesWonHookers) – \(result.holesWonSlicers) (\(result.holesHalved) halved)"
          )
        }
      }
      if match.format?.supportsPinkBall == true, let pink = match.pinkBallScore {
        Section("Pink ball") {
          LabeledContent(
            "Net total",
            value: pink.totalNet.map(String.init) ?? "—"
          )
          LabeledContent(
            "Holes counted",
            value: "\(pink.holesCounted)"
          )
          LabeledContent(
            "Balls left",
            value: "\(pink.ballsRemaining) of \(TournamentMatch.pinkBallsPerMatch)"
          )
          if pink.eliminated {
            Text("Eliminated — all 3 pink balls lost")
              .font(.footnote)
              .foregroundStyle(.red)
          }
        }
      }
      Section("Pairings") {
        ForEach(match.players) { player in
          HStack {
            Text(player.profile.displayName)
            Spacer()
            Text(player.side?.capitalized ?? "—")
              .foregroundStyle(.secondary)
          }
        }
      }
      Section {
        NavigationLink {
          ScorecardView(matchId: matchId)
        } label: {
          Label("Full scorecard", systemImage: "tablecells")
        }
      }
    }
    .listStyle(.insetGrouped)
  }

  // MARK: - Scoring helpers

  @ViewBuilder
  private func pinkBallCard(_ match: TournamentMatch) -> some View {
    let remaining = match.pinkBallsRemaining ?? TournamentMatch.pinkBallsPerMatch
    let lostCount = match.pinkBallsLost ?? 0
    let eliminated = remaining == 0 && !pinkBallLost
    let score = match.pinkBallScore
    let canSelect = match.canSelectPinkBallCarrier(forHole: hole)
    let selectable = match.selectablePinkBallCarriers(forHole: hole)
    let carrierId = pinkCarrierId ?? match.assignedPinkBallCarrier(forHole: hole)
    let assignedName = match.players
      .first(where: { $0.profileId == carrierId })?
      .profile.displayName

    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 8) {
        Circle()
          .fill(Color.pink)
          .frame(width: 10, height: 10)
        Text("Pink ball")
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(.primary)
        Spacer()
        if let total = score?.totalNet {
          Text("Net \(total)")
            .font(.subheadline.weight(.bold).monospacedDigit())
            .foregroundStyle(Color.pink)
        }
      }

      HStack {
        Text("\(remaining) of \(TournamentMatch.pinkBallsPerMatch) left")
          .font(.caption.weight(.medium).monospacedDigit())
          .foregroundStyle(remaining == 0 ? Color.red : Color.secondary)
        if let counted = score?.holesCounted, counted > 0 {
          Text("· \(counted) hole\(counted == 1 ? "" : "s") counted")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }

      if canSelect {
        Text("Choose a different player on holes 1–\(match.pinkBallRotationLength). After that the order repeats automatically.")
          .font(.caption)
          .foregroundStyle(.secondary)

        HStack {
          Text("Who has the pink ball")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.primary)
          Spacer(minLength: 8)
          Picker("Who has the pink ball", selection: Binding(
            get: {
              pinkCarrierId
                ?? match.assignedPinkBallCarrier(forHole: hole)
                ?? selectable.first?.profileId
            },
            set: { pinkCarrierId = $0 }
          )) {
            ForEach(selectable) { player in
              Text(player.profile.displayName).tag(Optional(player.profileId))
            }
          }
          .labelsHidden()
          .pickerStyle(.menu)
          .tint(.pink)
          .disabled(!match.canScore || selectable.isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.primary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
      } else {
        Text("From the hole 1–\(match.pinkBallRotationLength) lineup — order repeats automatically.")
          .font(.caption)
          .foregroundStyle(.secondary)
        HStack {
          Text("Who has the pink ball")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.primary)
          Spacer()
          Text(assignedName ?? "Set holes 1–\(match.pinkBallRotationLength) first")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(assignedName == nil ? Color.red : Color.pink)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.primary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
      }

      Button {
        guard match.canScore, !(eliminated && !pinkBallLost) else { return }
        pinkBallLost.toggle()
      } label: {
        HStack(spacing: 12) {
          Image(systemName: pinkBallLost ? "checkmark.square.fill" : "square")
            .font(.title2)
            .foregroundStyle(pinkBallLost ? Color.pink : Color.primary)
          Text("Lost pink ball")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
          Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.primary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .disabled(!match.canScore || (eliminated && !pinkBallLost))
      .accessibilityLabel("Lost pink ball")
      .accessibilityAddTraits(.isButton)
      .accessibilityValue(pinkBallLost ? "Checked" : "Unchecked")
      .accessibilityAddTraits(pinkBallLost ? .isSelected : [])

      if lostCount > 0 {
        Text(lostHolesLabel(match))
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      if remaining == 0 {
        Text("All 3 pink balls are gone — this group is out of the pink ball game.")
          .font(.caption.weight(.medium))
          .foregroundStyle(.red)
      }
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.pink.opacity(0.14))
    .overlay(
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .strokeBorder(Color.pink.opacity(0.35), lineWidth: 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
  }

  private func lostHolesLabel(_ match: TournamentMatch) -> String {
    let holes = (match.pinkBallHoles ?? [])
      .filter(\.lost)
      .map(\.holeNumber)
      .sorted()
    guard !holes.isEmpty else { return "" }
    let list = holes.map(String.init).joined(separator: ", ")
    return "Lost on hole\(holes.count == 1 ? "" : "s") \(list)"
  }

  @ViewBuilder
  private func strokeAllocationCard(_ match: TournamentMatch) -> some View {
    let si = match.strokeIndex(forHole: hole)
    let stroking: [(String, Int)] = {
      if match.format?.usesTeamBall == true {
        return ["hookers", "slicers"].compactMap { side in
          let n = match.strokesReceived(side: side, hole: hole)
          return n > 0 ? (side.capitalized, n) : nil
        }
      }
      return match.players.compactMap { player in
        let n = match.strokesReceived(profileId: player.profileId, hole: hole)
        guard n > 0 else { return nil }
        return (shortLastName(player.profile.displayName), n)
      }
    }()

    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 6) {
        Image(systemName: "circle.fill")
          .font(.system(size: 7))
          .foregroundStyle(BrandColors.primary)
        Text("Strokes on this hole")
          .font(.caption.weight(.semibold))
        Spacer()
        Text("HCP \(si) · hardest holes first")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }

      if stroking.isEmpty {
        Text("Nobody gets a stroke here — all square on strokes.")
          .font(.caption)
          .foregroundStyle(.secondary)
      } else {
        FlowStrokeChips(entries: stroking)
      }

      if let snap = match.playingHandicaps {
        Text(handicapLegend(match: match, snap: snap))
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(BrandColors.primary.opacity(0.08))
    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
  }

  private func handicapLegend(match: TournamentMatch, snap: PlayingHandicapSnapshot) -> String {
    if match.format?.usesTeamBall == true {
      let parts = snap.sides.map { side in
        "\(side.side.capitalized) +\(side.relativeStrokes) (CH \(side.courseHandicaps.map(String.init).joined(separator: "/")))"
      }
      return "Playing strokes vs low side: " + parts.joined(separator: " · ")
    }
    let parts = match.players.compactMap { player -> String? in
      guard let ph = snap.players.first(where: { $0.profileId == player.profileId }) else {
        return nil
      }
      return "\(shortLastName(player.profile.displayName)) +\(ph.relativeStrokes) (CH \(ph.courseHandicap))"
    }
    return "Playing strokes vs low: " + parts.joined(separator: " · ")
  }

  private func strokeSubtitle(
    side: String? = nil,
    relative: Int,
    onThisHole: Int,
    courseHandicap: Int? = nil
  ) -> String {
    var bits: [String] = []
    if let side {
      bits.append(side.capitalized)
    }
    if let courseHandicap {
      bits.append("CH \(courseHandicap)")
    }
    if relative > 0 {
      bits.append("+\(relative) strokes")
    } else {
      bits.append("strokes off")
    }
    if onThisHole > 0 {
      bits.append(onThisHole == 1 ? "gets stroke" : "gets \(onThisHole) strokes")
    }
    return bits.joined(separator: " · ")
  }

  private func shortLastName(_ name: String) -> String {
    name.split(separator: " ").last.map(String.init) ?? name
  }

  private func binding(forPlayer id: UUID) -> Binding<Int> {
    Binding(
      get: { playerScores[id] ?? currentPar },
      set: { playerScores[id] = $0 }
    )
  }

  private func binding(forSide side: String) -> Binding<Int> {
    Binding(
      get: { sideScores[side] ?? currentPar },
      set: { sideScores[side] = $0 }
    )
  }

  private func load() async {
    isLoading = true
    loadError = nil
    defer { isLoading = false }
    do {
      let token = try sessionManager.requireToken()
      let loaded = try await ApiClient.shared.fetchMatch(token: token, id: matchId)
      match = loaded
      if !didSetInitialHole {
        hole = loaded.currentHoleNumber
        didSetInitialHole = true
      }
      hydrateInputs(from: loaded)
    } catch {
      loadError = error.localizedDescription
    }
  }

  private func hydrateInputs(from match: TournamentMatch) {
    let par = match.par(forHole: hole)
    playerScores = [:]
    sideScores = [:]

    for player in match.players {
      playerScores[player.profileId] = par
    }
    sideScores["hookers"] = par
    sideScores["slicers"] = par

    if let existing = match.pinkBall(forHole: hole) {
      pinkCarrierId = existing.carrierProfileId
      pinkBallLost = existing.lost
    } else if let assigned = match.assignedPinkBallCarrier(forHole: hole) {
      pinkCarrierId = assigned
      pinkBallLost = false
    } else {
      pinkCarrierId = match.selectablePinkBallCarriers(forHole: hole).first?.profileId
      pinkBallLost = false
    }

    guard let scores = match.holeScores else { return }
    for score in scores where score.holeNumber == hole {
      if let profileId = score.profileId {
        playerScores[profileId] = score.grossStrokes
      }
      if let side = score.side {
        sideScores[side] = score.grossStrokes
      }
    }
  }

  private func save(match: TournamentMatch) async {
    errorMessage = nil
    isSaving = true
    defer { isSaving = false }

    do {
      let token = try sessionManager.requireToken()
      let updated: TournamentMatch
      let pinkPayload: [String: Any]?
      if match.format?.supportsPinkBall == true {
        let carrier: UUID?
        if match.canSelectPinkBallCarrier(forHole: hole) {
          let allowed = Set(match.selectablePinkBallCarriers(forHole: hole).map(\.profileId))
          if let chosen = pinkCarrierId, allowed.contains(chosen) {
            carrier = chosen
          } else {
            carrier = match.assignedPinkBallCarrier(forHole: hole)
              ?? match.selectablePinkBallCarriers(forHole: hole).first?.profileId
          }
        } else {
          carrier = match.assignedPinkBallCarrier(forHole: hole)
        }
        guard let carrier else {
          errorMessage = "Set a unique pink-ball player on holes 1–\(match.pinkBallRotationLength) before continuing."
          return
        }
        pinkPayload = [
          "carrier_profile_id": carrier.uuidString.lowercased(),
          "lost": pinkBallLost,
        ]
      } else {
        pinkPayload = nil
      }

      if match.format?.usesTeamBall == true {
        let payload: [[String: Any]] = ["hookers", "slicers"].map { side in
          [
            "side": side,
            "gross_strokes": sideScores[side] ?? match.par(forHole: hole),
          ]
        }
        updated = try await ApiClient.shared.putHoleScore(
          token: token,
          matchId: matchId,
          hole: hole,
          playerScores: nil,
          sideScores: payload,
          pinkBall: pinkPayload
        )
      } else {
        let payload: [[String: Any]] = match.players.map { player in
          [
            "profile_id": player.profileId.uuidString.lowercased(),
            "gross_strokes": playerScores[player.profileId] ?? match.par(forHole: hole),
          ]
        }
        updated = try await ApiClient.shared.putHoleScore(
          token: token,
          matchId: matchId,
          hole: hole,
          playerScores: payload,
          sideScores: nil,
          pinkBall: pinkPayload
        )
      }
      self.match = updated
      if hole < 18 {
        hole += 1
      }
      hydrateInputs(from: updated)
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  private func fmt(_ value: Double) -> String {
    value == floor(value) ? String(Int(value)) : String(format: "%.1f", value)
  }
}

struct ScoreStepperRow: View {
  let title: String
  let subtitle: String?
  @Binding var value: Int
  let par: Int
  var strokesOnHole: Int = 0
  var isPinkCarrier: Bool = false

  private var net: Int { value - strokesOnHole }

  var body: some View {
    HStack(alignment: .center) {
      VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: 6) {
          Text(title)
          if isPinkCarrier {
            Text("PINK")
              .font(.caption2.weight(.bold))
              .foregroundStyle(.white)
              .padding(.horizontal, 6)
              .padding(.vertical, 2)
              .background(Color.pink)
              .clipShape(Capsule())
          }
          if strokesOnHole > 0 {
            Text(strokesOnHole == 1 ? "●" : String(repeating: "●", count: min(strokesOnHole, 3)))
              .font(.caption.weight(.bold))
              .foregroundStyle(BrandColors.primary)
              .accessibilityLabel(
                strokesOnHole == 1
                  ? "Gets a stroke on this hole"
                  : "Gets \(strokesOnHole) strokes on this hole"
              )
          }
        }
        if let subtitle {
          Text(subtitle)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        if strokesOnHole > 0 {
          Text("Net \(net)")
            .font(.caption2.weight(.semibold).monospacedDigit())
            .foregroundStyle(BrandColors.primary)
        }
      }
      Spacer()
      HStack(spacing: 12) {
        Button {
          if value > 1 { value -= 1 }
        } label: {
          Image(systemName: "minus.circle.fill")
            .font(.title2)
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)

        Text("\(value)")
          .font(.title3.monospacedDigit().weight(.semibold))
          .frame(minWidth: 28)
          .foregroundStyle(
            value == par
              ? Color.primary
              : (value < par ? Color.green : Color.orange)
          )

        Button {
          if value < 15 { value += 1 }
        } label: {
          Image(systemName: "plus.circle.fill")
            .font(.title2)
            .foregroundStyle(BrandColors.primary)
        }
        .buttonStyle(.plain)
      }
    }
    .padding(.vertical, 4)
    .padding(.horizontal, 8)
    .padding(.vertical, 6)
    .background(
      isPinkCarrier
        ? Color.pink.opacity(0.12)
        : (strokesOnHole > 0 ? BrandColors.primary.opacity(0.06) : Color.clear)
    )
    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
  }
}

private struct FlowStrokeChips: View {
  let entries: [(String, Int)]

  var body: some View {
    FlexibleChipWrap(entries: entries)
  }
}

/// Simple wrapping chips without a dependency on Layout protocol gymnastics.
private struct FlexibleChipWrap: View {
  let entries: [(String, Int)]

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      ForEach(Array(entries.enumerated()), id: \.offset) { _, entry in
        HStack(spacing: 6) {
          Image(systemName: "circle.fill")
            .font(.system(size: 6))
          Text(entry.1 == 1 ? "\(entry.0) gets a stroke" : "\(entry.0) gets \(entry.1) strokes")
            .font(.caption.weight(.medium))
        }
        .foregroundStyle(BrandColors.primary)
      }
    }
  }
}
