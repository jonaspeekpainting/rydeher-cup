import SwiftUI

struct AdminTabView: View {
  @EnvironmentObject private var sessionManager: SessionManager
  @State private var matches: [TournamentMatch] = []
  @State private var sessions: [TournamentSession] = []
  @State private var profiles: [UserProfile] = []
  @State private var courses: [CourseSummary] = []
  @State private var loadError: String?
  @State private var isLoading = true
  @State private var showSessionSetup = false

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
              showSessionSetup = true
            } label: {
              Label("Set up session matches", systemImage: "person.3.sequence")
            }
          }

          if matches.isEmpty {
            Section("Matches") {
              Text("No matches yet.")
                .foregroundStyle(.secondary)
            }
          } else {
            ForEach(sessions) { session in
              let sessionMatches = matches.filter { $0.sessionId == session.id }
              if !sessionMatches.isEmpty {
                Section(session.label) {
                  ForEach(sessionMatches) { match in
                    matchLink(match)
                  }
                  .onDelete { offsets in
                    deleteMatches(sessionMatches, at: offsets)
                  }
                }
              }
            }

            let unassigned = matches.filter { $0.sessionId == nil }
            if !unassigned.isEmpty {
              Section("Unassigned") {
                ForEach(unassigned) { match in
                  matchLink(match)
                }
                .onDelete { offsets in
                  deleteMatches(unassigned, at: offsets)
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
    .sheet(isPresented: $showSessionSetup) {
      NavigationStack {
        AdminSessionSetupView(
          sessions: sessions,
          profiles: profiles,
          courses: courses,
          existingMatches: matches
        ) {
          showSessionSetup = false
          Task { await load() }
        }
      }
    }
  }

  @ViewBuilder
  private func matchLink(_ match: TournamentMatch) -> some View {
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

  private func deleteMatches(_ source: [TournamentMatch], at offsets: IndexSet) {
    let toDelete = offsets.map { source[$0] }
    matches.removeAll { match in toDelete.contains(where: { $0.id == match.id }) }
    Task {
      do {
        let token = try sessionManager.requireToken()
        for match in toDelete {
          try await ApiClient.shared.deleteMatch(token: token, id: match.id)
        }
      } catch {
        loadError = error.localizedDescription
        await load()
      }
    }
  }
}

// MARK: - Session setup (metadata + N pairings)

private struct PairingDraft: Identifiable {
  let id = UUID()
  var hookers: [UUID] = []
  var slicers: [UUID] = []
}

struct AdminSessionSetupView: View {
  @EnvironmentObject private var sessionManager: SessionManager
  let sessions: [TournamentSession]
  let profiles: [UserProfile]
  let courses: [CourseSummary]
  let existingMatches: [TournamentMatch]
  let onCreated: () -> Void

  @Environment(\.dismiss) private var dismiss

  @State private var step = 0
  @State private var sessionId: UUID?
  @State private var matchCount = 5
  @State private var format: MatchFormat = .bestBallMatch
  @State private var visibility: ScoringVisibility = .releaseOnComplete
  @State private var courseId: UUID?
  @State private var teeId: UUID?
  @State private var pairings: [PairingDraft] = (0..<5).map { _ in PairingDraft() }
  @State private var errorMessage: String?
  @State private var isSaving = false

  private var selectedCourse: CourseSummary? {
    courses.first { $0.id == courseId }
  }

  private var slotsPerSide: Int {
    format == .singlesMatch ? 1 : 2
  }

  private var hookersRoster: [UserProfile] {
    profiles
      .filter { $0.teamSlug == "hookers" }
      .sorted { $0.displayName < $1.displayName }
  }

  private var slicersRoster: [UserProfile] {
    profiles
      .filter { $0.teamSlug == "slicers" }
      .sorted { $0.displayName < $1.displayName }
  }

  private var usedPlayerIds: Set<UUID> {
    Set(pairings.flatMap { $0.hookers + $0.slicers })
  }

  private var sessionAlreadyHasMatches: Bool {
    guard let sessionId else { return false }
    return existingMatches.contains { $0.sessionId == sessionId }
  }

  private var pairingsComplete: Bool {
    pairings.allSatisfy {
      $0.hookers.count == slotsPerSide && $0.slicers.count == slotsPerSide
    }
  }

  var body: some View {
    Form {
      if step == 0 {
        metadataSection
      } else {
        pairingsSection
      }

      if let errorMessage {
        Section {
          Text(errorMessage).foregroundStyle(.red).font(.footnote)
        }
      }
    }
    .navigationTitle(step == 0 ? "Session setup" : "Pairings")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button(step == 0 ? "Cancel" : "Back") {
          if step == 0 {
            dismiss()
          } else {
            step = 0
            errorMessage = nil
          }
        }
      }
      ToolbarItem(placement: .confirmationAction) {
        if step == 0 {
          Button("Next") {
            errorMessage = nil
            if sessionId == nil {
              errorMessage = "Pick a session."
              return
            }
            if sessionAlreadyHasMatches {
              errorMessage = "That session already has matches. Clear them first or pick another session."
              return
            }
            resizePairings()
            step = 1
          }
        } else {
          Button("Create \(matchCount)") {
            Task { await createAll() }
          }
          .disabled(isSaving || !pairingsComplete)
        }
      }
    }
    .onChange(of: matchCount) { _, newValue in
      format = newValue == 10 ? .singlesMatch : .bestBallMatch
      resizePairings()
    }
    .onChange(of: format) { _, _ in
      for i in pairings.indices {
        pairings[i].hookers = Array(pairings[i].hookers.prefix(slotsPerSide))
        pairings[i].slicers = Array(pairings[i].slicers.prefix(slotsPerSide))
      }
    }
    .onChange(of: courseId) { _, _ in
      teeId = selectedCourse?.tees?.first?.id
    }
    .onAppear {
      if sessionId == nil {
        sessionId = sessions.first?.id
      }
      if courseId == nil {
        courseId = courses.first?.id
        teeId = selectedCourse?.tees?.first?.id
      }
    }
  }

  @ViewBuilder
  private var metadataSection: some View {
    Section {
      Text("Set shared details once, then fill \(matchCount) pairings.")
        .font(.footnote)
        .foregroundStyle(.secondary)
    }

    Section("Session") {
      Picker("Round", selection: $sessionId) {
        Text("Select…").tag(Optional<UUID>.none)
        ForEach(sessions) { session in
          let count = existingMatches.filter { $0.sessionId == session.id }.count
          Text(count == 0 ? session.label : "\(session.label) (\(count) set)")
            .tag(Optional(session.id))
        }
      }

      Picker("Matchups", selection: $matchCount) {
        Text("5 (2v2)").tag(5)
        Text("10 (singles)").tag(10)
      }
      .pickerStyle(.segmented)
    }

    Section("Shared match settings") {
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
  }

  @ViewBuilder
  private var pairingsSection: some View {
    Section {
      Text(
        format == .singlesMatch
          ? "Pick 1 Hooker and 1 Slicer per match. Players can only appear once."
          : "Pick 2 Hookers and 2 Slicers per match. Players can only appear once."
      )
      .font(.footnote)
      .foregroundStyle(.secondary)

      let filled = pairings.filter {
        $0.hookers.count == slotsPerSide && $0.slicers.count == slotsPerSide
      }.count
      Text("\(filled)/\(matchCount) pairings set · \(usedPlayerIds.count) players assigned")
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    ForEach(Array(pairings.enumerated()), id: \.element.id) { index, _ in
      Section("Match \(index + 1)") {
        playerSlots(
          title: "Hookers",
          roster: hookersRoster,
          selected: pairingBinding(index, side: .hookers)
        )
        playerSlots(
          title: "Slicers",
          roster: slicersRoster,
          selected: pairingBinding(index, side: .slicers)
        )
      }
    }
  }

  private enum Side { case hookers, slicers }

  private func pairingBinding(_ index: Int, side: Side) -> Binding<[UUID]> {
    Binding(
      get: {
        side == .hookers ? pairings[index].hookers : pairings[index].slicers
      },
      set: { newValue in
        if side == .hookers {
          pairings[index].hookers = newValue
        } else {
          pairings[index].slicers = newValue
        }
      }
    )
  }

  @ViewBuilder
  private func playerSlots(
    title: String,
    roster: [UserProfile],
    selected: Binding<[UUID]>
  ) -> some View {
    ForEach(0..<slotsPerSide, id: \.self) { slot in
      let label = slotsPerSide == 1 ? title : "\(title) \(slot + 1)"
      Picker(label, selection: slotSelection(selected, slot: slot)) {
        Text("Select…").tag(Optional<UUID>.none)
        ForEach(availablePlayers(roster: roster, selected: selected.wrappedValue, slot: slot)) { profile in
          Text(profile.displayName).tag(Optional(profile.id))
        }
      }
    }
  }

  private func slotSelection(_ selected: Binding<[UUID]>, slot: Int) -> Binding<UUID?> {
    Binding(
      get: {
        slot < selected.wrappedValue.count ? selected.wrappedValue[slot] : nil
      },
      set: { newValue in
        var next = selected.wrappedValue
        if let newValue {
          if slot < next.count {
            next[slot] = newValue
          } else {
            next.append(newValue)
          }
        } else if slot < next.count {
          next.remove(at: slot)
        }
        var seen = Set<UUID>()
        selected.wrappedValue = next.filter { seen.insert($0).inserted }.prefix(slotsPerSide).map { $0 }
      }
    )
  }

  private func availablePlayers(
    roster: [UserProfile],
    selected: [UUID],
    slot: Int
  ) -> [UserProfile] {
    let current = slot < selected.count ? selected[slot] : nil
    return roster.filter { profile in
      if profile.id == current { return true }
      return !usedPlayerIds.contains(profile.id)
    }
  }

  private func resizePairings() {
    if pairings.count < matchCount {
      pairings.append(contentsOf: (pairings.count..<matchCount).map { _ in PairingDraft() })
    } else if pairings.count > matchCount {
      pairings = Array(pairings.prefix(matchCount))
    }
    for i in pairings.indices {
      pairings[i].hookers = Array(pairings[i].hookers.prefix(slotsPerSide))
      pairings[i].slicers = Array(pairings[i].slicers.prefix(slotsPerSide))
    }
  }

  private func createAll() async {
    errorMessage = nil
    guard let sessionId else {
      errorMessage = "Pick a session."
      return
    }
    guard pairingsComplete else {
      errorMessage = "Fill every Hookers and Slicers slot."
      return
    }

    isSaving = true
    defer { isSaving = false }

    do {
      let token = try sessionManager.requireToken()
      let matchPayloads: [[String: Any]] = pairings.enumerated().map { index, pairing in
        var players: [[String: Any]] = []
        for id in pairing.hookers {
          players.append(["profile_id": id.uuidString, "side": "hookers"])
        }
        for id in pairing.slicers {
          players.append(["profile_id": id.uuidString, "side": "slicers"])
        }
        return [
          "sort_order": index + 1,
          "players": players,
        ]
      }

      var body: [String: Any] = [
        "session_id": sessionId.uuidString,
        "format": format.rawValue,
        "scoring_visibility": visibility.rawValue,
        "matches": matchPayloads,
      ]
      if let courseId { body["course_id"] = courseId.uuidString }
      if let teeId { body["tee_id"] = teeId.uuidString }

      _ = try await ApiClient.shared.createSessionMatches(token: token, body: body)
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
