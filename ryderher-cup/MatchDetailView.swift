import SwiftUI

struct MatchDetailView: View {
  @EnvironmentObject private var sessionManager: SessionManager
  let matchId: UUID

  @State private var match: TournamentMatch?
  @State private var loadError: String?
  @State private var isLoading = true
  @State private var selectedHole = 1

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
        List {
          Section("Match") {
            LabeledContent("Format", value: match.format?.title ?? "—")
            LabeledContent("Status", value: statusLabel(match))
            LabeledContent("Scoring", value: match.scoringVisibility.title)
            if let result = match.result, match.scoresVisible {
              LabeledContent(
                "Points",
                value: "\(fmt(result.hookersPoints))–\(fmt(result.slicersPoints))"
                  + (result.isProvisional ? " (live)" : "")
              )
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

          if match.canScore {
            Section("Enter scores") {
              NavigationLink {
                ScoreEntryView(matchId: matchId, initialHole: selectedHole)
              } label: {
                Label("Score card", systemImage: "square.and.pencil")
              }
            }
          }

          if match.scoresVisible, let scores = match.holeScores, !scores.isEmpty {
            Section("Hole results") {
              ForEach(1 ... 18, id: \.self) { hole in
                let holeScores = scores.filter { $0.holeNumber == hole }
                if !holeScores.isEmpty {
                  VStack(alignment: .leading, spacing: 4) {
                    Text("Hole \(hole)")
                      .font(.subheadline.weight(.semibold))
                    ForEach(Array(holeScores.enumerated()), id: \.offset) { _, score in
                      Text(scoreLine(score, match: match))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    if let outcome = match.holeOutcomes?.first(where: { $0.holeNumber == hole }) {
                      Text(outcomeText(outcome))
                        .font(.caption.weight(.medium))
                    }
                  }
                  .padding(.vertical, 2)
                }
              }
            }
          } else if !match.scoresVisible {
            Section {
              Text("Hole-by-hole scores are hidden until this match is complete.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
          }
        }
        .listStyle(.insetGrouped)
      }
    }
    .navigationTitle(match?.label ?? "Match")
    .navigationBarTitleDisplayMode(.inline)
    .task { await load() }
    .refreshable { await load() }
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

  private func statusLabel(_ match: TournamentMatch) -> String {
    switch match.status {
    case .setup: return "Setup"
    case .inProgress: return match.scoringVisibility == .live ? "Live" : "In progress"
    case .complete: return "Complete"
    }
  }

  private func scoreLine(_ score: HoleScore, match: TournamentMatch) -> String {
    if let profileId = score.profileId,
       let player = match.players.first(where: { $0.profileId == profileId }) {
      return "\(player.profile.displayName): \(score.grossStrokes)"
    }
    if let side = score.side {
      return "\(side.capitalized): \(score.grossStrokes)"
    }
    return "\(score.grossStrokes)"
  }

  private func outcomeText(_ outcome: MatchHoleOutcome) -> String {
    if let side = outcome.winnerSide {
      return "Won by \(side.capitalized)"
    }
    return "Halved"
  }

  private func fmt(_ value: Double) -> String {
    value == floor(value) ? String(Int(value)) : String(format: "%.1f", value)
  }
}
