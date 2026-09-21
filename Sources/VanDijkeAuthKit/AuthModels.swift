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
    public let refreshToken: String?
    public let accessTokenExpiresAt: Int?
    public let deviceID: String?
    public let user: AuthUser?

    public init(
        token: String,
        refreshToken: String? = nil,
        accessTokenExpiresAt: Int? = nil,
        deviceID: String? = nil,
        user: AuthUser? = nil
    ) {
        self.token = token
        self.refreshToken = refreshToken
        self.accessTokenExpiresAt = accessTokenExpiresAt
        self.deviceID = deviceID
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

public struct PasskeyStatus: Decodable, Equatable, Sendable {
    public let enabled: Bool
    public let count: Int
}

public struct PasskeyInfo: Decodable, Equatable, Identifiable, Sendable {
    public let id: Int
    public let name: String
    public let aaguid: String?
    public let deviceType: String?
    public let backedUp: Bool
    public let createdAt: String?
    public let lastUsedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, name, aaguid
        case deviceType = "device_type"
        case backedUp = "backed_up"
        case createdAt = "created_at"
        case lastUsedAt = "last_used_at"
    }
}

public struct MobileSessionInfo: Decodable, Equatable, Identifiable, Sendable {
    public let id: String
    public let clientID: String
    public let deviceID: String?
    public let createdAt: String?
    public let lastUsedAt: String?
    public let isCurrent: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case clientID = "client_id"
        case deviceID = "device_id"
        case createdAt = "created_at"
        case lastUsedAt = "last_used_at"
        case isCurrent = "is_current"
    }
}

public struct PasswordResetLink: Equatable, Sendable {
    public let token: String
    public let clientID: String?

    public init?(url: URL, configuration: AuthConfiguration) {
        guard url.scheme?.lowercased() == "https",
              url.host?.lowercased() == configuration.resetLinkHost.lowercased(),
              url.path == configuration.resetLinkPath else {
            return nil
        }

        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        guard let token = queryItems.first(where: { $0.name == "token" })?.value,
              !token.isEmpty else {
            return nil
        }

        if let clientID = queryItems.first(where: { $0.name == "client_id" })?.value,
           clientID != configuration.clientID {
            return nil
        }

        self.token = token
        self.clientID = queryItems.first(where: { $0.name == "client_id" })?.value
    }
}

public struct AccountInviteLink: Equatable, Sendable {
    public let token: String
    public let clientID: String

    public init?(url: URL, configuration: AuthConfiguration) {
        guard url.scheme?.lowercased() == "https",
              url.host?.lowercased() == configuration.resetLinkHost.lowercased(),
              url.path == configuration.inviteLinkPath else {
            return nil
        }

        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        guard let token = queryItems.first(where: { $0.name == "token" })?.value,
              !token.isEmpty,
              let clientID = queryItems.first(where: { $0.name == "client_id" })?.value,
              clientID == configuration.clientID else {
            return nil
        }

        self.token = token
        self.clientID = clientID
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
    case passkeyRequired

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
        case .passkeyRequired:
            return "This admin account must sign in with a passkey."
        }
    }
}
