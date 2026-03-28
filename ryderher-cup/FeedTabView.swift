import SwiftUI

struct FeedTabView: View {
  @Binding var showSettings: Bool

  var body: some View {
    ContentUnavailableView(
      "Feed",
      systemImage: "bubble.left.and.bubble.right",
      description: Text("Announcements and activity will appear here.")
    )
    .navigationTitle("Feed")
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button {
          showSettings = true
        } label: {
          Image(systemName: "gearshape")
        }
        .accessibilityLabel("Settings")
      }
    }
  }
}
