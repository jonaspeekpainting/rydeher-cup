//
//  ryderher_cupApp.swift
//  ryderher-cup
//
//  Created by Jonas Peek on 3/28/26.
//

import SwiftUI

@main
struct ryderher_cupApp: App {
  @StateObject private var sessionManager = SessionManager()

  var body: some Scene {
    WindowGroup {
      AppRootView()
        .environmentObject(sessionManager)
    }
  }
}
