import Foundation

enum ApiClientError: LocalizedError {
  case invalidURL
  case invalidResponse
  case unauthorized
  case server(String)

  var errorDescription: String? {
    switch self {
    case .invalidURL:
      return "Invalid API URL."
    case .invalidResponse:
      return "Unexpected server response."
    case .unauthorized:
      return "Your session expired. Sign in again."
    case .server(let message):
      return message
    }
  }
}

struct ApiErrorBody: Decodable {
  let error: String
}

struct AuthResponse: Decodable {
  let token: String
  let profile: UserProfile
}

final class ApiClient {
  static let shared = ApiClient()

  private let baseURL = AppSecrets.apiBaseURL
  private let decoder = JSONDecoder()

  private init() {}

  func signUp(
    email: String,
    password: String,
    code: String,
    ghinNumber: String,
    handicapIndex: Double?
  ) async throws -> AuthResponse {
    var body: [String: Any] = [
      "email": email,
      "password": password,
      "code": code,
      "ghin_number": ghinNumber,
    ]
    if let handicapIndex {
      body["handicap_index"] = handicapIndex
    }
    return try await request(path: "/api/auth/signup", method: "POST", body: body, token: nil)
  }

  func signIn(email: String, password: String) async throws -> AuthResponse {
    try await request(
      path: "/api/auth/signin",
      method: "POST",
      body: ["email": email, "password": password],
      token: nil
    )
  }

  func fetchProfile(token: String) async throws -> UserProfile {
    try await request(path: "/api/auth/me", method: "GET", token: token)
  }

  func fetchAllProfiles(token: String) async throws -> [UserProfile] {
    try await request(path: "/api/profiles", method: "GET", token: token)
  }

  func patchMyProfile(
    token: String,
    ghinNumber: String?,
    handicapIndex: Double?,
    courseHandicap: Int?,
    refreshGhin: Bool
  ) async throws -> UserProfile {
    var body: [String: Any] = ["refresh_ghin": refreshGhin]
    if let ghinNumber { body["ghin_number"] = ghinNumber }
    if let handicapIndex { body["handicap_index"] = handicapIndex }
    if let courseHandicap { body["course_handicap"] = courseHandicap }
    return try await request(path: "/api/profiles/me", method: "PATCH", body: body, token: token)
  }

  func adminPatchProfile(
    token: String,
    profileId: UUID,
    teamSlug: String?,
    handicapIndex: Double?,
    courseHandicap: Int?
  ) async throws -> UserProfile {
    var body: [String: Any] = [:]
    if let teamSlug { body["team_slug"] = teamSlug }
    if let handicapIndex { body["handicap_index"] = handicapIndex }
    if let courseHandicap { body["course_handicap"] = courseHandicap }
    return try await request(
      path: "/api/profiles/\(profileId.uuidString)",
      method: "PATCH",
      body: body,
      token: token
    )
  }

  func fetchStandings(token: String) async throws -> CupStandings {
    try await request(path: "/api/standings", method: "GET", token: token)
  }

  func fetchSessions(token: String) async throws -> [TournamentSession] {
    try await request(path: "/api/sessions", method: "GET", token: token)
  }

  func fetchMatches(token: String) async throws -> [TournamentMatch] {
    try await request(path: "/api/matches", method: "GET", token: token)
  }

  func fetchMatch(token: String, id: UUID) async throws -> TournamentMatch {
    try await request(path: "/api/matches/\(id.uuidString)", method: "GET", token: token)
  }

  func createMatch(token: String, body: [String: Any]) async throws -> TournamentMatch {
    try await request(path: "/api/matches", method: "POST", body: body, token: token)
  }

  func updateMatch(token: String, id: UUID, body: [String: Any]) async throws -> TournamentMatch {
    try await request(
      path: "/api/matches/\(id.uuidString)",
      method: "PATCH",
      body: body,
      token: token
    )
  }

  func startMatch(token: String, id: UUID) async throws -> TournamentMatch {
    try await request(
      path: "/api/matches/\(id.uuidString)/start",
      method: "POST",
      body: [:],
      token: token
    )
  }

  func completeMatch(token: String, id: UUID) async throws -> TournamentMatch {
    try await request(
      path: "/api/matches/\(id.uuidString)/complete",
      method: "POST",
      body: [:],
      token: token
    )
  }

  func putHoleScore(
    token: String,
    matchId: UUID,
    hole: Int,
    playerScores: [[String: Any]]?,
    sideScores: [[String: Any]]?
  ) async throws -> TournamentMatch {
    var body: [String: Any] = [:]
    if let playerScores { body["player_scores"] = playerScores }
    if let sideScores { body["side_scores"] = sideScores }
    return try await request(
      path: "/api/matches/\(matchId.uuidString)/holes/\(hole)",
      method: "PUT",
      body: body,
      token: token
    )
  }

  func searchCourses(token: String, query: String) async throws -> [CourseSearchHit] {
    let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
    return try await request(
      path: "/api/courses/search?q=\(encoded)",
      method: "GET",
      token: token
    )
  }

  func listCourses(token: String) async throws -> [CourseSummary] {
    try await request(path: "/api/courses", method: "GET", token: token)
  }

  func importCourse(token: String, externalId: String) async throws -> CourseSummary {
    try await request(
      path: "/api/courses",
      method: "POST",
      body: ["external_id": externalId],
      token: token
    )
  }

  func fetchTeams(token: String) async throws -> [TournamentTeam] {
    try await request(path: "/api/teams", method: "GET", token: token)
  }

  private func request<T: Decodable>(
    path: String,
    method: String,
    body: [String: Any]? = nil,
    token: String?
  ) async throws -> T {
    var request = try makeRequest(path: path, method: method, token: token)
    if let body {
      request.httpBody = try JSONSerialization.data(withJSONObject: body)
    }
    return try await perform(request)
  }

  private func makeRequest(path: String, method: String, token: String?) throws -> URLRequest {
    guard let url = URL(string: path, relativeTo: baseURL) else {
      throw ApiClientError.invalidURL
    }

    var request = URLRequest(url: url)
    request.httpMethod = method
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    if let token {
      request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }
    return request
  }

  private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
    let (data, response) = try await URLSession.shared.data(for: request)
    guard let http = response as? HTTPURLResponse else {
      throw ApiClientError.invalidResponse
    }

    if http.statusCode == 401 {
      throw ApiClientError.unauthorized
    }

    if !(200 ... 299).contains(http.statusCode) {
      if let body = try? decoder.decode(ApiErrorBody.self, from: data) {
        throw ApiClientError.server(body.error)
      }
      throw ApiClientError.server("Request failed (\(http.statusCode)).")
    }

    do {
      return try decoder.decode(T.self, from: data)
    } catch {
      throw ApiClientError.invalidResponse
    }
  }
}
