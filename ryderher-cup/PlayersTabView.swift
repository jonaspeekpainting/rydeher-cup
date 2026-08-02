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

  private var isSearching: Bool {
    !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  var body: some View {
    Group {
      if isLoading {
        ProgressView()
          .tint(BrandColors.primary)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else if let loadError {
        ContentUnavailableView(
          "Could not load players",
          systemImage: "exclamationmark.triangle",
          description: Text(loadError)
        )
      } else {
        ScrollView {
          VStack(alignment: .leading, spacing: 22) {
            if isSearching {
              searchResults
            } else {
              rosterSections
            }
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 12)
        }
        .background(BrandScreenBackground())
      }
    }
    .navigationTitle("Players")
    .toolbarBackground(BrandColors.canvas, for: .navigationBar)
    .searchable(text: $searchText, prompt: "Search players")
    .task { await load() }
    .refreshable { await load() }
  }

  @ViewBuilder
  private var rosterSections: some View {
    if !teams.isEmpty {
      ForEach(teams) { team in
        TeamRosterSection(team: team)
      }
    } else {
      BrandSectionHeader(title: "Signed-in players")
      ForEach(filteredPlayers) { player in
        BrandCard(padding: 14) {
          PlayerRowContent(player: player, showTeamBadge: true)
        }
      }
    }
  }

  @ViewBuilder
  private var searchResults: some View {
    BrandSectionHeader(
      title: "Results",
      subtitle: "\(filteredPlayers.count) player\(filteredPlayers.count == 1 ? "" : "s")"
    )
    if filteredPlayers.isEmpty {
      BrandCard {
        Text("No players match that search.")
          .foregroundStyle(BrandColors.inkMuted)
      }
    } else {
      ForEach(filteredPlayers) { player in
        BrandCard(padding: 14) {
          PlayerRowContent(player: player, showTeamBadge: true)
        }
      }
    }
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

private struct TeamRosterSection: View {
  let team: TournamentTeam

  private var signedUpCount: Int {
    team.roster.filter { $0.profile != nil }.count
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .bottom) {
        VStack(alignment: .leading, spacing: 4) {
          Text(team.name)
            .font(.system(.title3, design: .serif).weight(.semibold))
            .foregroundStyle(BrandColors.onPrimary)
          Text("\(signedUpCount)/\(team.roster.count) signed up")
            .font(.caption)
            .foregroundStyle(BrandColors.onPrimary.opacity(0.72))
        }
        Spacer()
        Image(systemName: "flag.fill")
          .foregroundStyle(BrandColors.onPrimary.opacity(0.55))
      }
      .padding(16)
      .background(
        LinearGradient(
          colors: [
            BrandColors.team(team.slug),
            BrandColors.team(team.slug).opacity(0.82),
          ],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      )
      .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
      .shadow(color: BrandColors.team(team.slug).opacity(0.35), radius: 10, y: 5)

      VStack(spacing: 8) {
        ForEach(team.roster) { entry in
          BrandCard(padding: 14) {
            RosterEntryRow(entry: entry, teamSlug: team.slug)
          }
        }
      }
    }
  }
}

private struct RosterEntryRow: View {
  let entry: TeamRosterEntry
  let teamSlug: String

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Circle()
        .fill(BrandColors.team(teamSlug).opacity(0.14))
        .frame(width: 40, height: 40)
        .overlay {
          Text(initials(entry.displayName))
            .font(.caption.weight(.bold))
            .foregroundStyle(BrandColors.team(teamSlug))
        }

      VStack(alignment: .leading, spacing: 4) {
        Text(entry.displayName)
          .font(.body.weight(.semibold))
          .foregroundStyle(BrandColors.ink)

        if let profile = entry.profile {
          handicapLine(profile)
          Text(profile.email)
            .font(.caption)
            .foregroundStyle(BrandColors.inkMuted)
        } else {
          Text("Not signed up yet")
            .font(.caption.weight(.medium))
            .foregroundStyle(BrandColors.primarySoft)
        }
      }
      Spacer(minLength: 0)
    }
  }

  @ViewBuilder
  private func handicapLine(_ player: UserProfile) -> some View {
    HStack(spacing: 8) {
      if let index = player.handicapIndex {
        MetaChip(text: "Index \(formatIndex(index))")
      }
      if let ch = player.courseHandicap {
        MetaChip(text: "CH \(ch)")
      }
    }
  }

  private func initials(_ name: String) -> String {
    let parts = name.split(separator: " ")
    let letters = parts.prefix(2).compactMap { $0.first.map(String.init) }
    return letters.joined().uppercased()
  }

  private func formatIndex(_ value: Double) -> String {
    value == floor(value) ? String(Int(value)) : String(format: "%.1f", value)
  }
}

private struct PlayerRowContent: View {
  let player: UserProfile
  var showTeamBadge: Bool = false

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Circle()
        .fill(BrandColors.team(player.teamSlug).opacity(0.14))
        .frame(width: 40, height: 40)
        .overlay {
          Text(initials(player.displayName))
            .font(.caption.weight(.bold))
            .foregroundStyle(BrandColors.team(player.teamSlug))
        }

      VStack(alignment: .leading, spacing: 4) {
        HStack(spacing: 8) {
          Text(player.displayName)
            .font(.body.weight(.semibold))
            .foregroundStyle(BrandColors.ink)
          if showTeamBadge, let team = player.teamLabel {
            Text(team)
              .font(.caption2.weight(.bold))
              .foregroundStyle(BrandColors.onPrimary)
              .padding(.horizontal, 8)
              .padding(.vertical, 3)
              .background(BrandColors.team(player.teamSlug))
              .clipShape(Capsule())
          }
        }
        HStack(spacing: 8) {
          if let index = player.handicapIndex {
            MetaChip(text: "Index \(formatIndex(index))")
          }
          if let ch = player.courseHandicap {
            MetaChip(text: "CH \(ch)")
          }
        }
        Text(player.email)
          .font(.caption)
          .foregroundStyle(BrandColors.inkMuted)
      }
      Spacer(minLength: 0)
    }
  }

  private func initials(_ name: String) -> String {
    let parts = name.split(separator: " ")
    let letters = parts.prefix(2).compactMap { $0.first.map(String.init) }
    return letters.joined().uppercased()
  }

  private func formatIndex(_ value: Double) -> String {
    value == floor(value) ? String(Int(value)) : String(format: "%.1f", value)
  }
}

private struct MetaChip: View {
  let text: String

  var body: some View {
    Text(text)
      .font(.caption2.weight(.semibold))
      .foregroundStyle(BrandColors.primary)
      .padding(.horizontal, 8)
      .padding(.vertical, 3)
      .background(BrandColors.primary.opacity(0.08))
      .clipShape(Capsule())
  }
}
