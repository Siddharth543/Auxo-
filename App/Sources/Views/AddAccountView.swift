import SwiftUI
import AuxoCore
import AuxoProviders

struct AddAccountView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var source: Source = .codeforces
    @State private var handle = ""
    @State private var isWorking = false
    @State private var errorText: String?

    // GitHub sign-in
    @State private var deviceCode: GitHubDeviceFlow.Code?
    @State private var signInTask: Task<Void, Never>?
    @State private var personalToken = ""

    private var needsGitHubSignIn: Bool { source == .github && !model.hasGitHubToken }

    private var canAdd: Bool {
        !isWorking && !needsGitHubSignIn && !handle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Source", selection: $source) {
                        ForEach(Source.allCases) { item in
                            Text(item.displayName).tag(item)
                        }
                    }
                }

                if needsGitHubSignIn {
                    githubSignIn
                } else {
                    Section {
                        TextField(source.handleLabel, text: $handle)
                            .autocorrectionDisabled()
                            #if os(iOS)
                            .textInputAutocapitalization(.never)
                            #endif
                            .onSubmit { if canAdd { add() } }
                    } footer: {
                        Text(source.handleHint)
                    }
                }

                if source == .leetcode {
                    Section {
                        Text("LeetCode has no official API. Auxo reads the same data your public profile page shows; if LeetCode changes that page, its heatmap may stop updating until Auxo is updated.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if let errorText {
                    Section {
                        Text(errorText)
                            .foregroundStyle(.red)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Add Account")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        signInTask?.cancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isWorking {
                        ProgressView().controlSize(.small)
                    } else {
                        Button("Add") { add() }
                            .disabled(!canAdd)
                    }
                }
            }
            .onChange(of: source) { _, _ in
                errorText = nil
            }
        }
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 380)
        #endif
        .onDisappear { signInTask?.cancel() }
    }

    // MARK: GitHub sign-in

    @ViewBuilder
    private var githubSignIn: some View {
        Section {
            Text("GitHub only shares contribution calendars with signed-in apps. Auxo requests no permissions: the token can read public profile data only, and it's stored in your Keychain.")
                .font(.callout)

            if let clientID = GitHubConfig.clientID {
                if let code = deviceCode {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Enter this code on GitHub:")
                        Text(code.userCode)
                            .font(.system(size: 28, weight: .semibold, design: .monospaced))
                            .textSelection(.enabled)
                        Link("Open \(code.verificationURL.host ?? "github.com")\(code.verificationURL.path)",
                             destination: code.verificationURL)
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text("Waiting for you to approve…")
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Button("Sign in with GitHub") { startDeviceFlow(clientID: clientID) }
                }
            }
        } header: {
            Text("Sign in to GitHub")
        }

        Section {
            SecureField("Personal access token", text: $personalToken)
            Button("Use this token") { usePersonalToken() }
                .disabled(personalToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isWorking)
            if let url = URL(string: "https://github.com/settings/personal-access-tokens/new") {
                Link("Create a fine-grained token (no permissions needed)", destination: url)
            }
        } header: {
            Text(GitHubConfig.clientID == nil ? "Sign in with a token" : "Or use a token")
        } footer: {
            Text("Choose “Public repositories” access and leave every permission at “No access”.")
        }
    }

    @MainActor
    private func startDeviceFlow(clientID: String) {
        errorText = nil
        signInTask?.cancel()
        signInTask = Task {
            do {
                let flow = GitHubDeviceFlow(clientID: clientID)
                let code = try await flow.start()
                deviceCode = code
                let token = try await flow.waitForToken(code)
                try await finishSignIn(token: token)
            } catch is CancellationError {
                deviceCode = nil
            } catch {
                deviceCode = nil
                errorText = error.localizedDescription
            }
        }
    }

    @MainActor
    private func usePersonalToken() {
        let token = personalToken.trimmingCharacters(in: .whitespacesAndNewlines)
        errorText = nil
        isWorking = true
        Task {
            do {
                try await finishSignIn(token: token)
                personalToken = ""
            } catch {
                errorText = error.localizedDescription
            }
            isWorking = false
        }
    }

    @MainActor
    private func finishSignIn(token: String) async throws {
        let login = try await GitHubProvider().viewerLogin(token: token)
        guard model.setGitHubToken(token) else {
            throw ProviderError.unavailable("Couldn't save the token to your Keychain.")
        }
        deviceCode = nil
        if handle.isEmpty { handle = login }
    }

    // MARK: Add

    @MainActor
    private func add() {
        errorText = nil
        isWorking = true
        let source = source
        let handle = handle
        Task {
            do {
                try await model.addAccount(source: source, handle: handle)
                isWorking = false
                dismiss()
            } catch {
                errorText = error.localizedDescription
                isWorking = false
            }
        }
    }
}
