import SwiftUI

enum AppSection: String, CaseIterable, Identifiable, Hashable {
    case dashboard
    case accounts
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .accounts: return "Accounts"
        case .settings: return "Settings"
        }
    }

    var icon: String {
        switch self {
        case .dashboard: return "square.grid.3x3.fill"
        case .accounts: return "person.2"
        case .settings: return "gearshape"
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @State private var section: AppSection? = .dashboard

    var body: some View {
        content
            .onChange(of: model.focusedAccountID) { _, id in
                if id != nil { section = .dashboard }
            }
    }

    @ViewBuilder
    private var content: some View {
        #if os(macOS)
        NavigationSplitView {
            List(selection: $section) {
                ForEach(AppSection.allCases) { item in
                    NavigationLink(value: item) {
                        Label(item.title, systemImage: item.icon)
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 170, ideal: 200, max: 260)
        } detail: {
            NavigationStack {
                detail(for: section ?? .dashboard)
            }
        }
        #else
        TabView(selection: Binding(get: { section ?? .dashboard }, set: { section = $0 })) {
            ForEach(AppSection.allCases) { item in
                NavigationStack {
                    detail(for: item)
                }
                .tabItem { Label(item.title, systemImage: item.icon) }
                .tag(item)
            }
        }
        #endif
    }

    @ViewBuilder
    private func detail(for section: AppSection) -> some View {
        switch section {
        case .dashboard: DashboardView()
        case .accounts: AccountsView()
        case .settings: SettingsView()
        }
    }
}
