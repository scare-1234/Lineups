import SwiftUI

/// Where a builder navigation push goes.
enum BuilderRoute: Hashable {
    case new(seed: Player?)
    case edit(id: UUID)
    case detail(id: UUID)
}

/// Tab 2: saved lineups plus the entry point into the builder.
struct MyLineupsListView: View {

    @Environment(AppContainer.self) private var container
    @State private var path: [BuilderRoute] = []

    private var store: CustomLineupStore { container.store }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if store.lineups.isEmpty {
                    EmptyStateView(
                        title: L10n.Builder.noLineupsTitle,
                        message: L10n.Builder.noLineupsMessage,
                        systemImage: "rectangle.3.group",
                        actionTitle: L10n.Builder.newLineup,
                        action: { path.append(.new(seed: nil)) }
                    )
                } else {
                    lineupList
                }
            }
            .background(Theme.Palette.background)
            .navigationTitle(L10n.Builder.myLineups)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Haptics.impact(.light)
                        path.append(.new(seed: nil))
                    } label: {
                        Label(L10n.Builder.newLineup, systemImage: "plus")
                    }
                }
            }
            .navigationDestination(for: BuilderRoute.self) { route in
                destination(for: route)
            }
            .task {
                await store.loadLineups()
                await store.loadFavorites()
            }
            .onChange(of: container.pendingBuilderPlayer) { _, newValue in
                guard let player = newValue else { return }
                container.pendingBuilderPlayer = nil
                path.append(.new(seed: player))
            }
        }
    }

    private var lineupList: some View {
        List {
            ForEach(store.lineups) { lineup in
                Button {
                    path.append(.edit(id: lineup.id))
                } label: {
                    SavedLineupCard(lineup: lineup)
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        Task { await store.delete(id: lineup.id) }
                    } label: {
                        Label(L10n.Common.delete, systemImage: "trash")
                    }
                }
                .contextMenu {
                    Button {
                        path.append(.detail(id: lineup.id))
                    } label: {
                        Label(L10n.Builder.viewDetails, systemImage: "info.circle")
                    }
                    Button {
                        Task { await store.duplicate(lineup) }
                    } label: {
                        Label(L10n.Common.duplicate, systemImage: "doc.on.doc")
                    }
                    Button(role: .destructive) {
                        Task { await store.delete(id: lineup.id) }
                    } label: {
                        Label(L10n.Common.delete, systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .refreshable { await store.loadLineups() }
    }

    @ViewBuilder
    private func destination(for route: BuilderRoute) -> some View {
        switch route {
        case .new(let seed):
            LineupBuilderView(store: store, existing: nil, seed: seed)
        case .edit(let id):
            LineupBuilderView(store: store, existing: store.lineup(id: id))
        case .detail(let id):
            if let lineup = store.lineup(id: id) {
                CustomLineupDetailView(lineup: lineup)
            } else {
                EmptyStateView(
                    title: L10n.Builder.noLineupsTitle,
                    message: L10n.Builder.noLineupsMessage
                )
            }
        }
    }
}

/// Saved lineup card with a mini-pitch preview.
struct SavedLineupCard: View {
    let lineup: CustomLineup

    var body: some View {
        HStack(spacing: 12) {
            if let formation = lineup.parsedFormation {
                FormationMiniPitch(formation: formation, dotSize: 6)
                    .frame(width: 62)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(lineup.name)
                    .font(Theme.Typography.bodyEmphasis)
                    .lineLimit(1)
                Text(lineup.formation)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Palette.accent)
                HStack(spacing: 8) {
                    Label(RatingScale.text(for: lineup.averageRating), systemImage: "star.fill")
                    Label(
                        L10n.Lineups.playerCount(lineup.players.count, lineup.parsedFormation?.playerCount ?? 11),
                        systemImage: "person.3.fill"
                    )
                }
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Palette.secondaryText)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(Theme.Palette.secondaryText)
        }
        .cardStyle()
        .accessibilityElement(children: .combine)
    }
}

#Preview("My lineups") {
    MyLineupsListView()
        .environment(AppContainer.preview())
}
