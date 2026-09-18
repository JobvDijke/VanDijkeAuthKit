import Foundation

/// Configuration supplied by the host app.
public struct AuthConfiguration: Sendable, Equatable {
    public let apiBaseURL: URL
    public let clientID: String
    public let nativeOrigin: String
    public let resetLinkHost: String
    public let inviteLinkPath: String

    public init(
        apiBaseURL: URL,
        clientID: String,
        nativeOrigin: String,
        resetLinkHost: String? = nil,
        inviteLinkPath: String? = nil
    ) {
        self.apiBaseURL = apiBaseURL
        self.clientID = clientID
        self.nativeOrigin = nativeOrigin
        self.resetLinkHost = resetLinkHost ?? apiBaseURL.host ?? ""
        self.inviteLinkPath = inviteLinkPath ?? "/invite/\(clientID)"
    }

    func endpoint(_ path: String) -> URL {
        apiBaseURL.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
    }
}
