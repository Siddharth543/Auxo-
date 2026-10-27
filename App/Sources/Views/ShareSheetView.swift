import SwiftUI
import AuxoCore
import AuxoUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Previews the 1200×630 share image and offers Copy and the system share sheet.
struct ShareSheetView: View {
    let target: ShareTarget

    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var includeHandle = false
    @State private var image: CGImage?
    @State private var copied = false

    private var isAccount: Bool {
        if case .account = target { return true }
        return false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Share card").font(.headline)
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }

            Group {
                if let image {
                    Image(decorative: image, scale: 1)
                        .resizable()
                        .aspectRatio(ShareCardView.size.width / ShareCardView.size.height, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 220)
                }
            }
            .accessibilityLabel("Share card preview")

            if isAccount {
                Toggle("Include username", isOn: $includeHandle)
            }

            HStack(spacing: 12) {
                Button(copied ? "Copied" : "Copy image") { copy() }
                    .disabled(image == nil)
                if let image {
                    let shareImage = Image(decorative: image, scale: 1)
                    ShareLink(item: shareImage, preview: SharePreview("Auxo streak", image: shareImage)) {
                        Label("Share…", systemImage: "square.and.arrow.up")
                    }
                }
                Spacer()
            }
        }
        .padding(20)
        #if os(macOS)
        .frame(width: 620)
        #endif
        .task(id: includeHandle) { render() }
    }

    @MainActor
    private func render() {
        copied = false
        image = ShareCardRenderer.cgImage(makeCard())
    }

    @MainActor
    private func makeCard() -> ShareCardView {
        let today = LocalDay.today()
        let settings = model.settings
        let dateText = "Past 12 months · \(Date().formatted(date: .abbreviated, time: .omitted))"

        switch target {
        case .combined:
            let visible = model.accounts.filter { model.isShownOnDashboard($0) }
            let series = ActivitySeries.combined(visible.compactMap { model.snapshots[$0.id]?.series })
            let weeks = HeatmapLayout.weeks(count: 53, today: today,
                                            weekStartsOnMonday: settings.weekStartsOnMonday, series: series)
            let levels = Palette.combinedHexLevels(settings: settings)
            return ShareCardView(title: "All streaks",
                                 dotHex: settings.theme == .perSource ? SourceStyle.combinedHex : levels[3],
                                 stats: StreakStats.compute(series, today: today),
                                 unit: nil,
                                 rating: nil,
                                 weeks: weeks,
                                 levelHex: levels,
                                 dateText: dateText) { cell in
                min(cell.count, levels.count - 1)
            }

        case .account(let id):
            let account = model.accounts.first { $0.id == id }
            let source = account?.source ?? .github
            let snapshot = model.snapshots[id]
            let series = snapshot?.series ?? ActivitySeries()
            let weeks = HeatmapLayout.weeks(count: 53, today: today,
                                            weekStartsOnMonday: settings.weekStartsOnMonday, series: series)
            var title = source.displayName
            if includeHandle, let handle = account?.handle { title += "  ·  \(handle)" }
            return ShareCardView(title: title,
                                 dotHex: SourceStyle.hex(source),
                                 stats: StreakStats.compute(series, today: today),
                                 unit: source.unit(codeforcesAcceptedOnly: settings.codeforcesAcceptedOnly),
                                 rating: snapshot?.rating,
                                 weeks: weeks,
                                 levelHex: Palette.hexLevels(for: source, settings: settings),
                                 dateText: dateText) { cell in
                source.level(for: cell.count)
            }
        }
    }

    private func copy() {
        guard let image else { return }
        #if os(macOS)
        let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([nsImage])
        #else
        UIPasteboard.general.image = UIImage(cgImage: image)
        #endif
        copied = true
    }
}
