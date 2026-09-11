import SwiftUI

/// Shimmering skeleton placeholder — used instead of a spinner while data loads.
struct ShimmerView: View {
    var cornerRadius: CGFloat = Theme.Layout.smallCornerRadius

    @State private var phase: CGFloat = -1

    var body: some View {
        GeometryReader { proxy in
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Theme.Palette.cardElevated)
                .overlay {
                    LinearGradient(
                        colors: [.clear, Color.white.opacity(0.18), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: proxy.size.width * 0.6)
                    .offset(x: phase * proxy.size.width * 1.6)
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        .onAppear {
            withAnimation(.linear(duration: 1.3).repeatForever(autoreverses: false)) {
                phase = 1
            }
        }
        .accessibilityHidden(true)
    }
}

/// Skeleton list used by the match list and search results.
struct LoadingView: View {
    var rows: Int = 6
    var rowHeight: CGFloat = 62

    var body: some View {
        VStack(spacing: Theme.Layout.rowSpacing) {
            ForEach(0..<rows, id: \.self) { _ in
                ShimmerView(cornerRadius: Theme.Layout.cornerRadius)
                    .frame(height: rowHeight)
            }
        }
        .padding(.horizontal)
        .accessibilityLabel(L10n.Common.loading)
    }
}

/// Skeleton shaped like the pitch, for the lineups tab.
struct LoadingPitchView: View {
    var body: some View {
        VStack(spacing: Theme.Layout.rowSpacing) {
            ShimmerView(cornerRadius: Theme.Layout.cornerRadius)
                .aspectRatio(Theme.Layout.pitchAspectRatio, contentMode: .fit)
            ForEach(0..<3, id: \.self) { _ in
                ShimmerView().frame(height: 44)
            }
        }
        .padding(.horizontal)
        .accessibilityLabel(L10n.Common.loading)
    }
}

#Preview("Loading") {
    ScrollView {
        LoadingView()
        LoadingPitchView()
    }
    .background(Theme.Palette.background)
}
