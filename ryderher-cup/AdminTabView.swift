import SwiftUI

struct AdminTabView: View {
  var body: some View {
    ContentUnavailableView(
      "Match setup",
      systemImage: "person.3.sequence",
      description: Text("Assign players to matches here. Full tools are coming in a follow-up.")
    )
    .navigationTitle("Admin")
  }
}
