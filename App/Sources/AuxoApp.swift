import SwiftUI

@main
struct AuxoApp: App {
    @StateObject private var model = AppModel()

    private var content: some View {
        RootView()
            .environmentObject(model)
            .task { await model.refresh() }
            .onOpenURL { model.handle(url: $0) }
    }

    var body: some Scene {
        #if os(macOS)
        // `Window` is single-instance. A `WindowGroup` opens a new window for every auxo:// link
        // a widget sends, so clicking a stacked widget used to spawn several windows.
        Window("Auxo", id: "main") { content }
            .defaultSize(width: 1000, height: 760)
        #else
        WindowGroup { content }
        #endif
    }
}
