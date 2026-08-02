import SwiftUI
import UIKit

struct MainTabView: View {
  @EnvironmentObject private var sessionManager: SessionManager
  @State private var showSettings = false

  private var showAdminTab: Bool {
    sessionManager.profile?.isAdmin == true
  }

  var body: some View {
    TabView {
      NavigationStack {
        ScoreboardTabView(showSettings: $showSettings)
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

      if showAdminTab {
        NavigationStack {
          AdminTabView()
        }
        .tabItem { Label("Admin", systemImage: "gearshape.fill") }
      }
    }
    .tint(BrandColors.primary)
    .toolbarBackground(BrandColors.card, for: .tabBar)
    .toolbarBackground(.visible, for: .tabBar)
    .toolbarColorScheme(.light, for: .tabBar)
    .onAppear { configureTabBarAppearance() }
    .sheet(isPresented: $showSettings) {
      NavigationStack {
        SettingsView()
      }
      .tint(BrandColors.primary)
    }
  }

  /// Keep selected + unselected tab icons on brand primary in light and dark mode.
  private func configureTabBarAppearance() {
    let brand = UIColor(BrandColors.primary)
    let appearance = UITabBarAppearance()
    appearance.configureWithDefaultBackground()

    let item = UITabBarItemAppearance()
    let attributes: [NSAttributedString.Key: Any] = [
      .foregroundColor: brand,
    ]
    item.normal.iconColor = brand
    item.normal.titleTextAttributes = attributes
    item.selected.iconColor = brand
    item.selected.titleTextAttributes = attributes

    appearance.stackedLayoutAppearance = item
    appearance.inlineLayoutAppearance = item
    appearance.compactInlineLayoutAppearance = item

    UITabBar.appearance().standardAppearance = appearance
    UITabBar.appearance().scrollEdgeAppearance = appearance
    UITabBar.appearance().tintColor = brand
    UITabBar.appearance().unselectedItemTintColor = brand
  }
}
