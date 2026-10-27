import SwiftUI
import AuxoCore
import AuxoUI

enum ShareTarget: Identifiable, Hashable {
    case combined
    case account(String)

    var id: String {
        switch self {
        case .combined: return "all"
        case .account(let id): return id
        }
    }
}

struct DashboardView: View {
    @EnvironmentObject private var model: AppModel
    @State private var shareTarget: ShareTarget?

    private var visible: [Account] {
        model.accounts.filter { model.isShownOnDashboard($0) }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if model.accounts.isEmpty {
                        emptyState
                    } else {
                        filters
                        if visible.isEmpty {
                            Text("All streaks are hidden. Turn one on above.")
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .card()
                        } else {
                            summary
                            combinedCard.id("all")
                            ForEach(visible) { account in
                                AccountCardView(account: account,
                                                snapshot: model.snapshots[account.id],
                                                settings: model.settings) {
                                    shareTarget = .account(account.id)
                                }
                                .id(account.id)
                            }
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: 1040, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .onChange(of: model.focusedAccountID) { _, id in
                focus(on: id, proxy: proxy)
            }
            .onAppear {
                focus(on: model.focusedAccountID, proxy: proxy)
            }
        }
        .navigationTitle("Dashboard")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await model.refresh(force: true) }
                } label: {
                    if model.isSyncing {
                        ProgressView().controlSize(.small)
                    } else {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
                .disabled(model.isSyncing || model.accounts.isEmpty)
                .help("Fetch the latest data now")
            }
        }
        .refreshable { await model.refresh(force: true) }
        .sheet(item: $shareTarget) { target in
            ShareSheetView(target: target)
                .environmentObject(model)
        }
    }

    /// Scrolls to the account a widget tap asked for, un-hiding it if needed.
    private func focus(on id: String?, proxy: ScrollViewProxy) {
        guard let id else { return }
        if id != "all", let account = model.accounts.first(where: { $0.id == id }),
           !model.isShownOnDashboard(account) {
            model.toggleDashboard(account)
        }
        model.focusedAccountID = nil
        DispatchQueue.main.async {
            withAnimation { proxy.scrollTo(id, anchor: .top) }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.grid.3x3.fill")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Add your first account")
                .font(.title3.weight(.semibold))
            Text("Auxo shows your GitHub, LeetCode and Codeforces streaks here and in desktop and home-screen widgets.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 420)
            Text("Open Accounts to add one.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private var filters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Text("Show")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                ForEach(model.accounts) { account in
                    let on = model.isShownOnDashboard(account)
                    Button {
                        model.toggleDashboard(account)
                    } label: {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(SourceStyle.color(account.source).opacity(on ? 1 : 0.35))
                                .frame(width: 8, height: 8)
                            Text("\(account.source.displayName) · \(account.handle)")
                                .font(.caption.weight(.semibold))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .foregroundStyle(on ? Color.primary : Color.secondary)
                        .background(Capsule().fill(on ? Color.accentColor.opacity(0.14) : Color.secondary.opacity(0.08)))
                        .overlay(Capsule().strokeBorder(on ? Color.accentColor.opacity(0.6) : Color.secondary.opacity(0.2)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityValue(on ? "Shown" : "Hidden")
                }
            }
        }
    }

    private var combinedSeries: ActivitySeries {
        ActivitySeries.combined(visible.compactMap { model.snapshots[$0.id]?.series })
    }

    private var summary: some View {
        let today = LocalDay.today()
        let combined = StreakStats.compute(combinedSeries, today: today)
        let perAccount = visible.map { account in
            (account, StreakStats.compute(model.snapshots[account.id]?.series ?? ActivitySeries(), today: today))
        }
        let best = perAccount.max { $0.1.current < $1.1.current }

        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 12)], spacing: 12) {
            summaryTile(value: "\(combined.current)d", label: "Combined streak (any source)")
            summaryTile(value: "\(best?.1.current ?? 0)d",
                        label: best.map { "Best current: \($0.0.source.displayName)" } ?? "Best current streak")
            summaryTile(value: "\(combined.activeDays)", label: "Days active in the past year")
        }
    }

    private func summaryTile(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .card()
    }

    private var combinedCard: some View {
        let levels = Palette.combinedLevels(settings: model.settings)
        let series = combinedSeries
        let weeks = HeatmapLayout.weeks(count: 53, today: .today(),
                                        weekStartsOnMonday: model.settings.weekStartsOnMonday, series: series)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                HStack(spacing: 4) {
                    Circle().fill(Color(hex: SourceStyle.combinedHex)).frame(width: 7, height: 7)
                    Text("All streaks").fontWeight(.semibold)
                }
                Text("Shade = how many accounts were active that day")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Share") { shareTarget = .combined }
            }
            YearHeatmap(weeks: weeks,
                        weekStartsOnMonday: model.settings.weekStartsOnMonday,
                        summary: "Combined activity heatmap") { cell in
                levels[min(cell.count, levels.count - 1)]
            }
        }
        .card()
    }
}
