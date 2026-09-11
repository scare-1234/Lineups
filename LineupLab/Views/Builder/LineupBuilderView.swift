import SwiftUI

/// The custom lineup builder: pick a formation, fill every slot with any player in the
/// database, drag players around, then save the XI to Core Data.
struct LineupBuilderView: View {

    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: LineupBuilderViewModel

    @State private var isShowingFormationPicker = false
    @State private var isShowingNameDialog = false
    @State private var draftName = ""
    @State private var playerSheet: PlayerSheetTarget?
    @State private var slotActionTarget: FormationSlot?
    @State private var pickerSlot: FormationSlot?
    @State private var seedPlayers: [Player] = []
    @State private var shareCard: Image?

    init(store: CustomLineupStore, existing: CustomLineup? = nil, seed: Player? = nil) {
        _viewModel = State(initialValue: LineupBuilderViewModel(store: store, existing: existing))
        _seedPlayers = State(initialValue: seed.map { [$0] } ?? [])
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Layout.sectionSpacing) {
                formationSection
                pitchSection
                if viewModel.unplaced.isEmpty == false {
                    UnplacedPlayersStrip(players: viewModel.unplaced) { player in
                        if let slot = FormationParser.bestSlot(
                            for: player.role,
                            in: viewModel.formation,
                            occupied: Set(viewModel.assignments.keys)
                        ) {
                            withAnimation(Theme.Motion.slotSpring) {
                                _ = viewModel.assign(player, to: slot)
                            }
                        }
                    }
                }
                actionButtons
                LineupSummaryCard(
                    averageRating: viewModel.averageRating,
                    totalAge: viewModel.totalAge,
                    averageAge: viewModel.averageAge,
                    nationalities: viewModel.nationalityBreakdown
                )
                if viewModel.saveIssues.isEmpty == false {
                    ValidationIssuesView(issues: viewModel.saveIssues)
                }
            }
            .padding(.vertical, 12)
        }
        .background(Theme.Palette.background)
        .navigationTitle(viewModel.name.isEmpty ? L10n.Builder.title : viewModel.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(L10n.Common.save) {
                    draftName = viewModel.name
                    isShowingNameDialog = true
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if let shareCard {
                    ShareLink(
                        item: shareCard,
                        preview: SharePreview(shareTitle, image: shareCard)
                    ) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .sheet(isPresented: $isShowingFormationPicker) {
            FormationPickerView(selected: viewModel.formation.name) { name in
                withAnimation(Theme.Motion.formationChange) {
                    viewModel.change(formationNamed: name)
                }
            }
        }
        .sheet(item: $pickerSlot) { slot in
            PlayerPickerView(
                service: container.service,
                slot: slot,
                usedPlayerIDs: viewModel.usedPlayerIDs,
                seed: seedPlayers,
                onSelect: { player in
                    seedPlayers.append(player)
                    withAnimation(Theme.Motion.slotSpring) {
                        _ = viewModel.assign(player, to: slot)
                    }
                },
                onQuickFill: { candidates in
                    seedPlayers.append(contentsOf: candidates)
                    withAnimation(Theme.Motion.slotSpring) {
                        _ = viewModel.quickFill(from: candidates)
                    }
                }
            )
        }
        .sheet(item: $playerSheet) { target in
            PlayerDetailView(player: target.player, service: container.service, store: container.store)
        }
        .confirmationDialog(
            slotActionTarget?.label ?? "",
            isPresented: Binding(
                get: { slotActionTarget != nil },
                set: { if $0 == false { slotActionTarget = nil } }
            ),
            titleVisibility: .visible
        ) {
            slotActions
        }
        .alert(L10n.Builder.nameYourLineup, isPresented: $isShowingNameDialog) {
            TextField(L10n.Builder.lineupName, text: $draftName)
            Button(L10n.Common.cancel, role: .cancel) {}
            Button(L10n.Common.save) {
                viewModel.name = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
                Task {
                    if await viewModel.save() { dismiss() }
                }
            }
        }
        .task {
            if let seed = seedPlayers.first, viewModel.assignments.isEmpty {
                _ = viewModel.assign(seed)
            }
        }
        .task(id: shareSignature) {
            shareCard = renderShareCard()
        }
    }

    // MARK: - Sections

    private var formationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L10n.Formation.title)
                    .font(Theme.Typography.sectionTitle)
                Spacer()
                Button {
                    isShowingFormationPicker = true
                } label: {
                    Label(viewModel.formation.name, systemImage: "square.grid.3x3")
                        .font(Theme.Typography.captionEmphasis)
                }
                .tint(Theme.Palette.accent)
            }
            .padding(.horizontal)

            FormationStrip(selected: viewModel.formation.name) { name in
                withAnimation(Theme.Motion.formationChange) {
                    viewModel.change(formationNamed: name)
                }
            }

            Text(viewModel.progressLabel)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Palette.secondaryText)
                .padding(.horizontal)
        }
    }

    private var pitchSection: some View {
        VStack(spacing: 6) {
            BuilderPitch(
                formation: viewModel.formation,
                assignments: viewModel.assignments,
                onTapSlot: { slot in
                    if viewModel.player(in: slot) == nil {
                        pickerSlot = slot
                    } else {
                        slotActionTarget = slot
                    }
                },
                onDrop: { source, destination in
                    withAnimation(Theme.Motion.slotSpring) {
                        viewModel.move(from: source, to: destination)
                    }
                }
            )
            .padding(.horizontal)

            Text(L10n.Builder.dragHint)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Palette.secondaryText)
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 10) {
            Button {
                let used = viewModel.usedPlayerIDs
                let candidates = seedPlayers.filter { used.contains($0.id) == false }
                if candidates.isEmpty {
                    // Nothing discovered yet: send the user to search first.
                    pickerSlot = firstEmptySlot
                } else {
                    withAnimation(Theme.Motion.slotSpring) {
                        _ = viewModel.quickFill(from: candidates)
                    }
                }
            } label: {
                Label(L10n.Builder.quickFill, systemImage: "wand.and.stars")
                    .font(Theme.Typography.captionEmphasis)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.Palette.accent)
            .foregroundStyle(Color.black)

            Button(role: .destructive) {
                withAnimation(Theme.Motion.quick) { viewModel.clearAll() }
            } label: {
                Label(L10n.Builder.clearAll, systemImage: "trash")
                    .font(Theme.Typography.captionEmphasis)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var slotActions: some View {
        if let slot = slotActionTarget {
            Button(L10n.Builder.replacePlayer) {
                slotActionTarget = nil
                pickerSlot = slot
            }
            if let player = viewModel.player(in: slot) {
                Button(L10n.Builder.viewDetails) {
                    slotActionTarget = nil
                    playerSheet = PlayerSheetTarget(
                        id: player.playerId,
                        player: Player(custom: player),
                        matchStats: nil
                    )
                }
            }
            Button(L10n.Builder.removePlayer, role: .destructive) {
                withAnimation(Theme.Motion.slotSpring) {
                    viewModel.remove(slotID: slot.id)
                }
                slotActionTarget = nil
            }
            Button(L10n.Common.cancel, role: .cancel) { slotActionTarget = nil }
        }
    }

    private var firstEmptySlot: FormationSlot? {
        viewModel.formation.slots.first { viewModel.assignments[$0.id] == nil }
            ?? viewModel.formation.slots.first
    }

    private var shareTitle: String {
        viewModel.name.isEmpty ? L10n.Builder.title : viewModel.name
    }

    /// Signature that changes whenever the shared image would look different.
    private var shareSignature: String {
        "\(viewModel.formation.name)-\(viewModel.filledCount)-\(shareTitle)"
    }

    /// Renders the current XI to an image for sharing.
    private func renderShareCard() -> Image? {
        LineupImageRenderer.render(
            title: shareTitle,
            formation: viewModel.formation,
            assignments: viewModel.assignments,
            averageRating: viewModel.averageRating
        )
    }
}

/// The builder pitch: one tappable, draggable token per slot.
struct BuilderPitch: View {
    let formation: Formation
    let assignments: [String: CustomLineupPlayer]
    let onTapSlot: (FormationSlot) -> Void
    let onDrop: (String, String) -> Void

    var body: some View {
        PitchView(aspectRatio: 0.72) { size in
            ForEach(formation.slots) { slot in
                BuilderSlotView(
                    slot: slot,
                    player: assignments[slot.id],
                    onTap: { onTapSlot(slot) }
                )
                .draggable(slot.id) {
                    BuilderSlotView(slot: slot, player: assignments[slot.id], onTap: {})
                        .opacity(0.9)
                }
                .dropDestination(for: String.self) { items, _ in
                    guard let source = items.first else { return false }
                    onDrop(source, slot.id)
                    return true
                }
                .position(PitchOrientation.full.screenPoint(for: slot.point, in: size))
            }
        }
    }
}

/// A single slot: empty circle with its position label, or the player who fills it.
struct BuilderSlotView: View {
    let slot: FormationSlot
    let player: CustomLineupPlayer?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 3) {
                ZStack(alignment: .topTrailing) {
                    Circle()
                        .fill(player == nil ? Color.black.opacity(0.28) : Color.white.opacity(0.94))
                        .frame(width: 38, height: 38)
                        .overlay {
                            Circle().strokeBorder(
                                player == nil ? Color.white.opacity(0.6) : Color.black.opacity(0.15),
                                style: StrokeStyle(lineWidth: player == nil ? 1.5 : 1, dash: player == nil ? [4, 3] : [])
                            )
                        }
                        .overlay {
                            if player == nil {
                                Text(slot.label)
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .minimumScaleFactor(0.7)
                                    .lineLimit(1)
                                    .padding(2)
                            } else {
                                Text(slot.label)
                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.black.opacity(0.75))
                            }
                        }

                    if let player {
                        RatingBadge(rating: player.playerRating, size: 20, showsBorder: false)
                            .offset(x: 9, y: -6)
                    }
                }

                if let player {
                    Text(player.playerName)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: 78)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.black.opacity(0.45)))
                    if let flag = player.flagEmoji {
                        Text(flag).font(.system(size: 10))
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(player?.playerName ?? "\(L10n.Builder.emptySlot) \(slot.label)")
        .accessibilityValue(player.map { L10n.Player.ratingValue(RatingScale.text(for: $0.playerRating)) } ?? "")
        .accessibilityHint(L10n.Builder.pickPlayer)
    }
}

/// Players that lost their slot when the formation changed.
struct UnplacedPlayersStrip: View {
    let players: [CustomLineupPlayer]
    let onSelect: (CustomLineupPlayer) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "Unplaced players", comment: "Section title"))
                .font(Theme.Typography.sectionTitle)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(players) { player in
                        Button {
                            onSelect(player)
                        } label: {
                            HStack(spacing: 8) {
                                PlayerAvatarView(url: player.playerPhoto, initials: player.initials, size: 28)
                                Text(player.playerName)
                                    .font(Theme.Typography.caption)
                                    .lineLimit(1)
                                RatingBadge(rating: player.playerRating, size: 22, showsBorder: false)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Theme.Palette.card))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

/// Average rating, total age and nationality breakdown for the current XI.
struct LineupSummaryCard: View {
    let averageRating: Double?
    let totalAge: Int
    let averageAge: Double?
    let nationalities: [NationalityCount]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                StatTile(title: L10n.Builder.teamAverageRating, value: RatingScale.text(for: averageRating))
                StatTile(title: L10n.Builder.totalAge, value: String(totalAge))
                StatTile(
                    title: L10n.Builder.averageAge,
                    value: averageAge.map { String(format: "%.1f", $0) }
                )
            }

            if nationalities.isEmpty == false {
                Text(L10n.Builder.nationalities)
                    .font(Theme.Typography.sectionTitle)
                FlowRow(items: nationalities) { entry in
                    Text("\(entry.flagEmoji ?? "") \(entry.label)")
                        .font(Theme.Typography.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Theme.Palette.cardElevated))
                }
            }
        }
        .cardStyle()
        .padding(.horizontal)
    }
}

/// Why a lineup could not be saved.
struct ValidationIssuesView: View {
    let issues: [CustomLineupIssue]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(issues) { issue in
                Label(issue.message, systemImage: "exclamationmark.triangle.fill")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Palette.warning)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .padding(.horizontal)
    }
}

/// Simple wrapping row of chips.
struct FlowRow<Item: Identifiable, Content: View>: View {
    private let items: [Item]
    private let content: (Item) -> Content

    init(items: [Item], @ViewBuilder content: @escaping (Item) -> Content) {
        self.items = items
        self.content = content
    }

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 6)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
            ForEach(items) { item in
                content(item)
            }
        }
    }
}

#Preview("Builder") {
    NavigationStack {
        LineupBuilderView(
            store: CustomLineupStore(stack: CoreDataStack(inMemory: true)),
            existing: MockData.customLineup
        )
    }
    .environment(AppContainer.preview())
}
