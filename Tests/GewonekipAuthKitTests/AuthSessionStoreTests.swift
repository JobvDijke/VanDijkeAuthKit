import XCTest
@testable import GewonekipAuthKit

final class AuthSessionStoreTests: XCTestCase {
    func testInMemoryStoreRoundTripsAndClears() {
        let store = InMemoryAuthSessionStore()
        let session = AuthSession(
            token: "token-123",
            user: AuthUser(id: 7, username: "job")
        )

        XCTAssertNil(store.load())
        store.save(session)
        XCTAssertEqual(store.load(), session)
        store.clear()
        XCTAssertNil(store.load())
    }
}
