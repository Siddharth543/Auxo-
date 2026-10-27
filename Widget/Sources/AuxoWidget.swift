import SwiftUI
import WidgetKit
import AuxoUI

struct AuxoWidget: Widget {
    static let kind = "AuxoWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: Self.kind, intent: AuxoWidgetIntent.self, provider: AuxoTimelineProvider()) { entry in
            WidgetRootView(entry: entry)
                .environment(\.colorScheme, .dark)
                .containerBackground(for: .widget) {
                    Palette.surface
                }
        }
        .configurationDisplayName("Auxo Streaks")
        .description("GitHub, LeetCode and Codeforces heatmaps with your streak, rating and rank.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
    }
}

@main
struct AuxoWidgetBundle: WidgetBundle {
    var body: some Widget {
        AuxoWidget()
    }
}

#Preview(as: .systemMedium) {
    AuxoWidget()
} timeline: {
    SampleData.entry(layout: .single)
    SampleData.entry(layout: .stacked)
    SampleData.entry(layout: .combined)
}

#Preview(as: .systemLarge) {
    AuxoWidget()
} timeline: {
    SampleData.entry(layout: .single)
}
