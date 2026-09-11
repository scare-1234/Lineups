import SwiftUI

/// Events tab: a chronological timeline of goals, cards and substitutions.
struct MatchEventsView: View {
    let events: [MatchEvent]
    let homeTeamID: Int

    var body: some View {
        VStack(spacing: 0) {
            ForEach(events) { event in
                MatchEventRow(event: event, isHome: event.teamId == homeTeamID)
                if event.id != events.last?.id {
                    Divider()
                        .overlay(Theme.Palette.separator)
                        .padding(.leading, 56)
                }
            }
        }
        .cardStyle(padding: 0)
        .padding(.horizontal)
    }
}

struct MatchEventRow: View {
    let event: MatchEvent
    let isHome: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(event.minuteLabel)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.Palette.secondaryText)
                .frame(width: 42, alignment: .leading)

            Text(event.kind.symbol)
                .font(.system(size: 16))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.playerName ?? event.teamName)
                    .font(Theme.Typography.bodyEmphasis)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(event.detail)
                    if let assist = event.assistName, assist.isEmpty == false {
                        Text("·")
                        Text(assist).lineLimit(1)
                    }
                }
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Palette.secondaryText)
            }

            Spacer(minLength: 4)

            Text(event.teamName)
                .font(Theme.Typography.caption)
                .foregroundStyle(isHome ? Theme.Palette.accent : Theme.Palette.secondaryText)
                .lineLimit(1)
                .frame(maxWidth: 92, alignment: .trailing)
        }
        .padding(.horizontal, Theme.Layout.cardPadding)
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }
}

#Preview("Events") {
    ScrollView {
        MatchEventsView(events: MockData.events, homeTeamID: MockData.homeTeam.id)
            .padding(.vertical)
    }
    .background(Theme.Palette.background)
}
