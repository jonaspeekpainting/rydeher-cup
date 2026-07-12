import SwiftUI

struct ScoreboardTabView: View {
  @EnvironmentObject private var sessionManager: SessionManager
  @State private var standings: CupStandings?
  @State private var loadError: String?
  @State private var isLoading = true

  var body: some View {
    Group {
      if isLoading && standings == nil {
        ProgressView()
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else if let loadError, standings == nil {
        ContentUnavailableView(
          "Could not load scoreboard",
          systemImage: "exclamationmark.triangle",
          description: Text(loadError)
        )
      } else if let standings {
        List {
          Section {
            HStack {
              VStack(alignment: .leading, spacing: 4) {
                Text("Hookers")
                  .font(.headline)
                Text(pointsText(standings.hookersPoints))
                  .font(.largeTitle.weight(.bold))
                  .monospacedDigit()
              }
              Spacer()
              Text("vs")
                .foregroundStyle(.secondary)
              Spacer()
              VStack(alignment: .trailing, spacing: 4) {
                Text("Slicers")
                  .font(.headline)
                Text(pointsText(standings.slicersPoints))
                  .font(.largeTitle.weight(.bold))
                  .monospacedDigit()
              }
            }
            .padding(.vertical, 8)
          }

          ForEach(standings.sessions) { session in
            Section(session.session.label) {
              HStack {
                Text("Session")
                Spacer()
                Text("\(pointsText(session.hookersPoints)) – \(pointsText(session.slicersPoints))")
                  .fontWeight(.semibold)
                  .monospacedDigit()
              }
              ForEach(session.matches) { match in
                NavigationLink {
                  MatchDetailView(matchId: match.id)
                } label: {
                  MatchStandingsRow(match: match)
                }
              }
            }
          }

          if !standings.unassignedMatches.isEmpty {
            Section("Other matches") {
              ForEach(standings.unassignedMatches) { match in
                NavigationLink {
                  MatchDetailView(matchId: match.id)
                } label: {
                  MatchStandingsRow(match: match)
                }
              }
            }
          }
        }
        .listStyle(.insetGrouped)
      } else {
        ContentUnavailableView(
          "Scoreboard",
          systemImage: "flag.checkered",
          description: Text("Cup standings will appear once matches are set.")
        )
      }
    }
    .navigationTitle("Scoreboard")
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

  private func pointsText(_ value: Double) -> String {
    if value == floor(value) {
      return String(Int(value))
    }
    return String(format: "%.1f", value)
  }
}

private struct MatchStandingsRow: View {
  let match: StandingsMatchRow

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(match.label)
        .font(.body.weight(.medium))
      HStack(spacing: 8) {
        if let format = match.format {
          Text(format.title)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        statusBadge
        if match.countsTowardStandings,
           let hp = match.hookersPoints,
           let sp = match.slicersPoints {
          Text("\(formatPoints(hp))–\(formatPoints(sp))")
            .font(.caption.weight(.semibold))
            .monospacedDigit()
        } else if !match.countsTowardStandings, match.status != .complete {
          Text("Hidden until complete")
            .font(.caption)
            .foregroundStyle(.orange)
        }
      }
    }
    .padding(.vertical, 2)
  }

  @ViewBuilder
  private var statusBadge: some View {
    switch match.status {
    case .setup:
      Text("Setup").font(.caption2).foregroundStyle(.secondary)
    case .inProgress:
      Text(match.scoringVisibility == .live ? "Live" : "In progress")
        .font(.caption2.weight(.semibold))
        .foregroundStyle(match.scoringVisibility == .live ? .green : .secondary)
    case .complete:
      Text("Final").font(.caption2.weight(.semibold)).foregroundStyle(.blue)
    }
  }

  private func formatPoints(_ value: Double) -> String {
    value == floor(value) ? String(Int(value)) : String(format: "%.1f", value)
  }
}
