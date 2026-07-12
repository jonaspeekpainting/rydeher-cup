import SwiftUI

struct PlayersTabView: View {
  @EnvironmentObject private var sessionManager: SessionManager
  @State private var teams: [TournamentTeam] = []
  @State private var players: [UserProfile] = []
  @State private var searchText = ""
  @State private var loadError: String?
  @State private var isLoading = true

  private var filteredPlayers: [UserProfile] {
    let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if q.isEmpty { return players }
    return players.filter {
      $0.displayName.lowercased().contains(q)
        || $0.email.lowercased().contains(q)
        || ($0.teamLabel?.lowercased().contains(q) ?? false)
    }
  }

  var body: some View {
    Group {
      if isLoading {
        ProgressView()
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else if let loadError {
        ContentUnavailableView(
          "Could not load players",
          systemImage: "exclamationmark.triangle",
          description: Text(loadError)
        )
      } else {
        List {
          if !teams.isEmpty {
            ForEach(teams) { team in
              Section(team.name) {
                ForEach(team.roster) { entry in
                  VStack(alignment: .leading, spacing: 4) {
                    Text(entry.displayName)
                      .font(.headline)
                    if let profile = entry.profile {
                      handicapLine(profile)
                      Text(profile.email)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    } else {
                      Text("Not signed up yet")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    }
                  }
                  .padding(.vertical, 2)
                }
              }
            }
          }

          Section("Signed-in players") {
            ForEach(filteredPlayers) { player in
              VStack(alignment: .leading, spacing: 4) {
                HStack {
                  Text(player.displayName)
                    .font(.headline)
                  if let team = player.teamLabel {
                    Text(team)
                      .font(.caption2.weight(.semibold))
                      .padding(.horizontal, 6)
                      .padding(.vertical, 2)
                      .background(Color.secondary.opacity(0.15))
                      .clipShape(Capsule())
                  }
                }
                handicapLine(player)
                Text(player.email)
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
              .padding(.vertical, 2)
            }
          }
        }
        .listStyle(.insetGrouped)
      }
    }
    .navigationTitle("Players")
    .searchable(text: $searchText, prompt: "Search players")
    .task { await load() }
    .refreshable { await load() }
  }

  @ViewBuilder
  private func handicapLine(_ player: UserProfile) -> some View {
    HStack(spacing: 8) {
      if let index = player.handicapIndex {
        Text("Index \(formatIndex(index))")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      if let ch = player.courseHandicap {
        Text("CH \(ch)")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      if let ghin = player.ghinNumber {
        Text("GHIN \(ghin)")
          .font(.caption2)
          .foregroundStyle(.tertiary)
      }
    }
  }

  private func formatIndex(_ value: Double) -> String {
    value == floor(value) ? String(Int(value)) : String(format: "%.1f", value)
  }

  private func load() async {
    isLoading = true
    loadError = nil
    defer { isLoading = false }
    do {
      let token = try sessionManager.requireToken()
      async let teamsTask = ApiClient.shared.fetchTeams(token: token)
      async let playersTask = sessionManager.fetchAllProfiles()
      teams = try await teamsTask
      players = try await playersTask
    } catch {
      loadError = error.localizedDescription
    }
  }
}
