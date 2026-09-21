# GewonekipAuthKit

Shared native authentication components for Gewonekip apps.

The package owns the reusable account experience:

- Login and logout
- Password-reset request and confirmation
- Universal-link reset-token parsing
- Keychain session storage
- Reusable SwiftUI screens

It does not own app-specific API calls, permissions, or business logic.

## Add the package

In Xcode, add this repository as a Swift Package dependency and import it:

```swift
import GewonekipAuthKit
```

## Configure an app

```swift
let configuration = AuthConfiguration(
    apiBaseURL: URL(string: "https://accounts.gewonekip.com/api")!,
    clientID: "beesterlijk",
    nativeOrigin: "beesterlijk-ios://app",
    resetLinkHost: "accounts.gewonekip.com"
)

let client = AuthClient(
    configuration: configuration,
    sessionStore: KeychainAuthSessionStore(service: "nl.beesterlijk.app")
)
```

The account API is hosted at `https://accounts.gewonekip.com/api`.

## Native screens

```swift
NavigationStack {
    LoginView(client: client) { session in
        // Switch to the host app's authenticated root view.
        print(session.user?.username ?? "signed in")
    }
}
```

For an incoming universal link, extract the token and present the reset view:

```swift
if let link = PasswordResetLink(url: url, configuration: configuration) {
    ResetPasswordView(client: client, token: link.token)
}
```

## Repository policy

This package contains no secrets. Apps should provide their own client ID,
native origin, bundle-specific Keychain service, and app-specific API code.

## Local security hook

Enable the repository's pre-push security scan once after cloning:

```sh
./scripts/install_git_hooks.sh
```

The hook scans the current tracked files and all commits being pushed for
secrets and signing files.
