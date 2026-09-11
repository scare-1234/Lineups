import SwiftUI

/// One player row: photo, name, nationality flag, age, position and colour-coded rating.
struct PlayerCardView: View {
    let name: String
    let nationality: String
    let age: Int
    let position: String?
    let rating: Double?
    let photo: URL?
    let club: String?
    var number: Int?
    var isCaptain = false

    var body: some View {
        HStack(spacing: 12) {
            if let number {
                Text(String(number))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Palette.secondaryText)
                    .frame(width: 22)
            }

            PlayerAvatarView(url: photo, initials: initials)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(name)
                        .font(Theme.Typography.bodyEmphasis)
                        .foregroundStyle(Theme.Palette.primaryText)
                        .lineLimit(1)
                    if isCaptain {
                        Text("C")
                            .font(.system(size: 9, weight: .black))
                            .foregroundStyle(Color.black)
                            .padding(3)
                            .background(Circle().fill(Theme.Palette.warning))
                    }
                }

                HStack(spacing: 6) {
                    Text(NationalityFlag.label(for: nationality))
                        .lineLimit(1)
                    Text("·")
                    Text(String(age))
                    if let position, position.isEmpty == false {
                        Text("·")
                        Text(position).lineLimit(1)
                    }
                }
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Palette.secondaryText)

                if let club, club.isEmpty == false {
                    Text(club)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Palette.secondaryText)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 4)

            RatingBadge(rating: rating)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name), \(nationality), \(L10n.Player.age(age))")
        .accessibilityValue(L10n.Player.ratingValue(RatingScale.text(for: rating)))
    }

    private var initials: String {
        name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
    }
}

extension PlayerCardView {
    init(player: Player, number: Int? = nil) {
        self.init(
            name: player.name,
            nationality: player.nationality,
            age: player.age,
            position: player.pitchRole?.displayName ?? player.position,
            rating: player.rating,
            photo: player.photo,
            club: player.clubTeam,
            number: number
        )
    }

    init(lineupPlayer: LineupPlayer) {
        self.init(
            name: lineupPlayer.player.name,
            nationality: lineupPlayer.player.nationality,
            age: lineupPlayer.player.age,
            position: lineupPlayer.role?.displayName ?? lineupPlayer.position,
            rating: lineupPlayer.rating,
            photo: lineupPlayer.player.photo,
            club: lineupPlayer.player.clubTeam,
            number: lineupPlayer.number,
            isCaptain: lineupPlayer.matchStats?.isCaptain ?? false
        )
    }

    init(customPlayer: CustomLineupPlayer) {
        self.init(
            name: customPlayer.playerName,
            nationality: customPlayer.playerNationality,
            age: customPlayer.playerAge,
            position: customPlayer.role?.displayName ?? customPlayer.playerPosition,
            rating: customPlayer.playerRating,
            photo: customPlayer.playerPhoto,
            club: customPlayer.playerClub
        )
    }
}

#Preview("Player cards") {
    VStack(spacing: 12) {
        PlayerCardView(player: MockData.featuredPlayer)
        PlayerCardView(lineupPlayer: MockData.homeLineup.startXI[0])
        PlayerCardView(customPlayer: MockData.customLineup.players[0])
    }
    .padding()
    .background(Theme.Palette.background)
}
