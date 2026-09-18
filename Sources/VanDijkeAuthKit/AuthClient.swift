import Foundation

public actor AuthClient {
    public let configuration: AuthConfiguration

    private let sessionStore: any AuthSessionStore
    private let urlSession: URLSession

    public init(
        configuration: AuthConfiguration,
        sessionStore: any AuthSessionStore,
        urlSession: URLSession = .shared
    ) {
        self.configuration = configuration
        self.sessionStore = sessionStore
        self.urlSession = urlSession
    }

    public var session: AuthSession? {
        sessionStore.load()
    }

    public var token: String? {
        session?.token
    }

    @discardableResult
    public func login(username: String, password: String) async throws -> AuthSession {
        let payload: LoginPayload = try await request(
            "/auth/login",
            method: "POST",
            body: [
                "username": username,
                "password": password,
                "mobile": true,
                "client_id": configuration.clientID,
            ]
        )

        guard !payload.mobileToken.isEmpty else {
            throw AuthError.invalidResponse
        }

        let session = AuthSession(token: payload.mobileToken, user: payload.user)
        sessionStore.save(session)
        return session
    }

    public func logout() async {
        defer { sessionStore.clear() }
        guard let token else { return }

        do {
            let _: EmptyPayload = try await request(
                "/auth/logout",
                method: "POST",
                body: [:],
                token: token
            )
        } catch {
            // Local logout must still succeed if the server is unavailable.
        }
    }

    @discardableResult
    public func register(
        username: String,
        password: String,
        confirmation: String,
        inviteToken: String
    ) async throws -> AuthSession {
        guard password == confirmation else {
            throw AuthError.passwordMismatch
        }

        let payload: LoginPayload = try await request(
            "/auth/register",
            method: "POST",
            body: [
                "username": username,
                "password": password,
                "password_confirm": confirmation,
                "invite_token": inviteToken,
                "client_id": configuration.clientID,
                "mobile": true,
            ]
        )

        guard !payload.mobileToken.isEmpty else {
            throw AuthError.invalidResponse
        }

        let session = AuthSession(token: payload.mobileToken, user: payload.user)
        sessionStore.save(session)
        return session
    }

    @discardableResult
    public func requestPasswordReset(email: String) async throws -> PasswordResetRequestResult {
        try await request(
            "/password-reset/request",
            method: "POST",
            body: [
                "email": email,
                "client_id": configuration.clientID,
            ]
        )
    }

    @discardableResult
    public func resetPassword(
        token: String,
        password: String,
        confirmation: String
    ) async throws -> PasswordResetResult {
        guard password == confirmation else {
            throw AuthError.passwordMismatch
        }

        return try await request(
            "/password-reset/confirm",
            method: "POST",
            body: [
                "token": token,
                "password": password,
                "password_confirm": confirmation,
                "client_id": configuration.clientID,
            ]
        )
    }

    private func request<Value: Decodable>(
        _ path: String,
        method: String = "GET",
        body: [String: Any]? = nil,
        token: String? = nil
    ) async throws -> Value {
        var request = URLRequest(url: configuration.endpoint(path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(configuration.nativeOrigin, forHTTPHeaderField: "Origin")

        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.invalidResponse
        }

        let envelope: APIEnvelope<Value>
        do {
            envelope = try JSONDecoder().decode(APIEnvelope<Value>.self, from: data)
        } catch {
            throw AuthError.server("The account server returned an unreadable response.")
        }

        if httpResponse.statusCode == 401 {
            throw AuthError.unauthorized
        }

        guard httpResponse.statusCode < 400, envelope.ok, let value = envelope.data else {
            throw AuthError.server(envelope.error?.message ?? "The account request failed.")
        }

        return value
    }
}

private struct LoginPayload: Decodable {
    let mobileToken: String
    let user: AuthUser?

    enum CodingKeys: String, CodingKey {
        case mobileToken = "mobile_token"
        case user
    }
}

private struct EmptyPayload: Decodable {}
