import SwiftUI

struct MainTabView: View {
  @EnvironmentObject private var sessionManager: SessionManager
  @State private var showSettings = false

  private var showAdminTab: Bool {
    sessionManager.profile?.isAdmin == true
  }

  var body: some View {
    TabView {
      NavigationStack {
        ScoreboardTabView()
      }
      .tabItem { Label("Scoreboard", systemImage: "list.number") }

      NavigationStack {
        MatchUpsTabView()
      }
      .tabItem { Label("Match Ups", systemImage: "person.2") }

      NavigationStack {
        PlayersTabView()
      }
      .tabItem { Label("Players", systemImage: "person.3") }

      NavigationStack {
        FeedTabView(showSettings: $showSettings)
      }
      .tabItem { Label("Feed", systemImage: "bubble.left.and.bubble.right") }

      if showAdminTab {
        NavigationStack {
          AdminTabView()
        }
        .tabItem { Label("Admin", systemImage: "gearshape.fill") }
      }
    }
    .sheet(isPresented: $showSettings) {
      NavigationStack {
        SettingsView()
      }
    }
  }
}
