import SwiftUI

/// Three tabs: matches, the lineup builder and international football.
struct RootTabView: View {

    @Environment(AppContainer.self) private var container

    var body: some View {
        @Bindable var container = container

        return TabView(selection: $container.selectedTab) {
            MatchListView(service: container.service, store: container.store)
                .tabItem {
                    Label(L10n.App.tabMatches, systemImage: "sportscourt.fill")
                }
                .tag(AppTab.matches)

            MyLineupsListView()
                .tabItem {
                    Label(L10n.App.tabBuilder, systemImage: "person.3.sequence.fill")
                }
                .tag(AppTab.builder)

            InternationalView(service: container.service)
                .tabItem {
                    Label(L10n.App.tabInternational, systemImage: "globe")
                }
                .tag(AppTab.international)
        }
        .tint(Theme.Palette.accent)
    }
}

#Preview("Root") {
    RootTabView()
        .environment(AppContainer.preview())
}

#Preview("Root — needs API key") {
    RootTabView()
        .environment(AppContainer.preview(behaviour: .failure(.configuration(.missingFile)), configurationError: .missingFile))
}
