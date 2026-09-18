#if canImport(SwiftUI)
import SwiftUI

public struct LoginView: View {
    private let client: AuthClient
    private let onAuthenticated: (AuthSession) -> Void

    @State private var username = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var isLoading = false

    public init(
        client: AuthClient,
        onAuthenticated: @escaping (AuthSession) -> Void
    ) {
        self.client = client
        self.onAuthenticated = onAuthenticated
    }

    public var body: some View {
        Form {
            #if os(iOS)
            TextField("Username or email", text: $username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            #else
            TextField("Username or email", text: $username)
            #endif
            SecureField("Password", text: $password)

            Button("Sign in") {
                Task { await login() }
            }
            .disabled(username.isEmpty || password.isEmpty || isLoading)

            NavigationLink("Forgot password?") {
                ForgotPasswordView(client: client)
            }
        }
        .navigationTitle("Sign in")
        .alert("Sign in failed", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func login() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let session = try await client.login(username: username, password: password)
            onAuthenticated(session)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

public struct ForgotPasswordView: View {
    private let client: AuthClient
    @State private var email = ""
    @State private var message: String?
    @State private var errorMessage: String?
    @State private var isLoading = false

    public init(client: AuthClient) {
        self.client = client
    }

    public var body: some View {
        Form {
            Section {
                #if os(iOS)
                TextField("Email address", text: $email)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.emailAddress)
                #else
                TextField("Email address", text: $email)
                #endif

                Button("Send reset link") {
                    Task { await requestReset() }
                }
                .disabled(email.isEmpty || isLoading)
            }

            if let message {
                Section { Text(message).foregroundStyle(.secondary) }
            }
        }
        .navigationTitle("Forgot password")
        .alert("Password reset", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func requestReset() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await client.requestPasswordReset(email: email)
            message = result.message ?? "If an account exists, a reset link has been sent."
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

public struct InvitationRegistrationView: View {
    private let client: AuthClient
    private let inviteToken: String
    private let onRegistered: (AuthSession) -> Void

    @State private var username = ""
    @State private var password = ""
    @State private var confirmation = ""
    @State private var errorMessage: String?
    @State private var isLoading = false

    public init(
        client: AuthClient,
        inviteToken: String,
        onRegistered: @escaping (AuthSession) -> Void
    ) {
        self.client = client
        self.inviteToken = inviteToken
        self.onRegistered = onRegistered
    }

    public var body: some View {
        Form {
            Section {
                TextField("Username", text: $username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField("Password", text: $password)
                SecureField("Repeat password", text: $confirmation)
            }

            Button("Create account") {
                Task { await register() }
            }
            .disabled(username.isEmpty || password.isEmpty || confirmation.isEmpty || isLoading)
        }
        .navigationTitle("Create account")
        .alert("Registration failed", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func register() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let session = try await client.register(
                username: username,
                password: password,
                confirmation: confirmation,
                inviteToken: inviteToken
            )
            onRegistered(session)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

public struct ResetPasswordView: View {
    private let client: AuthClient
    private let token: String
    private let onCompleted: () -> Void

    @State private var password = ""
    @State private var confirmation = ""
    @State private var errorMessage: String?
    @State private var isLoading = false

    public init(
        client: AuthClient,
        token: String,
        onCompleted: @escaping () -> Void = {}
    ) {
        self.client = client
        self.token = token
        self.onCompleted = onCompleted
    }

    public var body: some View {
        Form {
            SecureField("New password", text: $password)
            SecureField("Repeat password", text: $confirmation)

            Button("Set new password") {
                Task { await resetPassword() }
            }
            .disabled(password.isEmpty || confirmation.isEmpty || isLoading)
        }
        .navigationTitle("Set password")
        .alert("Password reset failed", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func resetPassword() async {
        isLoading = true
        defer { isLoading = false }

        do {
            _ = try await client.resetPassword(token: token, password: password, confirmation: confirmation)
            onCompleted()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
#endif
