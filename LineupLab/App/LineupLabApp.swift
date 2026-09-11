import SwiftUI

@main
struct LineupLabApp: App {

    @State private var container = AppContainer.live()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(container)
                .tint(Theme.Palette.accent)
                .task {
                    await container.store.loadLineups()
                    await container.store.loadFavorites()
                }
        }
    }
}
