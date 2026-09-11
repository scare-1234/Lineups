import Foundation

/// The football data API surface the app talks to.
/// ViewModels depend on this protocol, never on the concrete implementation.
protocol FootballAPIServicing: Sendable {
    func fixtures(on date: Date, leagueID: Int?) async throws -> APIResponse<[Fixture]>
    func fixture(id: Int) async throws -> APIResponse<Fixture>
    func lineups(fixtureID: Int) async throws -> APIResponse<MatchLineups>
    func playerMatchStats(fixtureID: Int) async throws -> APIResponse<[Int: PlayerMatchStats]>
    func events(fixtureID: Int) async throws -> APIResponse<[MatchEvent]>
    func statistics(fixtureID: Int) async throws -> APIResponse<[TeamMatchStatistics]>
    func player(id: Int, season: Int?) async throws -> APIResponse<Player>
    func searchPlayers(named name: String, season: Int?) async throws -> APIResponse<[Player]>
    func league(id: Int, season: Int?) async throws -> APIResponse<League>
    func standings(leagueID: Int, season: Int?) async throws -> APIResponse<[StandingRow]>
    func nationalTeams(country: String) async throws -> APIResponse<[Team]>
    func squad(teamID: Int) async throws -> APIResponse<[Player]>
    func recentFixtures(leagueID: Int, season: Int?, last: Int) async throws -> APIResponse<[Fixture]>
}

/// API-Football (api-sports.io) implementation.
///
/// Endpoint reference: https://www.api-football.com/documentation-v3
struct FootballAPIService: FootballAPIServicing {

    private let client: APIClientProtocol
    private let defaultSeason: Int

    init(client: APIClientProtocol, defaultSeason: Int) {
        self.client = client
        self.defaultSeason = defaultSeason
    }

    // MARK: - Fixtures

    /// `GET /fixtures?date=2026-09-11`
    func fixtures(on date: Date, leagueID: Int? = nil) async throws -> APIResponse<[Fixture]> {
        var items = [URLQueryItem(name: "date", value: date.apiDayString)]
        if let leagueID {
            items.append(URLQueryItem(name: "league", value: String(leagueID)))
            items.append(URLQueryItem(name: "season", value: String(defaultSeason)))
        }
        let endpoint = Endpoint(path: "fixtures", queryItems: items, freshness: .live)
        let response: APIResponse<APIEnvelope<FixtureItemDTO>> = try await client.fetch(endpoint)
        return response.map { envelope in
            envelope.response.compactMap(FootballAPIService.makeFixture(from:))
                .sorted { $0.date < $1.date }
        }
    }

    /// `GET /fixtures?id={fixtureId}`
    func fixture(id: Int) async throws -> APIResponse<Fixture> {
        let endpoint = Endpoint(
            path: "fixtures",
            queryItems: [URLQueryItem(name: "id", value: String(id))],
            freshness: .live
        )
        let response: APIResponse<APIEnvelope<FixtureItemDTO>> = try await client.fetch(endpoint)
        guard let fixture = response.value.response.compactMap(FootballAPIService.makeFixture(from:)).first else {
            throw APIError.empty
        }
        return APIResponse(value: fixture, source: response.source)
    }

    /// `GET /fixtures?league={id}&season={season}&last={n}`
    func recentFixtures(leagueID: Int, season: Int? = nil, last: Int = 15) async throws -> APIResponse<[Fixture]> {
        let endpoint = Endpoint(
            path: "fixtures",
            queryItems: [
                URLQueryItem(name: "league", value: String(leagueID)),
                URLQueryItem(name: "season", value: String(season ?? defaultSeason)),
                URLQueryItem(name: "last", value: String(last))
            ],
            freshness: .live
        )
        let response: APIResponse<APIEnvelope<FixtureItemDTO>> = try await client.fetch(endpoint)
        return response.map { envelope in
            envelope.response.compactMap(FootballAPIService.makeFixture(from:))
                .sorted { $0.date > $1.date }
        }
    }

    // MARK: - Lineups and ratings

    /// `GET /fixtures/lineups?fixture={fixtureId}`
    func lineups(fixtureID: Int) async throws -> APIResponse<MatchLineups> {
        let endpoint = Endpoint(
            path: "fixtures/lineups",
            queryItems: [URLQueryItem(name: "fixture", value: String(fixtureID))],
            freshness: .live
        )
        let response: APIResponse<APIEnvelope<LineupItemDTO>> = try await client.fetch(endpoint)
        return response.map { envelope in
            let lineups = envelope.response.compactMap(FootballAPIService.makeLineup(from:))
            return MatchLineups(home: lineups.first, away: lineups.dropFirst().first)
        }
    }

    /// `GET /fixtures/players?fixture={fixtureId}` — the source of `games.rating`.
    func playerMatchStats(fixtureID: Int) async throws -> APIResponse<[Int: PlayerMatchStats]> {
        let endpoint = Endpoint(
            path: "fixtures/players",
            queryItems: [URLQueryItem(name: "fixture", value: String(fixtureID))],
            freshness: .live
        )
        let response: APIResponse<APIEnvelope<FixturePlayersItemDTO>> = try await client.fetch(endpoint)
        return response.map { envelope in
            var result: [Int: PlayerMatchStats] = [:]
            for team in envelope.response {
                for entry in team.players ?? [] {
                    guard let id = entry.player.id,
                          let stats = FootballAPIService.makeMatchStats(playerId: id, from: entry.statistics?.first) else { continue }
                    result[id] = stats
                }
            }
            return result
        }
    }

    /// `GET /fixtures/events?fixture={fixtureId}`
    func events(fixtureID: Int) async throws -> APIResponse<[MatchEvent]> {
        let endpoint = Endpoint(
            path: "fixtures/events",
            queryItems: [URLQueryItem(name: "fixture", value: String(fixtureID))],
            freshness: .live
        )
        let response: APIResponse<APIEnvelope<EventItemDTO>> = try await client.fetch(endpoint)
        return response.map { envelope in
            envelope.response.enumerated().compactMap { index, dto in
                FootballAPIService.makeEvent(from: dto, index: index)
            }
            .sorted { lhs, rhs in
                if lhs.minute != rhs.minute { return lhs.minute < rhs.minute }
                return (lhs.extraMinute ?? 0) < (rhs.extraMinute ?? 0)
            }
        }
    }

    /// `GET /fixtures/statistics?fixture={fixtureId}`
    func statistics(fixtureID: Int) async throws -> APIResponse<[TeamMatchStatistics]> {
        let endpoint = Endpoint(
            path: "fixtures/statistics",
            queryItems: [URLQueryItem(name: "fixture", value: String(fixtureID))],
            freshness: .live
        )
        let response: APIResponse<APIEnvelope<TeamStatisticsItemDTO>> = try await client.fetch(endpoint)
        return response.map { envelope in
            envelope.response.compactMap { dto -> TeamMatchStatistics? in
                guard let id = dto.team.id else { return nil }
                var values: [String: String] = [:]
                for entry in dto.statistics ?? [] {
                    guard let type = entry.type, let value = entry.value?.value else { continue }
                    values[type] = value
                }
                return TeamMatchStatistics(teamId: id, teamName: dto.team.name ?? "", values: values)
            }
        }
    }

    // MARK: - Players

    /// `GET /players?id={playerId}&season={season}`
    func player(id: Int, season: Int? = nil) async throws -> APIResponse<Player> {
        let endpoint = Endpoint(
            path: "players",
            queryItems: [
                URLQueryItem(name: "id", value: String(id)),
                URLQueryItem(name: "season", value: String(season ?? defaultSeason))
            ],
            freshness: .reference
        )
        let response: APIResponse<APIEnvelope<PlayerProfileItemDTO>> = try await client.fetch(endpoint)
        guard let dto = response.value.response.first else { throw APIError.empty }
        return APIResponse(value: FootballAPIService.makePlayer(from: dto), source: response.source)
    }

    /// `GET /players?search={name}&season={season}` — searches the whole database,
    /// which is what the builder needs: any player, any league, any nationality.
    func searchPlayers(named name: String, season: Int? = nil) async throws -> APIResponse<[Player]> {
        let query = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= AppConstants.minimumSearchLength else {
            return APIResponse(value: [], source: .network)
        }
        let endpoint = Endpoint(
            path: "players",
            queryItems: [
                URLQueryItem(name: "search", value: query),
                URLQueryItem(name: "season", value: String(season ?? defaultSeason))
            ],
            freshness: .reference
        )
        let response: APIResponse<APIEnvelope<PlayerProfileItemDTO>> = try await client.fetch(endpoint)
        return response.map { envelope in
            envelope.response.map(FootballAPIService.makePlayer(from:))
        }
    }

    /// `GET /players/squads?team={teamId}` — national team (or club) squad list.
    func squad(teamID: Int) async throws -> APIResponse<[Player]> {
        let endpoint = Endpoint(
            path: "players/squads",
            queryItems: [URLQueryItem(name: "team", value: String(teamID))],
            freshness: .reference
        )
        let response: APIResponse<APIEnvelope<SquadItemDTO>> = try await client.fetch(endpoint)
        return response.map { envelope in
            guard let item = envelope.response.first else { return [] }
            let country = item.team.country ?? item.team.name ?? ""
            return (item.players ?? []).compactMap { dto in
                FootballAPIService.makePlayer(from: dto, teamName: item.team.name, nationality: country)
            }
        }
    }

    // MARK: - Leagues

    /// `GET /leagues?id={leagueId}&season={season}`
    func league(id: Int, season: Int? = nil) async throws -> APIResponse<League> {
        let endpoint = Endpoint(
            path: "leagues",
            queryItems: [
                URLQueryItem(name: "id", value: String(id)),
                URLQueryItem(name: "season", value: String(season ?? defaultSeason))
            ],
            freshness: .reference
        )
        let response: APIResponse<APIEnvelope<LeagueItemDTO>> = try await client.fetch(endpoint)
        guard let dto = response.value.response.first else { throw APIError.empty }
        let league = League(
            id: dto.league.id ?? id,
            name: dto.league.name ?? "",
            country: dto.country?.name ?? dto.league.country ?? "",
            logo: FootballAPIService.url(dto.league.logo),
            season: dto.seasons?.first(where: { $0.current == true })?.year ?? (season ?? defaultSeason),
            type: dto.league.type ?? "League",
            flag: FootballAPIService.url(dto.country?.flag ?? dto.league.flag)
        )
        return APIResponse(value: league, source: response.source)
    }

    /// `GET /standings?league={id}&season={season}`
    func standings(leagueID: Int, season: Int? = nil) async throws -> APIResponse<[StandingRow]> {
        let endpoint = Endpoint(
            path: "standings",
            queryItems: [
                URLQueryItem(name: "league", value: String(leagueID)),
                URLQueryItem(name: "season", value: String(season ?? defaultSeason))
            ],
            freshness: .reference
        )
        let response: APIResponse<APIEnvelope<StandingsItemDTO>> = try await client.fetch(endpoint)
        return response.map { envelope in
            let groups = envelope.response.first?.league.standings ?? []
            return groups.flatMap { $0 }.compactMap(FootballAPIService.makeStandingRow(from:))
        }
    }

    /// `GET /teams?country={country}` filtered down to national teams.
    func nationalTeams(country: String) async throws -> APIResponse<[Team]> {
        let endpoint = Endpoint(
            path: "teams",
            queryItems: [URLQueryItem(name: "country", value: country)],
            freshness: .reference
        )
        let response: APIResponse<APIEnvelope<TeamsSearchItemDTO>> = try await client.fetch(endpoint)
        return response.map { envelope in
            envelope.response
                .compactMap { FootballAPIService.makeTeam(from: $0.team) }
                .filter(\.isNational)
        }
    }
}

/// `GET /teams` wraps each team in `{ team, venue }`.
struct TeamsSearchItemDTO: Decodable, Sendable {
    let team: TeamDTO
    let venue: VenueDTO?
}

// MARK: - DTO → domain mapping

extension FootballAPIService {

    static func url(_ string: String?) -> URL? {
        guard let string, string.isEmpty == false else { return nil }
        return URL(string: string)
    }

    static func makeTeam(from dto: TeamDTO?) -> Team? {
        guard let dto, let id = dto.id else { return nil }
        return Team(
            id: id,
            name: dto.name ?? "",
            logo: url(dto.logo),
            country: dto.country,
            isNational: dto.national ?? false
        )
    }

    static func makeLeague(from dto: LeagueDTO, fallbackSeason: Int = 0) -> League {
        League(
            id: dto.id ?? 0,
            name: dto.name ?? "",
            country: dto.country ?? "",
            logo: url(dto.logo),
            season: dto.season?.value ?? fallbackSeason,
            type: dto.type ?? "League",
            flag: url(dto.flag),
            round: dto.round
        )
    }

    static func makeFixture(from dto: FixtureItemDTO) -> Fixture? {
        guard let home = makeTeam(from: dto.teams.home),
              let away = makeTeam(from: dto.teams.away) else { return nil }
        return Fixture(
            id: dto.fixture.id,
            date: dto.fixture.date,
            status: dto.fixture.status?.short ?? "NS",
            homeTeam: home,
            awayTeam: away,
            homeScore: dto.goals?.home,
            awayScore: dto.goals?.away,
            league: makeLeague(from: dto.league),
            venue: dto.fixture.venue?.name,
            venueCity: dto.fixture.venue?.city,
            referee: dto.fixture.referee,
            elapsed: dto.fixture.status?.elapsed,
            statusDescription: dto.fixture.status?.long
        )
    }

    static func makeLineup(from dto: LineupItemDTO) -> MatchLineup? {
        guard let team = makeTeam(from: dto.team) else { return nil }
        return MatchLineup(
            team: team,
            formation: dto.formation ?? "",
            startXI: (dto.startXI ?? []).compactMap { makeLineupPlayer(from: $0, isStarting: true) },
            substitutes: (dto.substitutes ?? []).compactMap { makeLineupPlayer(from: $0, isStarting: false) },
            coachName: dto.coach?.name,
            coachPhoto: url(dto.coach?.photo)
        )
    }

    static func makeLineupPlayer(from dto: LineupEntryDTO, isStarting: Bool) -> LineupPlayer? {
        guard let id = dto.player.id else { return nil }
        let role = PitchRole(apiValue: dto.player.pos)
        let player = Player(
            id: id,
            name: dto.player.name ?? "",
            position: role?.rawValue ?? dto.player.pos
        )
        return LineupPlayer(
            player: player,
            number: dto.player.number ?? 0,
            position: dto.player.pos ?? "",
            grid: dto.player.grid,
            isStarting: isStarting
        )
    }

    static func makeMatchStats(playerId: Int, from dto: PlayerMatchStatsDTO?) -> PlayerMatchStats? {
        guard let dto else { return nil }
        return PlayerMatchStats(
            playerId: playerId,
            rating: dto.games?.rating?.value,
            minutes: dto.games?.minutes?.value,
            position: dto.games?.position,
            number: dto.games?.number?.value,
            isCaptain: dto.games?.captain ?? false,
            isSubstitute: dto.games?.substitute ?? false,
            goals: dto.goals?.total?.value,
            assists: dto.goals?.assists?.value,
            shotsTotal: dto.shots?.total?.value,
            shotsOn: dto.shots?.on?.value,
            passesTotal: dto.passes?.total?.value,
            passesKey: dto.passes?.key?.value,
            passAccuracy: dto.passes?.accuracy?.value,
            tacklesTotal: dto.tackles?.total?.value,
            blocks: dto.tackles?.blocks?.value,
            interceptions: dto.tackles?.interceptions?.value,
            duelsTotal: dto.duels?.total?.value,
            duelsWon: dto.duels?.won?.value,
            dribbleAttempts: dto.dribbles?.attempts?.value,
            dribbleSuccess: dto.dribbles?.success?.value,
            foulsDrawn: dto.fouls?.drawn?.value,
            foulsCommitted: dto.fouls?.committed?.value,
            yellowCards: dto.cards?.yellow?.value,
            redCards: dto.cards?.red?.value
        )
    }

    static func makePlayer(from dto: PlayerProfileItemDTO) -> Player {
        let stats = (dto.statistics ?? []).map(makeSeasonStats(from:))
        let primary = stats.max { ($0.minutes ?? 0) < ($1.minutes ?? 0) }
        return Player(
            id: dto.player.id,
            name: dto.player.name ?? "",
            firstName: dto.player.firstname,
            lastName: dto.player.lastname,
            age: dto.player.age ?? 0,
            nationality: dto.player.nationality ?? "",
            photo: url(dto.player.photo),
            height: dto.player.height,
            weight: dto.player.weight,
            position: primary?.position,
            rating: primary?.rating,
            clubTeam: primary?.teamName,
            birthDate: APIDateParsing.birthDate(from: dto.player.birth?.date),
            birthPlace: dto.player.birth?.place,
            birthCountry: dto.player.birth?.country,
            seasonStats: stats
        )
    }

    static func makePlayer(from dto: SquadPlayerDTO, teamName: String?, nationality: String) -> Player? {
        guard let id = dto.id else { return nil }
        let role = PitchRole(apiValue: dto.position)
        return Player(
            id: id,
            name: dto.name ?? "",
            age: dto.age ?? 0,
            nationality: nationality,
            photo: url(dto.photo),
            position: role?.rawValue ?? dto.position,
            clubTeam: teamName
        )
    }

    static func makeSeasonStats(from dto: PlayerSeasonStatsDTO) -> PlayerSeasonStats {
        PlayerSeasonStats(
            teamId: dto.team?.id,
            teamName: dto.team?.name,
            teamLogo: url(dto.team?.logo),
            leagueId: dto.league?.id,
            leagueName: dto.league?.name,
            season: dto.league?.season?.value,
            appearances: dto.games?.appearences?.value,
            lineups: dto.games?.lineups?.value,
            minutes: dto.games?.minutes?.value,
            goals: dto.goals?.total?.value,
            assists: dto.goals?.assists?.value,
            rating: dto.games?.rating?.value,
            position: dto.games?.position,
            yellowCards: dto.cards?.yellow?.value,
            redCards: dto.cards?.red?.value
        )
    }

    static func makeEvent(from dto: EventItemDTO, index: Int) -> MatchEvent? {
        guard let teamId = dto.team?.id else { return nil }
        return MatchEvent(
            id: "\(index)-\(teamId)-\(dto.time?.elapsed ?? 0)-\(dto.player?.id ?? 0)",
            minute: dto.time?.elapsed ?? 0,
            extraMinute: dto.time?.extra,
            teamId: teamId,
            teamName: dto.team?.name ?? "",
            teamLogo: url(dto.team?.logo),
            playerId: dto.player?.id,
            playerName: dto.player?.name,
            assistName: dto.assist?.name,
            type: dto.type ?? "",
            detail: dto.detail ?? "",
            comments: dto.comments
        )
    }

    static func makeStandingRow(from dto: StandingRowDTO) -> StandingRow? {
        guard let team = makeTeam(from: dto.team) else { return nil }
        return StandingRow(
            rank: dto.rank ?? 0,
            team: team,
            points: dto.points ?? 0,
            goalDifference: dto.goalsDiff ?? 0,
            played: dto.all?.played ?? 0,
            wins: dto.all?.win ?? 0,
            draws: dto.all?.draw ?? 0,
            losses: dto.all?.lose ?? 0,
            goalsFor: dto.all?.goals?.for ?? 0,
            goalsAgainst: dto.all?.goals?.against ?? 0,
            group: dto.group,
            form: dto.form
        )
    }

    /// Folds per-player match statistics (and therefore ratings) into a lineup.
    /// Pure function so it can be unit tested without touching the network.
    static func merge(lineups: MatchLineups, stats: [Int: PlayerMatchStats]) -> MatchLineups {
        MatchLineups(
            home: lineups.home.map { merge(lineup: $0, stats: stats) },
            away: lineups.away.map { merge(lineup: $0, stats: stats) }
        )
    }

    static func merge(lineup: MatchLineup, stats: [Int: PlayerMatchStats]) -> MatchLineup {
        var merged = lineup
        merged.startXI = lineup.startXI.map { merge(player: $0, stats: stats[$0.player.id]) }
        merged.substitutes = lineup.substitutes.map { merge(player: $0, stats: stats[$0.player.id]) }
        return merged
    }

    private static func merge(player: LineupPlayer, stats: PlayerMatchStats?) -> LineupPlayer {
        guard let stats else { return player }
        var merged = player
        merged.rating = stats.rating
        merged.matchStats = stats
        merged.player.rating = stats.rating
        return merged
    }
}
