import Foundation

struct MoodleClient {
    let baseURL: String
    var token: String

    init(baseURL: String, token: String) {
        self.baseURL = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.token = token
    }

    static func authenticate(baseURL: String, username: String, password: String) async throws -> String {
        let trimmedURL = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let url = URL(string: "\(trimmedURL)/login/token.php")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = "username=\(urlEncode(username))&password=\(urlEncode(password))&service=moodle_mobile_app"
        request.httpBody = Data(body.utf8)

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(TokenResponse.self, from: data)

        if let token = response.token {
            return token
        }

        let errorMsg = response.error ?? "Unknown authentication error"
        throw MoodleClientError.authFailed(errorMsg)
    }

    func getSiteInfo() async throws -> SiteInfo {
        return try await callFunction("core_webservice_get_site_info")
    }

    func getCourses(userId: Int) async throws -> [MoodleCourse] {
        return try await callFunction("core_enrol_get_users_courses", params: ["userid": "\(userId)"])
    }

    func getAssignments(courseIds: [Int]) async throws -> AssignmentsResponse {
        var params: [String: String] = [:]
        for (i, id) in courseIds.enumerated() {
            params["courseids[\(i)]"] = "\(id)"
        }
        return try await callFunction("mod_assign_get_assignments", params: params)
    }

    private func callFunction<T: Decodable>(_ function: String, params: [String: String] = [:]) async throws -> T {
        var components = URLComponents(string: "\(baseURL)/webservice/rest/server.php")!
        var queryItems = [
            URLQueryItem(name: "wstoken", value: token),
            URLQueryItem(name: "wsfunction", value: function),
            URLQueryItem(name: "moodlewsrestformat", value: "json"),
        ]
        for (key, value) in params {
            queryItems.append(URLQueryItem(name: key, value: value))
        }
        components.queryItems = queryItems

        let (data, _) = try await URLSession.shared.data(from: components.url!)

        // Check for Moodle error response
        if let errorResponse = try? JSONDecoder().decode(MoodleError.self, from: data),
           errorResponse.errorcode != nil {
            if errorResponse.errorcode == "invalidtoken" {
                throw MoodleClientError.tokenExpired
            }
            throw MoodleClientError.apiError(errorResponse.message ?? "Unknown API error")
        }

        return try JSONDecoder().decode(T.self, from: data)
    }

    private static func urlEncode(_ string: String) -> String {
        return string.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? string
    }
}

enum MoodleClientError: LocalizedError {
    case authFailed(String)
    case tokenExpired
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .authFailed(let msg):
            return "Authentication failed: \(msg)"
        case .tokenExpired:
            return "Token expired, re-authentication required"
        case .apiError(let msg):
            return "Moodle API error: \(msg)"
        }
    }
}
