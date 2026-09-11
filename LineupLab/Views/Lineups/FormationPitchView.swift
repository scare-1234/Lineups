import SwiftUI

/// Where a team is drawn on the pitch.
enum PitchOrientation: Sendable {
    /// One team using the whole pitch, attacking upwards (the builder).
    case full
    /// Home team in the bottom half, attacking upwards.
    case bottomHalf
    /// Away team in the top half, attacking downwards.
    case topHalf

    /// Maps a normalised formation point (x left→right, y own goal→opponent goal)
    /// onto the pitch in view coordinates.
    func screenPoint(for point: CGPoint, in size: CGSize) -> CGPoint {
        switch self {
        case .full:
            CGPoint(x: point.x * size.width, y: (0.965 - point.y * 0.93) * size.height)
        case .bottomHalf:
            CGPoint(x: point.x * size.width, y: (0.985 - point.y * 0.47) * size.height)
        case .topHalf:
            CGPoint(x: (1 - point.x) * size.width, y: (0.015 + point.y * 0.47) * size.height)
        }
    }
}

/// The green surface: gradient, mown stripes and white markings.
struct PitchSurface: View {
    var showsStripes = true

    var body: some View {
        Canvas { context, size in
            let base = CGRect(origin: .zero, size: size)
            context.fill(Path(base), with: .linearGradient(
                Gradient(colors: [Theme.Palette.pitch, Theme.Palette.pitchDark]),
                startPoint: CGPoint(x: 0, y: 0),
                endPoint: CGPoint(x: 0, y: size.height)
            ))

            if showsStripes {
                let stripeHeight = size.height / 10
                for index in stride(from: 0, to: 10, by: 2) {
                    let rect = CGRect(x: 0, y: CGFloat(index) * stripeHeight, width: size.width, height: stripeHeight)
                    context.fill(Path(rect), with: .color(Color.white.opacity(0.035)))
                }
            }

            let shading = GraphicsContext.Shading.color(Color.white.opacity(0.55))
            let lineWidth = max(1, size.width * 0.005)
            let inset = size.width * 0.035
            let field = base.insetBy(dx: inset, dy: inset)

            context.stroke(Path(field), with: shading, lineWidth: lineWidth)

            var halfway = Path()
            halfway.move(to: CGPoint(x: field.minX, y: field.midY))
            halfway.addLine(to: CGPoint(x: field.maxX, y: field.midY))
            context.stroke(halfway, with: shading, lineWidth: lineWidth)

            let radius = field.width * 0.15
            let circle = CGRect(
                x: field.midX - radius,
                y: field.midY - radius,
                width: radius * 2,
                height: radius * 2
            )
            context.stroke(Path(ellipseIn: circle), with: shading, lineWidth: lineWidth)
            context.fill(
                Path(ellipseIn: CGRect(x: field.midX - lineWidth, y: field.midY - lineWidth, width: lineWidth * 2, height: lineWidth * 2)),
                with: shading
            )

            let boxWidth = field.width * 0.46
            let boxHeight = field.height * 0.14
            let sixWidth = field.width * 0.22
            let sixHeight = field.height * 0.06

            for isTop in [true, false] {
                let boxY = isTop ? field.minY : field.maxY - boxHeight
                let box = CGRect(x: field.midX - boxWidth / 2, y: boxY, width: boxWidth, height: boxHeight)
                context.stroke(Path(box), with: shading, lineWidth: lineWidth)

                let sixY = isTop ? field.minY : field.maxY - sixHeight
                let six = CGRect(x: field.midX - sixWidth / 2, y: sixY, width: sixWidth, height: sixHeight)
                context.stroke(Path(six), with: shading, lineWidth: lineWidth)
            }
        }
        .accessibilityHidden(true)
    }
}

/// Pitch container. Children position themselves with `PitchOrientation.screenPoint(for:in:)`.
struct PitchView<Content: View>: View {
    private let aspectRatio: CGFloat
    private let showsStripes: Bool
    private let content: (CGSize) -> Content

    init(
        aspectRatio: CGFloat = Theme.Layout.pitchAspectRatio,
        showsStripes: Bool = true,
        @ViewBuilder content: @escaping (CGSize) -> Content
    ) {
        self.aspectRatio = aspectRatio
        self.showsStripes = showsStripes
        self.content = content
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                PitchSurface(showsStripes: showsStripes)
                content(proxy.size)
            }
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Layout.cornerRadius, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L10n.A11y.pitch)
    }
}

/// A player token on the pitch: shirt number, name and colour-coded rating.
struct PitchPlayerMarker: View {
    let number: Int?
    let name: String
    let rating: Double?
    var accent: Color = .white
    var diameter: CGFloat = 34
    var isCompact = false

    var body: some View {
        VStack(spacing: 3) {
            ZStack(alignment: .topTrailing) {
                Circle()
                    .fill(accent.opacity(0.92))
                    .frame(width: diameter, height: diameter)
                    .overlay {
                        Text(number.map(String.init) ?? "–")
                            .font(.system(size: diameter * 0.42, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.black.opacity(0.8))
                    }
                    .overlay {
                        Circle().strokeBorder(Color.black.opacity(0.18), lineWidth: 1)
                    }

                if isCompact == false {
                    RatingBadge(rating: rating, size: diameter * 0.55, showsBorder: false)
                        .offset(x: diameter * 0.28, y: -diameter * 0.16)
                }
            }

            if isCompact == false {
                Text(shortName)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(Color.black.opacity(0.42)))
                    .frame(maxWidth: diameter * 2.4)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(name)
        .accessibilityValue(L10n.Player.ratingValue(RatingScale.text(for: rating)))
    }

    /// "Rafael Moreno" → "R. Moreno" so names fit on the pitch.
    private var shortName: String {
        let parts = name.split(separator: " ")
        guard parts.count > 1, let first = parts.first?.first else { return name }
        return "\(first). \(parts.dropFirst().joined(separator: " "))"
    }
}

/// Tiny pitch preview used by the formation picker and saved lineup cards.
struct FormationMiniPitch: View {
    let formation: Formation
    var dotSize: CGFloat = 7
    var tint: Color = Theme.Palette.accent

    var body: some View {
        PitchView(aspectRatio: 0.78, showsStripes: false) { size in
            ForEach(formation.slots) { slot in
                Circle()
                    .fill(tint)
                    .frame(width: dotSize, height: dotSize)
                    .position(PitchOrientation.full.screenPoint(for: slot.point, in: size))
            }
        }
        .accessibilityLabel(formation.name)
    }
}

#Preview("Pitch") {
    let lineup = MockData.homeLineup
    let points = lineup.startingPoints

    return ScrollView {
        VStack(spacing: 16) {
            PitchView { size in
                ForEach(Array(lineup.startXI.enumerated()), id: \.element.id) { index, player in
                    PitchPlayerMarker(
                        number: player.number,
                        name: player.player.name,
                        rating: player.rating
                    )
                    .position(PitchOrientation.full.screenPoint(
                        for: points.indices.contains(index) ? points[index] : CGPoint(x: 0.5, y: 0.5),
                        in: size
                    ))
                }
            }
            HStack(spacing: 12) {
                ForEach(FormationParser.supported.prefix(3)) { formation in
                    FormationMiniPitch(formation: formation)
                }
            }
        }
        .padding()
    }
    .background(Theme.Palette.background)
}
