import Foundation

public protocol AuthSessionStore: Sendable {
    func load() -> AuthSession?
    func save(_ session: AuthSession)
    func clear()
}

/// Useful for previews and tests. Production apps should use KeychainAuthSessionStore.
public final class InMemoryAuthSessionStore: AuthSessionStore, @unchecked Sendable {
    private var session: AuthSession?

    public init(session: AuthSession? = nil) {
        self.session = session
    }

    public func load() -> AuthSession? { session }
    public func save(_ session: AuthSession) { self.session = session }
    public func clear() { session = nil }
}
