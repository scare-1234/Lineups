import SwiftUI

/// Thin banner explaining that what is on screen came from the cache.
struct DataBannerView: View {
    let banner: DataBanner

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: banner.systemImage)
            Text(banner.message)
                .font(Theme.Typography.caption)
            Spacer(minLength: 0)
            Text(banner.storedAt.kickoffString)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Palette.secondaryText)
        }
        .foregroundStyle(Theme.Palette.warning)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Palette.warning.opacity(0.12), in: RoundedRectangle(cornerRadius: Theme.Layout.smallCornerRadius))
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
    }
}

/// Friendly empty state with an SF Symbol illustration.
struct EmptyStateView: View {
    let title: String
    let message: String
    var systemImage: String = "sportscourt"
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(message)
        } actions: {
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.Palette.accent)
            }
        }
    }
}

/// Error state that knows the difference between "try again" and "go set up your API key".
struct ErrorStateView: View {
    let error: APIError
    var retry: (() -> Void)?

    var body: some View {
        if error.needsSetup {
            SetupInstructionsView(message: error.errorDescription ?? L10n.Setup.title)
        } else {
            ContentUnavailableView {
                Label(L10n.Errors.genericTitle, systemImage: "exclamationmark.triangle")
            } description: {
                Text(error.errorDescription ?? L10n.Errors.genericTitle)
            } actions: {
                if let retry {
                    Button(L10n.Common.retry, action: retry)
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.Palette.accent)
                }
            }
        }
    }
}

/// Shown when `Configuration.plist` has no usable API key.
struct SetupInstructionsView: View {
    var message: String = L10n.Setup.title

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Layout.sectionSpacing) {
                Label(L10n.Setup.title, systemImage: "key.horizontal")
                    .font(Theme.Typography.title)
                    .foregroundStyle(Theme.Palette.accent)

                Text(message)
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Palette.primaryText)

                Text(L10n.Setup.instructions)
                    .font(Theme.Typography.callout)
                    .foregroundStyle(Theme.Palette.secondaryText)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()
            .padding()
        }
    }
}

/// Horizontal filter chip.
struct FilterChip: View {
    let title: String
    let isSelected: Bool
    var systemImage: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage).font(.caption)
                }
                Text(title)
                    .font(Theme.Typography.captionEmphasis)
                    .lineLimit(1)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(isSelected ? Theme.Palette.accent : Theme.Palette.card)
            )
            .foregroundStyle(isSelected ? Color.black : Theme.Palette.primaryText)
            .overlay {
                Capsule().strokeBorder(Theme.Palette.separator, lineWidth: isSelected ? 0 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// Pulsing dot used for live matches.
struct LiveIndicator: View {
    @State private var isPulsing = false

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(Theme.Palette.live)
                .frame(width: 7, height: 7)
                .scaleEffect(isPulsing ? 1.35 : 0.85)
                .opacity(isPulsing ? 1 : 0.55)
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.75).repeatForever(autoreverses: true)) {
                        isPulsing = true
                    }
                }
            Text(L10n.Matches.live)
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(Theme.Palette.live)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.A11y.liveMatch)
    }
}

/// Status badge: LIVE / FT / NS / PST.
struct StatusBadge: View {
    let fixture: Fixture

    var body: some View {
        switch fixture.kind {
        case .live, .halfTime:
            LiveIndicator()
        default:
            Text(fixture.kind.badgeText(apiStatus: fixture.status, elapsed: fixture.elapsed))
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.Palette.secondaryText)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Capsule().fill(Theme.Palette.cardElevated))
        }
    }
}

#Preview("State views") {
    ScrollView {
        VStack(spacing: 20) {
            DataBannerView(banner: .offline(storedAt: Date()))
            FilterChip(title: "Premier League", isSelected: true) {}
            FilterChip(title: "La Liga", isSelected: false) {}
            StatusBadge(fixture: MockData.liveFixture)
            StatusBadge(fixture: MockData.finishedFixture)
            EmptyStateView(title: L10n.Matches.emptyTitle, message: L10n.Matches.emptyMessage)
            ErrorStateView(error: .rateLimited) {}
        }
        .padding()
    }
    .background(Theme.Palette.background)
}
