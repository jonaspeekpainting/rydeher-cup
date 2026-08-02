import SwiftUI

/// Standalone score entry kept for deep links; live matches use MatchDetailView.
struct ScoreEntryView: View {
  let matchId: UUID
  let initialHole: Int

  var body: some View {
    MatchDetailView(matchId: matchId)
  }
}
