import SwiftUI

/// Read-only summary of a saved lineup: formation, the XI, and squad statistics.
struct CustomLineupDetailView: View {

    @Environment(AppContainer.self) private var container
    let lineup: CustomLineup

    @State private var shareCard: Image?
    @State private var playerSheet: PlayerSheetTarget?

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Layout.sectionSpacing) {
                if let formation = lineup.parsedFormation {
                    PitchView(aspectRatio: 0.72) { size in
                        ForEach(formation.slots) { slot in
                            BuilderSlotView(
                                slot: slot,
                                player: lineup.playersBySlot[slot.id],
                                onTap: {
                                    guard let player = lineup.playersBySlot[slot.id] else { return }
                                    playerSheet = PlayerSheetTarget(
                                        id: player.playerId,
                                        player: Player(custom: player),
                                        matchStats: nil
                                    )
                                }
                            )
                            .position(PitchOrientation.full.screenPoint(for: slot.point, in: size))
                        }
                    }
                    .padding(.horizontal)
                }

                LineupSummaryCard(
                    averageRating: lineup.averageRating,
                    totalAge: lineup.totalAge,
                    averageAge: lineup.averageAge,
                    nationalities: lineup.nationalityBreakdown
                )

                VStack(spacing: 10) {
                    ForEach(orderedPlayers) { player in
                        Button {
                            playerSheet = PlayerSheetTarget(
                                id: player.playerId,
                                player: Player(custom: player),
                                matchStats: nil
                            )
                        } label: {
                            HStack(spacing: 10) {
                                Text(player.positionSlot)
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .frame(width: 38, alignment: .leading)
                                    .foregroundStyle(Theme.Palette.accent)
                                PlayerCardView(customPlayer: player)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .cardStyle()
                .padding(.horizontal)
            }
            .padding(.vertical, 12)
        }
        .background(Theme.Palette.background)
        .navigationTitle(lineup.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let shareCard {
                    ShareLink(item: shareCard, preview: SharePreview(lineup.name, image: shareCard)) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .sheet(item: $playerSheet) { target in
            PlayerDetailView(player: target.player, service: container.service, store: container.store)
        }
        .task {
            guard let formation = lineup.parsedFormation else { return }
            shareCard = LineupImageRenderer.render(
                title: lineup.name,
                formation: formation,
                assignments: lineup.playersBySlot,
                averageRating: lineup.averageRating
            )
        }
    }

    private var orderedPlayers: [CustomLineupPlayer] {
        guard let formation = lineup.parsedFormation else { return lineup.players }
        let bySlot = lineup.playersBySlot
        return formation.slots.compactMap { bySlot[$0.id] }
    }
}

#Preview("Lineup detail") {
    NavigationStack {
        CustomLineupDetailView(lineup: MockData.customLineup)
    }
    .environment(AppContainer.preview())
}
