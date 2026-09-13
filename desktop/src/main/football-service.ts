import type { ApiResponse } from '../shared/api';
import { MIN_SEARCH_LENGTH } from '../shared/api';
import {
  asArray,
  envelopeResponse,
  mapEvent,
  mapFixture,
  mapFixturePlayerStats,
  mapLeague,
  mapLineup,
  mapPlayer,
  mapSquadPlayer,
  mapStandingRow,
  mapTeam,
  mapTeamStatistics,
  str,
} from '../shared/mapping';
import type {
  Fixture,
  League,
  MatchEvent,
  MatchLineups,
  Player,
  PlayerMatchStats,
  StandingRow,
  Team,
  TeamMatchStatistics,
} from '../shared/types';
import type { ApiClient } from './api-client';
import type { ConfigStore } from './config-store';

function present<T>(value: T | null): value is T {
  return value !== null;
}

/**
 * The API-Football endpoints LineupLab uses.
 * Reference: https://www.api-football.com/documentation-v3
 */
export class FootballService {
  constructor(
    private readonly client: ApiClient,
    private readonly config: ConfigStore,
  ) {}

  /** `GET /fixtures?date=2026-09-11` */
  fixturesOn(date: string): Promise<ApiResponse<Fixture[]>> {
    return this.client.request({ path: 'fixtures', query: { date }, freshness: 'live' }, (payload) =>
      envelopeResponse(payload)
        .map(mapFixture)
        .filter(present)
        .sort((a, b) => a.date.localeCompare(b.date)),
    );
  }

  /** `GET /fixtures?id={fixtureId}` */
  fixture(id: number): Promise<ApiResponse<Fixture>> {
    return this.client.request({ path: 'fixtures', query: { id }, freshness: 'live' }, (payload) => {
      const fixture = envelopeResponse(payload).map(mapFixture).filter(present)[0];
      if (!fixture) throw new Error('empty');
      return fixture;
    });
  }

  /** `GET /fixtures?league={id}&season={season}&last={n}` */
  recentFixtures(leagueId: number, last: number): Promise<ApiResponse<Fixture[]>> {
    return this.client.request(
      { path: 'fixtures', query: { league: leagueId, season: this.config.season, last }, freshness: 'live' },
      (payload) =>
        envelopeResponse(payload)
          .map(mapFixture)
          .filter(present)
          .sort((a, b) => b.date.localeCompare(a.date)),
    );
  }

  /** `GET /fixtures/lineups?fixture={fixtureId}` */
  lineups(fixtureId: number): Promise<ApiResponse<MatchLineups>> {
    return this.client.request(
      { path: 'fixtures/lineups', query: { fixture: fixtureId }, freshness: 'live' },
      (payload) => {
        const lineups = envelopeResponse(payload).map(mapLineup).filter(present);
        return { home: lineups[0] ?? null, away: lineups[1] ?? null } satisfies MatchLineups;
      },
    );
  }

  /** `GET /fixtures/players?fixture={fixtureId}` — the source of `games.rating`. */
  playerMatchStats(fixtureId: number): Promise<ApiResponse<Record<number, PlayerMatchStats>>> {
    return this.client.request(
      { path: 'fixtures/players', query: { fixture: fixtureId }, freshness: 'live' },
      (payload) => mapFixturePlayerStats(envelopeResponse(payload)),
    );
  }

  /** `GET /fixtures/events?fixture={fixtureId}` */
  events(fixtureId: number): Promise<ApiResponse<MatchEvent[]>> {
    return this.client.request(
      { path: 'fixtures/events', query: { fixture: fixtureId }, freshness: 'live' },
      (payload) =>
        envelopeResponse(payload)
          .map((entry, index) => mapEvent(entry, index))
          .filter(present)
          .sort((a, b) => (a.minute !== b.minute ? a.minute - b.minute : (a.extraMinute ?? 0) - (b.extraMinute ?? 0))),
    );
  }

  /** `GET /fixtures/statistics?fixture={fixtureId}` */
  statistics(fixtureId: number): Promise<ApiResponse<TeamMatchStatistics[]>> {
    return this.client.request(
      { path: 'fixtures/statistics', query: { fixture: fixtureId }, freshness: 'live' },
      (payload) => envelopeResponse(payload).map(mapTeamStatistics).filter(present),
    );
  }

  /** `GET /players?id={playerId}&season={season}` */
  player(id: number): Promise<ApiResponse<Player>> {
    return this.client.request(
      { path: 'players', query: { id, season: this.config.season }, freshness: 'reference' },
      (payload) => {
        const player = envelopeResponse(payload).map(mapPlayer).filter(present)[0];
        if (!player) throw new Error('empty');
        return player;
      },
    );
  }

  /**
   * `GET /players?search={name}&season={season}` — searches the whole database, which is
   * what the builder needs: any player, any league, any nationality.
   */
  async searchPlayers(query: string): Promise<ApiResponse<Player[]>> {
    const trimmed = query.trim();
    if (trimmed.length < MIN_SEARCH_LENGTH) {
      return { ok: true, value: [], source: { kind: 'network' } };
    }
    return this.client.request(
      { path: 'players', query: { search: trimmed, season: this.config.season }, freshness: 'reference' },
      (payload) => envelopeResponse(payload).map(mapPlayer).filter(present),
    );
  }

  /** `GET /players/squads?team={teamId}` */
  squad(teamId: number): Promise<ApiResponse<Player[]>> {
    return this.client.request(
      { path: 'players/squads', query: { team: teamId }, freshness: 'reference' },
      (payload) => {
        const item = envelopeResponse(payload)[0];
        if (!item) return [];
        const team = (item as Record<string, unknown>).team;
        const teamName = str((team as Record<string, unknown> | null)?.name);
        const country = str((team as Record<string, unknown> | null)?.country) ?? teamName ?? '';
        return asArray((item as Record<string, unknown>).players)
          .map((entry) => mapSquadPlayer(entry, teamName, country))
          .filter(present);
      },
    );
  }

  /** `GET /teams?country={country}`, filtered down to national teams. */
  nationalTeams(country: string): Promise<ApiResponse<Team[]>> {
    return this.client.request({ path: 'teams', query: { country }, freshness: 'reference' }, (payload) =>
      envelopeResponse(payload)
        .map((entry) => mapTeam((entry as Record<string, unknown>).team))
        .filter(present)
        .filter((team) => team.isNational),
    );
  }

  /** `GET /leagues?id={leagueId}&season={season}` */
  league(id: number): Promise<ApiResponse<League>> {
    return this.client.request(
      { path: 'leagues', query: { id, season: this.config.season }, freshness: 'reference' },
      (payload) => {
        const item = envelopeResponse(payload)[0];
        if (!item) throw new Error('empty');
        const record = item as Record<string, unknown>;
        const league = mapLeague(record.league, this.config.season);
        const country = str((record.country as Record<string, unknown> | null)?.name);
        return { ...league, country: country ?? league.country };
      },
    );
  }

  /** `GET /standings?league={id}&season={season}` */
  standings(leagueId: number): Promise<ApiResponse<StandingRow[]>> {
    return this.client.request(
      { path: 'standings', query: { league: leagueId, season: this.config.season }, freshness: 'reference' },
      (payload) => {
        const item = envelopeResponse(payload)[0];
        if (!item) return [];
        const league = (item as Record<string, unknown>).league as Record<string, unknown> | undefined;
        const groups = asArray(league?.standings);
        return groups.flatMap((group) => asArray(group).map(mapStandingRow)).filter(present);
      },
    );
  }
}
