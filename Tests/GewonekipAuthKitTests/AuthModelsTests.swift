import XCTest
@testable import GewonekipAuthKit

final class AuthModelsTests: XCTestCase {
    func testLoginPayloadShapeCanBeDecodedThroughSessionModels() throws {
        let data = #"{"token":"token-123","user":{"id":7,"username":"job","email":"job@example.com"}}"#.data(using: .utf8)!
        let session = try JSONDecoder().decode(AuthSession.self, from: data)

        XCTAssertEqual(session.token, "token-123")
        XCTAssertEqual(session.user?.id, 7)
        XCTAssertEqual(session.user?.email, "job@example.com")
    }

    func testPasskeyStatusDecodes() throws {
        let data = #"{"enabled":true,"count":2}"#.data(using: .utf8)!
        let status = try JSONDecoder().decode(PasskeyStatus.self, from: data)

        XCTAssertEqual(status, PasskeyStatus(enabled: true, count: 2))
    }

    func testPasswordResetLinkExtractsTokenAndClientID() {
        let configuration = AuthConfiguration(
            apiBaseURL: URL(string: "https://accounts.gewonekip.com/api")!,
            clientID: "beesterlijk",
            nativeOrigin: "beesterlijk-ios://app"
        )
        let url = URL(string: "https://accounts.gewonekip.com/reset/beesterlijk?token=abc123&client_id=beesterlijk")!

        let link = PasswordResetLink(url: url, configuration: configuration)

        XCTAssertEqual(link?.token, "abc123")
        XCTAssertEqual(link?.clientID, "beesterlijk")
    }

    func testPasswordResetLinkRejectsOtherHosts() {
        let configuration = AuthConfiguration(
            apiBaseURL: URL(string: "https://accounts.gewonekip.com/api")!,
            clientID: "beesterlijk",
            nativeOrigin: "beesterlijk-ios://app"
        )
        let url = URL(string: "https://example.com/reset/beesterlijk?token=abc123")!

        XCTAssertNil(PasswordResetLink(url: url, configuration: configuration))
    }

    func testPasswordResetLinkRequiresExactAppPath() {
        let configuration = AuthConfiguration(
            apiBaseURL: URL(string: "https://accounts.gewonekip.com/api")!,
            clientID: "beesterlijk",
            nativeOrigin: "beesterlijk-ios://app"
        )

        XCTAssertNil(PasswordResetLink(
            url: URL(string: "https://accounts.gewonekip.com/reset/gewonekip-admin?token=abc123")!,
            configuration: configuration
        ))
        XCTAssertNil(PasswordResetLink(
            url: URL(string: "https://accounts.gewonekip.com/reset/beesterlijk/extra?token=abc123")!,
            configuration: configuration
        ))
        XCTAssertNil(PasswordResetLink(
            url: URL(string: "https://accounts.gewonekip.com/reset/beesterlijk?token=abc123&client_id=gewonekip-admin")!,
            configuration: configuration
        ))
    }

    func testAccountInviteLinkRequiresExactClientPathAndClientID() {
        let configuration = AuthConfiguration(
            apiBaseURL: URL(string: "https://accounts.gewonekip.com/api")!,
            clientID: "beesterlijk",
            nativeOrigin: "beesterlijk-ios://app"
        )
        let url = URL(string: "https://accounts.gewonekip.com/invite/beesterlijk?token=abc123&client_id=beesterlijk")!

        let link = AccountInviteLink(url: url, configuration: configuration)

        XCTAssertEqual(link?.token, "abc123")
        XCTAssertEqual(link?.clientID, "beesterlijk")
        XCTAssertNil(AccountInviteLink(
            url: URL(string: "https://accounts.gewonekip.com/invite/other?token=abc123&client_id=beesterlijk")!,
            configuration: configuration
        ))
        XCTAssertNil(AccountInviteLink(
            url: URL(string: "https://accounts.gewonekip.com/invite/beesterlijk?token=abc123&client_id=gewonekip-admin")!,
            configuration: configuration
        ))
    }
}
