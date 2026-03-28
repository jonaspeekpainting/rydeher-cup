import SwiftUI

struct ScoreboardTabView: View {
  var body: some View {
    ContentUnavailableView(
      "Scoreboard",
      systemImage: "flag.checkered",
      description: Text("Live standings will appear here.")
    )
    .navigationTitle("Scoreboard")
  }
}
