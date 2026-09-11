import SwiftUI

/// Search any player in the database and drop them into a slot.
struct PlayerPickerView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: PlayerSearchViewModel

    let slot: FormationSlot?
    let usedPlayerIDs: Set<Int>
    let onSelect: (Player) -> Void
    let onQuickFill: ([Player]) -> Void

    init(
        service: FootballAPIServicing,
        slot: FormationSlot?,
        usedPlayerIDs: Set<Int>,
        seed: [Player] = [],
        onSelect: @escaping (Player) -> Void,
        onQuickFill: @escaping ([Player]) -> Void
    ) {
        _viewModel = State(initialValue: PlayerSearchViewModel(service: service, seed: seed))
        self.slot = slot
        self.usedPlayerIDs = usedPlayerIDs
        self.onSelect = onSelect
        self.onQuickFill = onQuickFill
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                filters
                if let banner = viewModel.banner {
                    DataBannerView(banner: banner)
                }
                results
            }
            .background(Theme.Palette.background)
            .navigationTitle(slot.map { "\(L10n.Builder.pickPlayer) — \($0.label)" } ?? L10n.Builder.pickPlayer)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: Bindable(viewModel).query,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: L10n.Builder.searchPrompt
            )
            .onChange(of: viewModel.query) { _, _ in
                viewModel.queryChanged()
            }
            .onSubmit(of: .search) {
                Task { await viewModel.searchNow() }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L10n.Common.cancel) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.Builder.quickFill) {
                        Haptics.impact(.medium)
                        onQuickFill(viewModel.quickFillCandidates(excluding: usedPlayerIDs, role: slot?.role))
                        dismiss()
                    }
                    .disabled(viewModel.pool.isEmpty)
                }
            }
        }
    }

    private var filters: some View {
        VStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(title: L10n.Common.all, isSelected: viewModel.roleFilter == nil) {
                        viewModel.roleFilter = nil
                    }
                    ForEach(PitchRole.allCases) { role in
                        FilterChip(title: role.abbreviation, isSelected: viewModel.roleFilter == role) {
                            viewModel.roleFilter = viewModel.roleFilter == role ? nil : role
                        }
                    }
                }
                .padding(.horizontal)
            }

            HStack(spacing: 10) {
                Menu {
                    Button(L10n.Common.all) { viewModel.nationalityFilter = nil }
                    ForEach(viewModel.availableNationalities, id: \.self) { nationality in
                        Button(NationalityFlag.label(for: nationality)) {
                            viewModel.nationalityFilter = nationality
                        }
                    }
                } label: {
                    filterLabel(
                        title: viewModel.nationalityFilter.map { NationalityFlag.label(for: $0) } ?? L10n.Builder.nationality,
                        systemImage: "flag"
                    )
                }

                Menu {
                    Button(L10n.Common.none) { viewModel.minimumRating = 0 }
                    ForEach([6.0, 6.5, 7.0, 7.5, 8.0], id: \.self) { value in
                        Button(String(format: "%.1f+", value)) { viewModel.minimumRating = value }
                    }
                } label: {
                    filterLabel(
                        title: viewModel.minimumRating > 0
                            ? String(format: "%.1f+", viewModel.minimumRating)
                            : L10n.Builder.minRating,
                        systemImage: "star"
                    )
                }

                Spacer()
            }
            .padding(.horizontal)
        }
    }

    private func filterLabel(title: String, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage).font(.caption)
            Text(title).font(Theme.Typography.captionEmphasis).lineLimit(1)
            Image(systemName: "chevron.down").font(.system(size: 9))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Capsule().fill(Theme.Palette.card))
        .overlay { Capsule().strokeBorder(Theme.Palette.separator, lineWidth: 1) }
        .foregroundStyle(Theme.Palette.primaryText)
    }

    @ViewBuilder
    private var results: some View {
        if viewModel.isLoading {
            ScrollView { LoadingView(rows: 5) }
        } else if let error = viewModel.error {
            ErrorStateView(error: error) {
                Task { await viewModel.searchNow() }
            }
        } else if viewModel.isQueryTooShort {
            ContentUnavailableView(
                L10n.Builder.searchPrompt,
                systemImage: "magnifyingglass",
                description: Text(String(localized: "Type at least \(AppConstants.minimumSearchLength) characters.", comment: "Search hint"))
            )
        } else if viewModel.showsEmptyState {
            ContentUnavailableView(
                viewModel.hasSearched ? L10n.Builder.noPlayersFound : L10n.Builder.searchHint,
                systemImage: "person.crop.circle.badge.questionmark",
                description: Text(viewModel.hasSearched ? L10n.Builder.searchHint : L10n.Builder.searchPrompt)
            )
        } else {
            List {
                ForEach(viewModel.filteredResults) { player in
                    Button {
                        Haptics.impact(.medium)
                        onSelect(player)
                        dismiss()
                    } label: {
                        HStack {
                            PlayerCardView(player: player)
                            if usedPlayerIDs.contains(player.id) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Theme.Palette.accent)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Theme.Palette.card)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }
}

#Preview("Player picker") {
    PlayerPickerView(
        service: PreviewFootballAPIService(),
        slot: FormationParser.defaultFormation.slots.first,
        usedPlayerIDs: [],
        seed: MockData.searchResults,
        onSelect: { _ in },
        onQuickFill: { _ in }
    )
}
