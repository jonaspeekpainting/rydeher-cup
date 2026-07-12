import SwiftUI

struct AdminTabView: View {
  @EnvironmentObject private var sessionManager: SessionManager
  @State private var matches: [TournamentMatch] = []
  @State private var sessions: [TournamentSession] = []
  @State private var profiles: [UserProfile] = []
  @State private var courses: [CourseSummary] = []
  @State private var loadError: String?
  @State private var isLoading = true
  @State private var showCreate = false

  var body: some View {
    Group {
      if isLoading && matches.isEmpty {
        ProgressView()
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else if let loadError, matches.isEmpty {
        ContentUnavailableView(
          "Admin unavailable",
          systemImage: "exclamationmark.triangle",
          description: Text(loadError)
        )
      } else {
        List {
          Section {
            NavigationLink {
              AdminCourseImportView()
            } label: {
              Label("Import course", systemImage: "flag.fill")
            }
            Button {
              showCreate = true
            } label: {
              Label("Create match", systemImage: "plus.circle")
            }
          }

          Section("Matches") {
            if matches.isEmpty {
              Text("No matches yet.")
                .foregroundStyle(.secondary)
            }
            ForEach(matches) { match in
              NavigationLink {
                AdminMatchEditorView(matchId: match.id)
              } label: {
                VStack(alignment: .leading, spacing: 4) {
                  Text(match.label)
                  Text(
                    [
                      match.format?.title,
                      match.status.rawValue,
                      match.scoringVisibility.title,
                    ]
                    .compactMap { $0 }
                    .joined(separator: " · ")
                  )
                  .font(.caption)
                  .foregroundStyle(.secondary)
                }
              }
            }
          }
        }
        .listStyle(.insetGrouped)
      }
    }
    .navigationTitle("Admin")
    .task { await load() }
    .refreshable { await load() }
    .sheet(isPresented: $showCreate) {
      NavigationStack {
        AdminCreateMatchView(
          sessions: sessions,
          profiles: profiles,
          courses: courses
        ) {
          showCreate = false
          Task { await load() }
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
      async let m = ApiClient.shared.fetchMatches(token: token)
      async let s = ApiClient.shared.fetchSessions(token: token)
      async let p = ApiClient.shared.fetchAllProfiles(token: token)
      async let c = ApiClient.shared.listCourses(token: token)
      matches = try await m
      sessions = try await s
      profiles = try await p
      courses = try await c
    } catch {
      loadError = error.localizedDescription
    }
  }
}

struct AdminCreateMatchView: View {
  @EnvironmentObject private var sessionManager: SessionManager
  let sessions: [TournamentSession]
  let profiles: [UserProfile]
  let courses: [CourseSummary]
  let onCreated: () -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var label = ""
  @State private var format: MatchFormat = .bestBallMatch
  @State private var visibility: ScoringVisibility = .releaseOnComplete
  @State private var sessionId: UUID?
  @State private var courseId: UUID?
  @State private var teeId: UUID?
  @State private var hookers: [UUID] = []
  @State private var slicers: [UUID] = []
  @State private var errorMessage: String?
  @State private var isSaving = false

  private var selectedCourse: CourseSummary? {
    courses.first { $0.id == courseId }
  }

  private var maxPlayersPerSide: Int {
    format == .singlesMatch ? 1 : 2
  }

  var body: some View {
    Form {
      Section("Basics") {
        TextField("Label", text: $label)
        Picker("Format", selection: $format) {
          ForEach(MatchFormat.allCases) { item in
            Text(item.title).tag(item)
          }
        }
        Picker("Scoreboard", selection: $visibility) {
          ForEach(ScoringVisibility.allCases, id: \.self) { item in
            Text(item.title).tag(item)
          }
        }
        Picker("Session", selection: $sessionId) {
          Text("None").tag(Optional<UUID>.none)
          ForEach(sessions) { session in
            Text(session.label).tag(Optional(session.id))
          }
        }
      }

      Section("Course") {
        Picker("Course", selection: $courseId) {
          Text("None").tag(Optional<UUID>.none)
          ForEach(courses) { course in
            Text(course.name).tag(Optional(course.id))
          }
        }
        if let tees = selectedCourse?.tees, !tees.isEmpty {
          Picker("Tee", selection: $teeId) {
            Text("None").tag(Optional<UUID>.none)
            ForEach(tees) { tee in
              Text(tee.name).tag(Optional(tee.id))
            }
          }
        }
      }

      Section("Hookers (\(hookers.count)/\(maxPlayersPerSide))") {
        playerPicker(side: .hookers)
      }

      Section("Slicers (\(slicers.count)/\(maxPlayersPerSide))") {
        playerPicker(side: .slicers)
      }

      if let errorMessage {
        Section {
          Text(errorMessage).foregroundStyle(.red).font(.footnote)
        }
      }
    }
    .navigationTitle("New match")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button("Cancel") { dismiss() }
      }
      ToolbarItem(placement: .confirmationAction) {
        Button("Create") {
          Task { await create() }
        }
        .disabled(isSaving || label.trimmingCharacters(in: .whitespaces).isEmpty)
      }
    }
    .onChange(of: format) { _, _ in
      hookers = Array(hookers.prefix(maxPlayersPerSide))
      slicers = Array(slicers.prefix(maxPlayersPerSide))
    }
    .onChange(of: courseId) { _, _ in
      teeId = selectedCourse?.tees?.first?.id
    }
  }

  private enum Side { case hookers, slicers }

  @ViewBuilder
  private func playerPicker(side: Side) -> some View {
    let selected = side == .hookers ? hookers : slicers
    ForEach(profiles) { profile in
      let isOn = selected.contains(profile.id)
      Button {
        toggle(profile.id, side: side)
      } label: {
        HStack {
          Text(profile.displayName)
          Spacer()
          if isOn {
            Image(systemName: "checkmark.circle.fill")
              .foregroundStyle(.tint)
          }
        }
      }
      .foregroundStyle(.primary)
    }
  }

  private func toggle(_ id: UUID, side: Side) {
    switch side {
    case .hookers:
      if let idx = hookers.firstIndex(of: id) {
        hookers.remove(at: idx)
      } else if hookers.count < maxPlayersPerSide {
        hookers.append(id)
        slicers.removeAll { $0 == id }
      }
    case .slicers:
      if let idx = slicers.firstIndex(of: id) {
        slicers.remove(at: idx)
      } else if slicers.count < maxPlayersPerSide {
        slicers.append(id)
        hookers.removeAll { $0 == id }
      }
    }
  }

  private func create() async {
    errorMessage = nil
    isSaving = true
    defer { isSaving = false }
    do {
      let token = try sessionManager.requireToken()
      var players: [[String: Any]] = []
      for id in hookers {
        players.append(["profile_id": id.uuidString, "side": "hookers"])
      }
      for id in slicers {
        players.append(["profile_id": id.uuidString, "side": "slicers"])
      }
      var body: [String: Any] = [
        "label": label.trimmingCharacters(in: .whitespacesAndNewlines),
        "format": format.rawValue,
        "scoring_visibility": visibility.rawValue,
        "players": players,
      ]
      if let sessionId { body["session_id"] = sessionId.uuidString }
      if let courseId { body["course_id"] = courseId.uuidString }
      if let teeId { body["tee_id"] = teeId.uuidString }
      _ = try await ApiClient.shared.createMatch(token: token, body: body)
      onCreated()
      dismiss()
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}

struct AdminMatchEditorView: View {
  @EnvironmentObject private var sessionManager: SessionManager
  let matchId: UUID

  @State private var match: TournamentMatch?
  @State private var visibility: ScoringVisibility = .releaseOnComplete
  @State private var message: String?
  @State private var isWorking = false

  var body: some View {
    Form {
      if let match {
        Section("Match") {
          LabeledContent("Label", value: match.label)
          LabeledContent("Format", value: match.format?.title ?? "—")
          LabeledContent("Status", value: match.status.rawValue)
          Picker("Scoreboard", selection: $visibility) {
            ForEach(ScoringVisibility.allCases, id: \.self) { item in
              Text(item.title).tag(item)
            }
          }
          .onChange(of: visibility) { _, newValue in
            Task { await saveVisibility(newValue) }
          }
        }

        Section("Actions") {
          Button("Start match (snapshot handicaps)") {
            Task { await start() }
          }
          .disabled(match.status == .complete || isWorking)

          Button("Mark complete") {
            Task { await complete() }
          }
          .disabled(match.status == .complete || isWorking)
        }

        if let message {
          Section {
            Text(message).font(.footnote).foregroundStyle(.secondary)
          }
        }
      } else {
        ProgressView()
      }
    }
    .navigationTitle("Edit match")
    .task { await load() }
  }

  private func load() async {
    do {
      let token = try sessionManager.requireToken()
      let loaded = try await ApiClient.shared.fetchMatch(token: token, id: matchId)
      match = loaded
      visibility = loaded.scoringVisibility
    } catch {
      message = error.localizedDescription
    }
  }

  private func saveVisibility(_ value: ScoringVisibility) async {
    isWorking = true
    defer { isWorking = false }
    do {
      let token = try sessionManager.requireToken()
      match = try await ApiClient.shared.updateMatch(
        token: token,
        id: matchId,
        body: ["scoring_visibility": value.rawValue]
      )
      message = "Visibility updated."
    } catch {
      message = error.localizedDescription
    }
  }

  private func start() async {
    isWorking = true
    defer { isWorking = false }
    do {
      let token = try sessionManager.requireToken()
      match = try await ApiClient.shared.startMatch(token: token, id: matchId)
      message = "Match started."
    } catch {
      message = error.localizedDescription
    }
  }

  private func complete() async {
    isWorking = true
    defer { isWorking = false }
    do {
      let token = try sessionManager.requireToken()
      match = try await ApiClient.shared.completeMatch(token: token, id: matchId)
      message = "Match marked complete."
    } catch {
      message = error.localizedDescription
    }
  }
}

struct AdminCourseImportView: View {
  @EnvironmentObject private var sessionManager: SessionManager
  @State private var query = "Boyne"
  @State private var hits: [CourseSearchHit] = []
  @State private var message: String?
  @State private var isSearching = false
  @State private var isImporting = false

  var body: some View {
    List {
      Section {
        HStack {
          TextField("Search courses", text: $query)
            .textInputAutocapitalization(.words)
          Button("Search") {
            Task { await search() }
          }
          .disabled(isSearching || query.trimmingCharacters(in: .whitespaces).isEmpty)
        }
      }

      Section("Results") {
        if hits.isEmpty {
          Text("Search for Boyne courses to import scorecards.")
            .foregroundStyle(.secondary)
        }
        ForEach(hits) { hit in
          Button {
            Task { await importCourse(hit) }
          } label: {
            VStack(alignment: .leading, spacing: 2) {
              Text(hit.name)
              Text([hit.city, hit.state].compactMap { $0 }.joined(separator: ", "))
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
          .disabled(isImporting)
        }
      }

      if let message {
        Section {
          Text(message).font(.footnote)
        }
      }
    }
    .navigationTitle("Import course")
    .task { await search() }
  }

  private func search() async {
    isSearching = true
    defer { isSearching = false }
    do {
      let token = try sessionManager.requireToken()
      hits = try await ApiClient.shared.searchCourses(token: token, query: query)
    } catch {
      message = error.localizedDescription
    }
  }

  private func importCourse(_ hit: CourseSearchHit) async {
    isImporting = true
    defer { isImporting = false }
    do {
      let token = try sessionManager.requireToken()
      let course = try await ApiClient.shared.importCourse(
        token: token,
        externalId: hit.externalId
      )
      message = "Imported \(course.name)."
    } catch {
      message = error.localizedDescription
    }
  }
}
