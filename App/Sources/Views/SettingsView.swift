import SwiftUI
import AuxoCore
import AuxoUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel

    private var customColor: Binding<Color> {
        Binding(
            get: { Color(hex: model.settings.customAccentHex) },
            set: { newValue in
                if let hex = HexColor.string(from: newValue) {
                    model.settings.customAccentHex = hex
                }
            }
        )
    }

    var body: some View {
        Form {
            Section {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 10)], spacing: 10) {
                    ForEach(ThemeID.allCases) { theme in
                        themeButton(theme)
                    }
                }
                .padding(.vertical, 4)

                if model.settings.theme == .custom {
                    ColorPicker("Accent color", selection: customColor, supportsOpacity: false)
                }
            } header: {
                Text("Theme")
            } footer: {
                Text("Recolors every heatmap: widgets, this app and share cards. Rank colors always follow Codeforces and LeetCode.")
            }

            Section {
                Picker("Week starts on", selection: $model.settings.weekStartsOnMonday) {
                    Text("Sunday").tag(false)
                    Text("Monday").tag(true)
                }
                Toggle("Codeforces: count accepted submissions only", isOn: $model.settings.codeforcesAcceptedOnly)
            } header: {
                Text("Heatmap")
            }

            Section {
                LabeledContent("Version", value: Self.version)
                Link("Source code and issues on GitHub", destination: AuxoLinks.repository)
                Text("Data comes from the official Codeforces API, the official GitHub GraphQL API and the data endpoint behind LeetCode's public profile pages. Nothing is sent anywhere else, and Auxo has no servers.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } header: {
                Text("About")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .onChange(of: model.settings.codeforcesAcceptedOnly) { _, _ in
            Task { await model.refresh(force: true) }
        }
    }

    private func themeButton(_ theme: ThemeID) -> some View {
        let selected = model.settings.theme == theme
        return Button {
            model.settings.theme = theme
        } label: {
            VStack(spacing: 6) {
                HStack(spacing: 2) {
                    ForEach(Array(Palette.swatch(theme, customAccent: model.settings.customAccentHex).enumerated()), id: \.offset) { _, color in
                        RoundedRectangle(cornerRadius: 2).fill(color).frame(height: 12)
                    }
                }
                Text(theme.displayName)
                    .font(.caption.weight(selected ? .semibold : .regular))
                    .foregroundStyle(selected ? Color.primary : Color.secondary)
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 9).fill(Color.secondary.opacity(0.08)))
            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(selected ? Color.accentColor : Color.secondary.opacity(0.2),
                                                                     lineWidth: selected ? 2 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(theme.displayName) theme")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    static var version: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(short) (\(build))"
    }
}
