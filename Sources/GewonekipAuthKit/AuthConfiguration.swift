import Foundation

/// Configuration supplied by the host app.
public struct AuthConfiguration: Sendable, Equatable {
    public let apiBaseURL: URL
    public let clientID: String
    public let nativeOrigin: String
    public let resetLinkHost: String
    public let resetLinkPath: String
    public let inviteLinkPath: String
    public let passkeysEnabled: Bool

    public init(
        apiBaseURL: URL,
        clientID: String,
        nativeOrigin: String,
        resetLinkHost: String? = nil,
        resetLinkPath: String? = nil,
        inviteLinkPath: String? = nil,
        passkeysEnabled: Bool = false
    ) {
        self.apiBaseURL = apiBaseURL
        self.clientID = clientID
        self.nativeOrigin = nativeOrigin
        self.resetLinkHost = resetLinkHost ?? apiBaseURL.host ?? ""
        self.resetLinkPath = resetLinkPath ?? "/reset/\(clientID)"
        self.inviteLinkPath = inviteLinkPath ?? "/invite/\(clientID)"
        self.passkeysEnabled = passkeysEnabled
    }

    func endpoint(_ path: String) -> URL {
        apiBaseURL.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
    }
}
