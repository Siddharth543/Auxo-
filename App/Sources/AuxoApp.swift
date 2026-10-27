import SwiftUI

@main
struct AuxoApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .task { await model.refresh() }
                .onOpenURL { model.handle(url: $0) }
        }
        #if os(macOS)
        .defaultSize(width: 1000, height: 760)
        #endif
    }
}
