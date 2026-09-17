import Foundation

public struct AuthUser: Codable, Equatable, Sendable {
    public let id: Int?
    public let username: String?
    public let email: String?
    public let firstName: String?
    public let lastName: String?

    public init(
        id: Int?,
        username: String?,
        email: String? = nil,
        firstName: String? = nil,
        lastName: String? = nil
    ) {
        self.id = id
        self.username = username
        self.email = email
        self.firstName = firstName
        self.lastName = lastName
    }

    enum CodingKeys: String, CodingKey {
        case id, username, email
        case firstName = "first_name"
        case lastName = "last_name"
    }
}

public struct AuthSession: Codable, Equatable, Sendable {
    public let token: String
    public let user: AuthUser?

    public init(token: String, user: AuthUser? = nil) {
        self.token = token
        self.user = user
    }
}

public struct PasswordResetRequestResult: Decodable, Equatable, Sendable {
    public let sent: Bool
    public let message: String?
}

public struct PasswordResetResult: Decodable, Equatable, Sendable {
    public let reset: Bool
}

public struct PasswordResetLink: Equatable, Sendable {
    public let token: String
    public let clientID: String?

    public init?(url: URL, configuration: AuthConfiguration) {
        guard url.scheme?.lowercased() == "https",
              url.host?.lowercased() == configuration.resetLinkHost.lowercased(),
              url.pathComponents.contains("reset") else {
            return nil
        }

        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        guard let token = queryItems.first(where: { $0.name == "token" })?.value,
              !token.isEmpty else {
            return nil
        }

        self.token = token
        self.clientID = queryItems.first(where: { $0.name == "client_id" })?.value
    }
}

struct APIEnvelope<Value: Decodable>: Decodable {
    struct APIError: Decodable {
        let code: String?
        let message: String?
    }

    let ok: Bool
    let data: Value?
    let error: APIError?
}

public enum AuthError: LocalizedError, Equatable, Sendable {
    case invalidResponse
    case unauthorized
    case server(String)
    case passwordMismatch
    case invalidResetLink

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The account server returned an invalid response."
        case .unauthorized:
            return "Your session has expired. Please sign in again."
        case .server(let message):
            return message
        case .passwordMismatch:
            return "The passwords do not match."
        case .invalidResetLink:
            return "This password-reset link is invalid or has expired."
        }
    }
}
