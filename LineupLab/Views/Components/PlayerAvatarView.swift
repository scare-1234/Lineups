import SwiftUI

/// Circular player photo with a silhouette + initials placeholder when the photo is missing.
struct PlayerAvatarView: View {
    let url: URL?
    var initials: String = ""
    var size: CGFloat = Theme.Layout.avatarSize

    var body: some View {
        Group {
            if let url {
                AsyncImage(url: url, transaction: Transaction(animation: .easeInOut(duration: 0.2))) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        placeholder
                    case .empty:
                        placeholder.overlay { ProgressView().controlSize(.mini) }
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay { Circle().strokeBorder(Color.white.opacity(0.18), lineWidth: 1) }
        .accessibilityHidden(true)
    }

    private var placeholder: some View {
        ZStack {
            Circle().fill(Theme.Palette.cardElevated)
            if initials.isEmpty {
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.45))
                    .foregroundStyle(Theme.Palette.secondaryText)
            } else {
                Text(initials)
                    .font(.system(size: size * 0.38, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.Palette.secondaryText)
            }
        }
    }
}

/// Team crest with an initials fallback.
struct TeamLogoView: View {
    let team: Team
    var size: CGFloat = 28

    var body: some View {
        Group {
            if let logo = team.logo {
                AsyncImage(url: logo) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    initialsView
                }
            } else {
                initialsView
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private var initialsView: some View {
        Text(team.initials)
            .font(.system(size: size * 0.4, weight: .bold, design: .rounded))
            .foregroundStyle(Theme.Palette.secondaryText)
            .frame(width: size, height: size)
            .background(Circle().fill(Theme.Palette.cardElevated))
    }
}

#Preview("Avatars") {
    HStack(spacing: 16) {
        PlayerAvatarView(url: nil, initials: "RM")
        PlayerAvatarView(url: nil, initials: "", size: 56)
        TeamLogoView(team: MockData.homeTeam, size: 40)
    }
    .padding()
    .background(Theme.Palette.background)
}
