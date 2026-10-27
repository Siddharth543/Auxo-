import SwiftUI
import AuxoCore
import AuxoUI

struct AccountsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showingAdd = false
    @State private var pendingRemoval: Account?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        List {
            Section {
                if model.accounts.isEmpty {
                    Text("No accounts yet. Add your GitHub, LeetCode or Codeforces profile.")
                        .foregroundStyle(.secondary)
                }
                ForEach(model.accounts) { account in
                    row(account)
                }
                .onMove { model.move(from: $0, to: $1) }
            } footer: {
                Text("Accounts you add here appear in every widget's account picker. Drag to reorder.")
            }

            Section {
                if model.hasGitHubToken {
                    Label("Signed in to GitHub", systemImage: "checkmark.seal")
                    Button("Sign out of GitHub", role: .destructive) {
                        model.setGitHubToken(nil)
                    }
                } else {
                    Text("Not signed in. GitHub only shares contribution data with signed-in apps; you'll be asked to sign in when you add a GitHub account.")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("GitHub")
            }
        }
        .navigationTitle("Accounts")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAdd = true
                } label: {
                    Label("Add Account", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            AddAccountView()
                .environmentObject(model)
        }
        .confirmationDialog("Remove this account?",
                            isPresented: Binding(get: { pendingRemoval != nil }, set: { if !$0 { pendingRemoval = nil } }),
                            presenting: pendingRemoval) { account in
            Button("Remove \(account.source.displayName) · \(account.handle)", role: .destructive) {
                model.remove(account)
                pendingRemoval = nil
            }
        } message: { _ in
            Text("Its saved data is deleted and it disappears from your widgets.")
        }
    }

    private func row(_ account: Account) -> some View {
        HStack(spacing: 10) {
            SourceLabel(account.source)
            Text(account.handle)
                .font(.system(.body, design: .monospaced))
                .lineLimit(1)
            if let rating = model.snapshots[account.id]?.rating {
                RankText(rating, onDark: colorScheme == .dark)
                    .font(.callout.weight(.semibold))
            }
            Spacer(minLength: 8)
            StatusPill(snapshot: model.snapshots[account.id])
            Button(role: .destructive) {
                pendingRemoval = account
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Remove account")
            .accessibilityLabel("Remove \(account.source.displayName) account \(account.handle)")
        }
        .padding(.vertical, 2)
    }
}
