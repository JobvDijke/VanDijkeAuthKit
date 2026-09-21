import Foundation
#if os(iOS)
import AuthenticationServices
#endif

public actor AuthClient {
    public let configuration: AuthConfiguration

    private let sessionStore: any AuthSessionStore
    private let urlSession: URLSession
    #if os(iOS)
    private let passkeyURLSession: URLSession
    #endif

    public init(
        configuration: AuthConfiguration,
        sessionStore: any AuthSessionStore,
        urlSession: URLSession? = nil
    ) {
        self.configuration = configuration
        self.sessionStore = sessionStore
        if let urlSession {
            self.urlSession = urlSession
        } else {
            let sessionConfiguration = URLSessionConfiguration.ephemeral
            sessionConfiguration.httpShouldSetCookies = false
            sessionConfiguration.httpShouldHandleCookies = false
            sessionConfiguration.urlCache = nil
            self.urlSession = URLSession(configuration: sessionConfiguration)
        }
        #if os(iOS)
        let passkeySessionConfiguration = URLSessionConfiguration.ephemeral
        passkeySessionConfiguration.urlCache = nil
        self.passkeyURLSession = URLSession(configuration: passkeySessionConfiguration)
        #endif
    }

    public var session: AuthSession? {
        sessionStore.load()
    }

    public var token: String? {
        session?.token
    }

    public func validToken() async -> String? {
        guard let currentSession = session else { return nil }

        guard let expiresAt = currentSession.accessTokenExpiresAt else {
            return currentSession.token
        }

        let refreshMargin = 60
        let now = Int(Date().timeIntervalSince1970)
        guard expiresAt <= now + refreshMargin else {
            return currentSession.token
        }

        guard let refreshToken = currentSession.refreshToken,
              let deviceID = currentSession.deviceID else {
            sessionStore.clear()
            return nil
        }

        do {
            let payload: LoginPayload = try await request(
                "/auth/refresh",
                method: "POST",
                body: [
                    "refresh_token": refreshToken,
                    "client_id": configuration.clientID,
                    "device_id": deviceID,
                    "mobile": true,
                ]
            )

            guard !payload.mobileToken.isEmpty,
                  let newRefreshToken = payload.mobileRefreshToken,
                  let newExpiresAt = payload.mobileTokenExpiresAt else {
                throw AuthError.invalidResponse
            }

            let refreshedSession = AuthSession(
                token: payload.mobileToken,
                refreshToken: newRefreshToken,
                accessTokenExpiresAt: newExpiresAt,
                deviceID: deviceID,
                user: currentSession.user ?? payload.user
            )
            sessionStore.save(refreshedSession)
            return refreshedSession.token
        } catch {
            sessionStore.clear()
            return nil
        }
    }

    @discardableResult
    public func login(username: String, password: String) async throws -> AuthSession {
        let deviceID = UUID().uuidString
        let payload: LoginPayload = try await request(
            "/auth/login",
            method: "POST",
            body: [
                "username": username,
                "password": password,
                "mobile": true,
                "client_id": configuration.clientID,
                "device_id": deviceID,
            ]
        )

        guard !payload.mobileToken.isEmpty else {
            throw AuthError.invalidResponse
        }

        let session = makeSession(from: payload, deviceID: deviceID)
        sessionStore.save(session)
        return session
    }

    public func logout() async {
        defer { sessionStore.clear() }
        guard let token = await validToken() else { return }

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

    #if os(iOS)
    public func passkeyStatus() async throws -> PasskeyStatus {
        guard let token = await validToken() else {
            throw AuthError.unauthorized
        }
        let payload: MePayload = try await request("/me", token: token)
        return payload.passkey
    }

    public func listPasskeys() async throws -> [PasskeyInfo] {
        guard let token = await validToken() else {
            throw AuthError.unauthorized
        }
        let payload: PasskeyListPayload = try await request("/auth/passkeys", token: token)
        return payload.passkeys
    }

    public func revokePasskey(id: Int) async throws -> [PasskeyInfo] {
        guard let token = await validToken() else {
            throw AuthError.unauthorized
        }
        let payload: PasskeyListPayload = try await request(
            "/auth/passkeys/\(id)",
            method: "DELETE",
            token: token
        )
        return payload.passkeys
    }

    public func registerPasskey() async throws -> PasskeyStatus {
        guard configuration.passkeysEnabled else {
            throw AuthError.server("Passkeys are not enabled for this app.")
        }
        guard let token = await validToken() else {
            throw AuthError.unauthorized
        }

        let optionsPayload: PasskeyOptionsPayload = try await request(
            "/auth/passkeys/register/options",
            method: "POST",
            token: token,
            using: passkeyURLSession
        )
        let credential = try await PasskeyAuthorization.register(options: optionsPayload.options)
        let response: PasskeyStatusPayload = try await request(
            "/auth/passkeys/register/verify",
            method: "POST",
            body: ["credential": credential.registrationBody],
            token: token,
            using: passkeyURLSession
        )
        return response.passkey
    }

    public func loginWithPasskey(username: String? = nil) async throws -> AuthSession {
        guard configuration.passkeysEnabled else {
            throw AuthError.server("Passkeys are not enabled for this app.")
        }

        let deviceID = UUID().uuidString
        var optionsBody: [String: Any] = [
            "mobile": true,
            "client_id": configuration.clientID,
            "device_id": deviceID,
        ]
        if let username, !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            optionsBody["username"] = username.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let optionsPayload: PasskeyOptionsPayload = try await request(
            "/auth/passkeys/login/options",
            method: "POST",
            body: optionsBody,
            using: passkeyURLSession
        )
        let credential = try await PasskeyAuthorization.assert(options: optionsPayload.options)
        let payload: LoginPayload = try await request(
            "/auth/passkeys/login/verify",
            method: "POST",
            body: [
                "credential": credential.assertionBody,
                "mobile": true,
                "client_id": configuration.clientID,
                "device_id": deviceID,
            ],
            using: passkeyURLSession
        )

        guard !payload.mobileToken.isEmpty else {
            throw AuthError.invalidResponse
        }
        let session = makeSession(from: payload, deviceID: deviceID)
        sessionStore.save(session)
        return session
    }
    #endif

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

        let deviceID = UUID().uuidString
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
                "device_id": deviceID,
            ]
        )

        guard !payload.mobileToken.isEmpty else {
            throw AuthError.invalidResponse
        }

        let session = makeSession(from: payload, deviceID: deviceID)
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
        token: String? = nil,
        using session: URLSession? = nil
    ) async throws -> Value {
        var request = URLRequest(url: configuration.endpoint(path))
        request.httpMethod = method
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(configuration.nativeOrigin, forHTTPHeaderField: "Origin")
        request.setValue(configuration.clientID, forHTTPHeaderField: "X-Client-ID")

        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await (session ?? urlSession).data(for: request)
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

        if httpResponse.statusCode == 403, envelope.error?.code == "passkey_required" {
            throw AuthError.passkeyRequired
        }

        guard httpResponse.statusCode < 400, envelope.ok, let value = envelope.data else {
            throw AuthError.server(envelope.error?.message ?? "The account request failed.")
        }

        return value
    }

    private func makeSession(from payload: LoginPayload, deviceID: String) -> AuthSession {
        AuthSession(
            token: payload.mobileToken,
            refreshToken: payload.mobileRefreshToken,
            accessTokenExpiresAt: payload.mobileTokenExpiresAt,
            deviceID: deviceID,
            user: payload.user
        )
    }
}

private struct PasskeyStatusPayload: Decodable {
    let passkey: PasskeyStatus
}

private struct PasskeyListPayload: Decodable {
    let passkeys: [PasskeyInfo]
}

private struct PasskeyOptionsPayload: Decodable {
    let options: PasskeyOptions
}

struct PasskeyOptions: Decodable, Sendable {
    struct RelyingParty: Decodable, Sendable {
        let id: String
    }

    struct User: Decodable, Sendable {
        let id: String
        let name: String
    }

    struct CredentialDescriptor: Decodable, Sendable {
        let id: String
    }

    let challenge: String
    let rp: RelyingParty?
    let user: User?
    let rpID: String?
    let allowCredentials: [CredentialDescriptor]?

    enum CodingKeys: String, CodingKey {
        case challenge, rp, user
        case rpID = "rpId"
        case allowCredentials
    }
}

private struct MePayload: Decodable {
    let passkey: PasskeyStatus
}

private struct LoginPayload: Decodable {
    let mobileToken: String
    let mobileRefreshToken: String?
    let mobileTokenExpiresAt: Int?
    let user: AuthUser?

    enum CodingKeys: String, CodingKey {
        case mobileToken = "mobile_token"
        case mobileRefreshToken = "mobile_refresh_token"
        case mobileTokenExpiresAt = "mobile_token_expires_at"
        case user
    }
}

private struct EmptyPayload: Decodable {}
