import SwiftUI

struct MatchUpsTabView: View {
  var body: some View {
    ContentUnavailableView(
      "Match ups",
      systemImage: "person.line.dotted.person",
      description: Text("Pairings and match details will appear here.")
    )
    .navigationTitle("Match Ups")
  }
}
