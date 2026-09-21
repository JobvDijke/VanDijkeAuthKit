#if os(iOS)
import AuthenticationServices
import UIKit

struct PasskeyCredential: Sendable {
    let id: String
    let rawId: String
    let clientDataJSON: String
    let attestationObject: String?
    let authenticatorData: String?
    let signature: String?
    let userHandle: String?

    var registrationBody: [String: Any] {
        [
            "id": id,
            "rawId": rawId,
            "type": "public-key",
            "response": [
                "clientDataJSON": clientDataJSON,
                "attestationObject": attestationObject ?? "",
            ],
        ]
    }

    var assertionBody: [String: Any] {
        [
            "id": id,
            "rawId": rawId,
            "type": "public-key",
            "response": [
                "clientDataJSON": clientDataJSON,
                "authenticatorData": authenticatorData ?? "",
                "signature": signature ?? "",
                "userHandle": userHandle ?? "",
            ],
        ]
    }
}

enum PasskeyAuthorization {
    @MainActor
    static func register(options: PasskeyOptions) async throws -> PasskeyCredential {
        guard let user = options.user,
              let challenge = decode(options.challenge),
              let userID = decode(user.id),
              let relyingPartyID = options.rp?.id else {
            throw AuthError.invalidResponse
        }

        let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(
            relyingPartyIdentifier: relyingPartyID
        )
        let request = provider.createCredentialRegistrationRequest(
            challenge: challenge,
            name: user.name,
            userID: userID
        )
        request.userVerificationPreference = .required
        let authorization = try await perform(request)
        guard let credential = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialRegistration else {
            throw AuthError.invalidResponse
        }

        return PasskeyCredential(
            id: encode(credential.credentialID),
            rawId: encode(credential.credentialID),
            clientDataJSON: encode(credential.rawClientDataJSON),
            attestationObject: encode(credential.rawAttestationObject),
            authenticatorData: nil,
            signature: nil,
            userHandle: nil
        )
    }

    @MainActor
    static func `assert`(options: PasskeyOptions) async throws -> PasskeyCredential {
        guard let challenge = decode(options.challenge),
              let relyingPartyID = options.rpID else {
            throw AuthError.invalidResponse
        }

        let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(
            relyingPartyIdentifier: relyingPartyID
        )
        let request = provider.createCredentialAssertionRequest(challenge: challenge)
        request.userVerificationPreference = .required
        if let allowedCredentials = options.allowCredentials {
            request.allowedCredentials = allowedCredentials.compactMap { descriptor in
                guard let credentialID = decode(descriptor.id) else { return nil }
                return ASAuthorizationPublicKeyCredentialDescriptor(credentialID: credentialID)
            }
        }

        let authorization = try await perform(request)
        guard let credential = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialAssertion else {
            throw AuthError.invalidResponse
        }

        return PasskeyCredential(
            id: encode(credential.credentialID),
            rawId: encode(credential.credentialID),
            clientDataJSON: encode(credential.rawClientDataJSON),
            attestationObject: nil,
            authenticatorData: encode(credential.rawAuthenticatorData),
            signature: encode(credential.signature),
            userHandle: encode(credential.userID)
        )
    }

    @MainActor
    private static func perform(_ request: ASAuthorizationRequest) async throws -> ASAuthorization {
        let delegate = AuthorizationDelegate()
        let controller = ASAuthorizationController(authorizationRequests: [request])
        delegate.controller = controller
        controller.delegate = delegate
        controller.presentationContextProvider = delegate
        return try await delegate.perform()
    }

    private static func decode(_ value: String) -> Data? {
        guard let data = Data(base64URLEncoded: value) else { return nil }
        return data
    }

    private static func encode(_ data: Data?) -> String {
        data?.base64URLEncodedString() ?? ""
    }
}

@MainActor
private final class AuthorizationDelegate: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    var controller: ASAuthorizationController?
    private var continuation: CheckedContinuation<ASAuthorization, Error>?

    func perform() async throws -> ASAuthorization {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            controller?.performRequests()
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        continuation?.resume(returning: authorization)
        continuation = nil
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: { $0.isKeyWindow }) ?? UIWindow()
    }
}

private extension Data {
    init?(base64URLEncoded value: String) {
        var value = value.replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        value += String(repeating: "=", count: (4 - value.count % 4) % 4)
        self.init(base64Encoded: value)
    }

    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
#endif
