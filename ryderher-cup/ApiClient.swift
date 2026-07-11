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
  private let decoder: JSONDecoder = {
    let decoder = JSONDecoder()
    return decoder
  }()

  private init() {}

  func signUp(email: String, password: String, code: String) async throws -> AuthResponse {
    try await post(
      path: "/api/auth/signup",
      body: ["email": email, "password": password, "code": code],
      authorized: false
    )
  }

  func signIn(email: String, password: String) async throws -> AuthResponse {
    try await post(
      path: "/api/auth/signin",
      body: ["email": email, "password": password],
      authorized: false
    )
  }

  func fetchProfile(token: String) async throws -> UserProfile {
    try await get(path: "/api/auth/me", token: token)
  }

  func fetchAllProfiles(token: String) async throws -> [UserProfile] {
    try await get(path: "/api/profiles", token: token)
  }

  private func get<T: Decodable>(path: String, token: String) async throws -> T {
    let request = try makeRequest(path: path, method: "GET", token: token)
    return try await perform(request)
  }

  private func post<T: Decodable>(
    path: String,
    body: [String: String],
    authorized: Bool,
    token: String? = nil
  ) async throws -> T {
    var request = try makeRequest(
      path: path,
      method: "POST",
      token: authorized ? token : nil
    )
    request.httpBody = try JSONSerialization.data(withJSONObject: body)
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
