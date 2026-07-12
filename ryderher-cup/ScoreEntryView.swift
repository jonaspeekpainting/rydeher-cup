import SwiftUI

struct ScoreEntryView: View {
  @EnvironmentObject private var sessionManager: SessionManager
  let matchId: UUID
  let initialHole: Int

  @State private var match: TournamentMatch?
  @State private var hole = 1
  @State private var playerInputs: [UUID: String] = [:]
  @State private var sideInputs: [String: String] = [:]
  @State private var errorMessage: String?
  @State private var isSaving = false
  @State private var isLoading = true

  var body: some View {
    Group {
      if isLoading && match == nil {
        ProgressView()
      } else if let match {
        Form {
          Section {
            Stepper("Hole \(hole)", value: $hole, in: 1 ... 18)
              .onChange(of: hole) { _, _ in
                hydrateInputs(from: match)
              }
          }

          if match.format?.usesTeamBall == true {
            Section("Team scores") {
              ForEach(["hookers", "slicers"], id: \.self) { side in
                HStack {
                  Text(side.capitalized)
                  Spacer()
                  TextField("Gross", text: binding(forSide: side))
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 64)
                }
              }
            }
          } else {
            Section("Player scores") {
              ForEach(match.players) { player in
                HStack {
                  VStack(alignment: .leading) {
                    Text(player.profile.displayName)
                    Text(player.side?.capitalized ?? "")
                      .font(.caption)
                      .foregroundStyle(.secondary)
                  }
                  Spacer()
                  TextField("Gross", text: binding(forPlayer: player.profileId))
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 64)
                }
              }
            }
          }

          if let errorMessage {
            Section {
              Text(errorMessage)
                .foregroundStyle(.red)
                .font(.footnote)
            }
          }

          Section {
            Button {
              Task { await save(match: match) }
            } label: {
              if isSaving {
                ProgressView().frame(maxWidth: .infinity)
              } else {
                Text("Save hole \(hole)").frame(maxWidth: .infinity)
              }
            }
            .disabled(isSaving || !match.canScore)
          }
        }
      } else {
        ContentUnavailableView("Match unavailable", systemImage: "flag.slash")
      }
    }
    .navigationTitle("Score entry")
    .navigationBarTitleDisplayMode(.inline)
    .task {
      hole = initialHole
      await load()
    }
  }

  private func binding(forPlayer id: UUID) -> Binding<String> {
    Binding(
      get: { playerInputs[id] ?? "" },
      set: { playerInputs[id] = $0 }
    )
  }

  private func binding(forSide side: String) -> Binding<String> {
    Binding(
      get: { sideInputs[side] ?? "" },
      set: { sideInputs[side] = $0 }
    )
  }

  private func load() async {
    isLoading = true
    defer { isLoading = false }
    do {
      let token = try sessionManager.requireToken()
      let loaded = try await ApiClient.shared.fetchMatch(token: token, id: matchId)
      match = loaded
      hydrateInputs(from: loaded)
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  private func hydrateInputs(from match: TournamentMatch) {
    playerInputs = [:]
    sideInputs = [:]
    guard let scores = match.holeScores else { return }
    for score in scores where score.holeNumber == hole {
      if let profileId = score.profileId {
        playerInputs[profileId] = String(score.grossStrokes)
      }
      if let side = score.side {
        sideInputs[side] = String(score.grossStrokes)
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
      if match.format?.usesTeamBall == true {
        var sideScores: [[String: Any]] = []
        for side in ["hookers", "slicers"] {
          guard let text = sideInputs[side], let value = Int(text) else { continue }
          sideScores.append(["side": side, "gross_strokes": value])
        }
        guard !sideScores.isEmpty else {
          errorMessage = "Enter at least one team score."
          return
        }
        updated = try await ApiClient.shared.putHoleScore(
          token: token,
          matchId: matchId,
          hole: hole,
          playerScores: nil,
          sideScores: sideScores
        )
      } else {
        var playerScores: [[String: Any]] = []
        for player in match.players {
          guard let text = playerInputs[player.profileId], let value = Int(text) else {
            continue
          }
          playerScores.append([
            "profile_id": player.profileId.uuidString,
            "gross_strokes": value,
          ])
        }
        guard !playerScores.isEmpty else {
          errorMessage = "Enter at least one player score."
          return
        }
        updated = try await ApiClient.shared.putHoleScore(
          token: token,
          matchId: matchId,
          hole: hole,
          playerScores: playerScores,
          sideScores: nil
        )
      }
      self.match = updated
      hydrateInputs(from: updated)
      if hole < 18 {
        hole += 1
        hydrateInputs(from: updated)
      }
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}
