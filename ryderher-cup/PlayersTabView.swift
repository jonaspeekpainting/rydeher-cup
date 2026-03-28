import SwiftUI

struct PlayersTabView: View {
  @EnvironmentObject private var sessionManager: SessionManager
  @State private var players: [UserProfile] = []
  @State private var searchText = ""
  @State private var loadError: String?
  @State private var isLoading = true

  private var filteredPlayers: [UserProfile] {
    let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if q.isEmpty { return players }
    return players.filter {
      $0.displayName.lowercased().contains(q) || $0.email.lowercased().contains(q)
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
        List(filteredPlayers) { player in
          VStack(alignment: .leading, spacing: 4) {
            Text(player.displayName)
              .font(.headline)
            Text(player.email)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          .padding(.vertical, 4)
        }
        .listStyle(.insetGrouped)
      }
    }
    .navigationTitle("Players")
    .searchable(text: $searchText, prompt: "Search players")
    .task {
      await load()
    }
    .refreshable {
      await load()
    }
  }

  private func load() async {
    isLoading = true
    loadError = nil
    defer { isLoading = false }
    do {
      players = try await sessionManager.fetchAllProfiles()
    } catch {
      loadError = error.localizedDescription
    }
  }
}
