import AppIntents
import WidgetKit
import AuxoCore
import AuxoProviders

enum WidgetLayout: String, AppEnum {
    case single
    case stacked
    case combined

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Layout"

    static var caseDisplayRepresentations: [WidgetLayout: DisplayRepresentation] = [
        .single: "Single",
        .stacked: "Stacked",
        .combined: "Combined",
    ]
}

/// An account from the app, offered in the widget's "Edit Widget" picker.
struct AccountEntity: AppEntity {
    let id: String
    let sourceName: String
    let handle: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Account"
    static var defaultQuery = AccountQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(sourceName)", subtitle: "\(handle)")
    }

    init(_ account: Account) {
        id = account.id
        sourceName = account.source.displayName
        handle = account.handle
    }
}

struct AccountQuery: EntityQuery {
    func entities(for identifiers: [AccountEntity.ID]) async throws -> [AccountEntity] {
        SharedStore.shared.accounts()
            .filter { identifiers.contains($0.id) }
            .map(AccountEntity.init)
    }

    func suggestedEntities() async throws -> [AccountEntity] {
        SharedStore.shared.accounts().map(AccountEntity.init)
    }

    func defaultResult() async -> AccountEntity? {
        SharedStore.shared.accounts().first.map(AccountEntity.init)
    }
}

struct AuxoWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Auxo"
    static var description = IntentDescription("Your coding streaks from GitHub, LeetCode and Codeforces.")

    @Parameter(title: "Layout", default: .single)
    var layout: WidgetLayout

    @Parameter(title: "Account")
    var account: AccountEntity?

    @Parameter(title: "Accounts")
    var accounts: [AccountEntity]?

    static var parameterSummary: some ParameterSummary {
        When(\AuxoWidgetIntent.$layout, .equalTo, WidgetLayout.single) {
            Summary {
                \AuxoWidgetIntent.$layout
                \AuxoWidgetIntent.$account
            }
        } otherwise: {
            Summary {
                \AuxoWidgetIntent.$layout
                \AuxoWidgetIntent.$accounts
            }
        }
    }
}

/// The ↻ button on the widget. Runs in the widget process; WidgetKit reloads the widget afterwards.
struct RefreshIntent: AppIntent {
    static var title: LocalizedStringResource = "Refresh Auxo"
    static var isDiscoverable: Bool = false

    func perform() async throws -> some IntentResult {
        await SyncService.shared.sync(SharedStore.shared.accounts(), force: true)
        return .result()
    }
}
