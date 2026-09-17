import XCTest
@testable import VanDijkeAuthKit

final class AuthModelsTests: XCTestCase {
    func testLoginPayloadShapeCanBeDecodedThroughSessionModels() throws {
        let data = #"{"token":"token-123","user":{"id":7,"username":"job","email":"job@example.com"}}"#.data(using: .utf8)!
        let session = try JSONDecoder().decode(AuthSession.self, from: data)

        XCTAssertEqual(session.token, "token-123")
        XCTAssertEqual(session.user?.id, 7)
        XCTAssertEqual(session.user?.email, "job@example.com")
    }

    func testPasswordResetLinkExtractsTokenAndClientID() {
        let configuration = AuthConfiguration(
            apiBaseURL: URL(string: "https://accounts.vandij.ke/api")!,
            clientID: "beesterlijk",
            nativeOrigin: "beesterlijk-ios://app"
        )
        let url = URL(string: "https://accounts.vandij.ke/reset/beesterlijk?token=abc123&client_id=beesterlijk")!

        let link = PasswordResetLink(url: url, configuration: configuration)

        XCTAssertEqual(link?.token, "abc123")
        XCTAssertEqual(link?.clientID, "beesterlijk")
    }

    func testPasswordResetLinkRejectsOtherHosts() {
        let configuration = AuthConfiguration(
            apiBaseURL: URL(string: "https://accounts.vandij.ke/api")!,
            clientID: "beesterlijk",
            nativeOrigin: "beesterlijk-ios://app"
        )
        let url = URL(string: "https://example.com/reset/beesterlijk?token=abc123")!

        XCTAssertNil(PasswordResetLink(url: url, configuration: configuration))
    }
}
