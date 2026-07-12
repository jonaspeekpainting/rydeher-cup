import SwiftUI

struct MatchUpsTabView: View {
  @EnvironmentObject private var sessionManager: SessionManager
  @State private var sessions: [TournamentSession] = []
  @State private var matches: [TournamentMatch] = []
  @State private var loadError: String?
  @State private var isLoading = true

  private var unassigned: [TournamentMatch] {
    matches.filter { $0.sessionId == nil }
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
      } else if matches.isEmpty {
        ContentUnavailableView(
          "Match ups",
          systemImage: "person.line.dotted.person",
          description: Text("Pairings will appear once the admin sets matches.")
        )
      } else {
        List {
          ForEach(sessions) { session in
            let sessionMatches = matches.filter { $0.sessionId == session.id }
            if !sessionMatches.isEmpty {
              Section(session.label) {
                ForEach(sessionMatches) { match in
                  NavigationLink {
                    MatchDetailView(matchId: match.id)
                  } label: {
                    MatchUpsRow(match: match)
                  }
                }
              }
            }
          }

          if !unassigned.isEmpty {
            Section("Unscheduled") {
              ForEach(unassigned) { match in
                NavigationLink {
                  MatchDetailView(matchId: match.id)
                } label: {
                  MatchUpsRow(match: match)
                }
              }
            }
          }
        }
        .listStyle(.insetGrouped)
      }
    }
    .navigationTitle("Match Ups")
    .task { await load() }
    .refreshable { await load() }
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

private struct MatchUpsRow: View {
  let match: TournamentMatch

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
        Text(match.scoringVisibility == .live ? "Live" : "Release later")
          .font(.caption2)
          .padding(.horizontal, 6)
          .padding(.vertical, 2)
          .background(
            (match.scoringVisibility == .live ? Color.green : Color.orange)
              .opacity(0.15)
          )
          .clipShape(Capsule())
      }
      Text(pairingSummary)
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(2)
    }
    .padding(.vertical, 2)
  }

  private var pairingSummary: String {
    let hookers = match.players.filter { $0.side == "hookers" }.map(\.profile.displayName)
    let slicers = match.players.filter { $0.side == "slicers" }.map(\.profile.displayName)
    let left = hookers.isEmpty ? "TBD" : hookers.joined(separator: " / ")
    let right = slicers.isEmpty ? "TBD" : slicers.joined(separator: " / ")
    return "\(left) vs \(right)"
  }
}
