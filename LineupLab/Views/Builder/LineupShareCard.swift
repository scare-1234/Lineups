import SwiftUI

/// The card rendered to an image when a lineup is shared.
struct LineupShareCard: View {
    let title: String
    let formation: Formation
    let assignments: [String: CustomLineupPlayer]
    let averageRating: Double?

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: "soccerball")
                Text(title)
                    .font(.system(size: 20, weight: .bold))
                Spacer()
                Text(formation.name)
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
            }
            .foregroundStyle(.white)

            PitchView(aspectRatio: 0.72) { size in
                ForEach(formation.slots) { slot in
                    if let player = assignments[slot.id] {
                        PitchPlayerMarker(
                            number: nil,
                            name: player.playerName,
                            rating: player.playerRating,
                            diameter: 30
                        )
                        .position(PitchOrientation.full.screenPoint(for: slot.point, in: size))
                    } else {
                        Circle()
                            .strokeBorder(Color.white.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                            .frame(width: 30, height: 30)
                            .position(PitchOrientation.full.screenPoint(for: slot.point, in: size))
                    }
                }
            }

            HStack {
                Text(L10n.App.name)
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text("\(L10n.Builder.teamAverageRating) \(RatingScale.text(for: averageRating))")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(.white.opacity(0.8))
        }
        .padding(16)
        .frame(width: 420)
        .background(Theme.Palette.pitchDark)
    }
}

/// Renders a lineup to a shareable image.
enum LineupImageRenderer {
    @MainActor
    static func render(
        title: String,
        formation: Formation,
        assignments: [String: CustomLineupPlayer],
        averageRating: Double?,
        scale: CGFloat = 3
    ) -> Image? {
        let card = LineupShareCard(
            title: title,
            formation: formation,
            assignments: assignments,
            averageRating: averageRating
        )
        let renderer = ImageRenderer(content: card)
        renderer.scale = scale
        #if canImport(UIKit)
        guard let uiImage = renderer.uiImage else { return nil }
        return Image(uiImage: uiImage)
        #else
        return nil
        #endif
    }
}

#Preview("Share card") {
    LineupShareCard(
        title: "Dream XI",
        formation: FormationParser.defaultFormation,
        assignments: MockData.customLineup.playersBySlot,
        averageRating: MockData.customLineup.averageRating
    )
}
