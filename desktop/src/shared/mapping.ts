import { isInternationalLeague } from './leagues';
import { roleFromApi } from './formation';
import type {
  Fixture,
  FixtureStatusKind,
  League,
  LineupPlayer,
  MatchEvent,
  MatchEventKind,
  MatchLineup,
  MatchLineups,
  Player,
  PlayerMatchStats,
  PlayerSeasonStats,
  StandingRow,
  Team,
  TeamMatchStatistics,
} from './types';

/**
 * API-Football is loose about types: numbers arrive as 85, "85" or "85%", and null
 * shows up nearly everywhere. These helpers read `unknown` defensively so a surprise
 * payload degrades to a missing field rather than throwing.
 */

export function asRecord(value: unknown): Record<string, unknown> | null {
  return typeof value === 'object' && value !== null && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : null;
}

export function asArray(value: unknown): unknown[] {
  return Array.isArray(value) ? value : [];
}

export function num(value: unknown): number | null {
  if (typeof value === 'number') return Number.isFinite(value) ? value : null;
  if (typeof value === 'string') {
    const cleaned = value.replace('%', '').trim();
    if (cleaned.length === 0) return null;
    const parsed = Number(cleaned);
    return Number.isFinite(parsed) ? parsed : null;
  }
  return null;
}

export function int(value: unknown): number | null {
  const parsed = num(value);
  return parsed === null ? null : Math.trunc(parsed);
}

export function str(value: unknown): string | null {
  if (typeof value === 'string') return value.length > 0 ? value : null;
  if (typeof value === 'number' || typeof value === 'boolean') return String(value);
  return null;
}

export function bool(value: unknown): boolean {
  return value === true;
}

function field(source: unknown, key: string): unknown {
  const record = asRecord(source);
  return record ? record[key] : undefined;
}

/** `errors` is `[]` when everything is fine and a dictionary when it is not. */
export function errorMessages(value: unknown): Record<string, string> {
  const record = asRecord(value);
  if (!record) return {};
  const messages: Record<string, string> = {};
  for (const [key, entry] of Object.entries(record)) {
    const text = str(entry);
    if (text) messages[key] = text;
  }
  return messages;
}

export function envelopeResponse(payload: unknown): unknown[] {
  return asArray(field(payload, 'response'));
}

// MARK: - Teams, leagues, fixtures

export function mapTeam(value: unknown): Team | null {
  const id = int(field(value, 'id'));
  if (id === null) return null;
  return {
    id,
    name: str(field(value, 'name')) ?? '',
    logo: str(field(value, 'logo')),
    country: str(field(value, 'country')),
    isNational: bool(field(value, 'national')),
  };
}

export function mapLeague(value: unknown, fallbackSeason = 0): League {
  const country = str(field(value, 'country')) ?? '';
  const id = int(field(value, 'id')) ?? 0;
  return {
    id,
    name: str(field(value, 'name')) ?? '',
    country,
    logo: str(field(value, 'logo')),
    season: int(field(value, 'season')) ?? fallbackSeason,
    type: str(field(value, 'type')) ?? 'League',
    flag: str(field(value, 'flag')),
    round: str(field(value, 'round')),
  };
}

export function statusKind(status: string): FixtureStatusKind {
  switch (status.toUpperCase()) {
    case 'TBD':
    case 'NS':
      return 'scheduled';
    case '1H':
    case '2H':
    case 'ET':
    case 'BT':
    case 'P':
    case 'LIVE':
    case 'INT':
      return 'live';
    case 'HT':
      return 'halfTime';
    case 'FT':
    case 'AET':
    case 'PEN':
      return 'finished';
    case 'PST':
      return 'postponed';
    case 'CANC':
    case 'ABD':
    case 'SUSP':
    case 'AWD':
    case 'WO':
      return 'cancelled';
    default:
      return 'unknown';
  }
}

export function isLeagueInternational(league: League): boolean {
  return isInternationalLeague(league.id, league.country);
}

export function mapFixture(value: unknown): Fixture | null {
  const fixture = field(value, 'fixture');
  const teams = field(value, 'teams');
  const id = int(field(fixture, 'id'));
  const home = mapTeam(field(teams, 'home'));
  const away = mapTeam(field(teams, 'away'));
  const date = str(field(fixture, 'date'));
  if (id === null || !home || !away || !date) return null;

  const status = field(fixture, 'status');
  const venue = field(fixture, 'venue');
  const goals = field(value, 'goals');

  return {
    id,
    date,
    status: str(field(status, 'short')) ?? 'NS',
    statusDescription: str(field(status, 'long')),
    elapsed: int(field(status, 'elapsed')),
    homeTeam: home,
    awayTeam: away,
    homeScore: int(field(goals, 'home')),
    awayScore: int(field(goals, 'away')),
    league: mapLeague(field(value, 'league')),
    venue: str(field(venue, 'name')),
    venueCity: str(field(venue, 'city')),
    referee: str(field(fixture, 'referee')),
  };
}

// MARK: - Lineups

function mapLineupPlayer(value: unknown, isStarting: boolean): LineupPlayer | null {
  const player = field(value, 'player');
  const id = int(field(player, 'id'));
  if (id === null) return null;
  const position = str(field(player, 'pos')) ?? '';
  const role = roleFromApi(position);
  return {
    player: {
      id,
      name: str(field(player, 'name')) ?? '',
      firstName: null,
      lastName: null,
      age: 0,
      nationality: '',
      photo: null,
      height: null,
      weight: null,
      position: role ?? position,
      rating: null,
      clubTeam: null,
      birthDate: null,
      birthPlace: null,
      birthCountry: null,
      seasonStats: [],
    },
    number: int(field(player, 'number')) ?? 0,
    position,
    grid: str(field(player, 'grid')),
    isStarting,
    rating: null,
    matchStats: null,
  };
}

export function mapLineup(value: unknown): MatchLineup | null {
  const team = mapTeam(field(value, 'team'));
  if (!team) return null;
  const coach = field(value, 'coach');
  return {
    team,
    formation: str(field(value, 'formation')) ?? '',
    startXI: asArray(field(value, 'startXI'))
      .map((entry) => mapLineupPlayer(entry, true))
      .filter((entry): entry is LineupPlayer => entry !== null),
    substitutes: asArray(field(value, 'substitutes'))
      .map((entry) => mapLineupPlayer(entry, false))
      .filter((entry): entry is LineupPlayer => entry !== null),
    coachName: str(field(coach, 'name')),
    coachPhoto: str(field(coach, 'photo')),
  };
}

// MARK: - Per-player match statistics

export function mapMatchStats(playerId: number, value: unknown): PlayerMatchStats | null {
  const record = asRecord(value);
  if (!record) return null;
  const games = field(record, 'games');
  const shots = field(record, 'shots');
  const goals = field(record, 'goals');
  const passes = field(record, 'passes');
  const tackles = field(record, 'tackles');
  const duels = field(record, 'duels');
  const dribbles = field(record, 'dribbles');
  const fouls = field(record, 'fouls');
  const cards = field(record, 'cards');

  return {
    playerId,
    // This is the player rating the app shows, e.g. "7.8".
    rating: num(field(games, 'rating')),
    minutes: int(field(games, 'minutes')),
    position: str(field(games, 'position')),
    number: int(field(games, 'number')),
    isCaptain: bool(field(games, 'captain')),
    isSubstitute: bool(field(games, 'substitute')),
    goals: int(field(goals, 'total')),
    assists: int(field(goals, 'assists')),
    shotsTotal: int(field(shots, 'total')),
    shotsOn: int(field(shots, 'on')),
    passesTotal: int(field(passes, 'total')),
    passesKey: int(field(passes, 'key')),
    passAccuracy: int(field(passes, 'accuracy')),
    tacklesTotal: int(field(tackles, 'total')),
    blocks: int(field(tackles, 'blocks')),
    interceptions: int(field(tackles, 'interceptions')),
    duelsTotal: int(field(duels, 'total')),
    duelsWon: int(field(duels, 'won')),
    dribbleAttempts: int(field(dribbles, 'attempts')),
    dribbleSuccess: int(field(dribbles, 'success')),
    foulsDrawn: int(field(fouls, 'drawn')),
    foulsCommitted: int(field(fouls, 'committed')),
    yellowCards: int(field(cards, 'yellow')),
    redCards: int(field(cards, 'red')),
  };
}

export function mapFixturePlayerStats(response: unknown[]): Record<number, PlayerMatchStats> {
  const result: Record<number, PlayerMatchStats> = {};
  for (const team of response) {
    for (const entry of asArray(field(team, 'players'))) {
      const id = int(field(field(entry, 'player'), 'id'));
      if (id === null) continue;
      const stats = mapMatchStats(id, asArray(field(entry, 'statistics'))[0]);
      if (stats) result[id] = stats;
    }
  }
  return result;
}

/** Folds per-player statistics (and therefore ratings) into a lineup. */
export function mergeRatings(
  lineups: MatchLineups,
  stats: Record<number, PlayerMatchStats>,
): MatchLineups {
  const mergePlayer = (entry: LineupPlayer): LineupPlayer => {
    const match = stats[entry.player.id];
    if (!match) return entry;
    return {
      ...entry,
      rating: match.rating,
      matchStats: match,
      player: { ...entry.player, rating: match.rating },
    };
  };
  const mergeLineup = (lineup: MatchLineup | null): MatchLineup | null =>
    lineup
      ? { ...lineup, startXI: lineup.startXI.map(mergePlayer), substitutes: lineup.substitutes.map(mergePlayer) }
      : null;

  return { home: mergeLineup(lineups.home), away: mergeLineup(lineups.away) };
}

// MARK: - Players

export function mapSeasonStats(value: unknown): PlayerSeasonStats {
  const games = field(value, 'games');
  const goals = field(value, 'goals');
  const cards = field(value, 'cards');
  const team = field(value, 'team');
  const league = field(value, 'league');
  return {
    teamId: int(field(team, 'id')),
    teamName: str(field(team, 'name')),
    teamLogo: str(field(team, 'logo')),
    leagueId: int(field(league, 'id')),
    leagueName: str(field(league, 'name')),
    season: int(field(league, 'season')),
    // The API really does spell it "appearences".
    appearances: int(field(games, 'appearences')),
    lineups: int(field(games, 'lineups')),
    minutes: int(field(games, 'minutes')),
    goals: int(field(goals, 'total')),
    assists: int(field(goals, 'assists')),
    rating: num(field(games, 'rating')),
    position: str(field(games, 'position')),
    yellowCards: int(field(cards, 'yellow')),
    redCards: int(field(cards, 'red')),
  };
}

export function mapPlayer(value: unknown): Player | null {
  const profile = field(value, 'player');
  const id = int(field(profile, 'id'));
  if (id === null) return null;

  const stats = asArray(field(value, 'statistics')).map(mapSeasonStats);
  const primary = stats.reduce<PlayerSeasonStats | null>((best, entry) => {
    if (!best) return entry;
    return (entry.minutes ?? 0) > (best.minutes ?? 0) ? entry : best;
  }, null);
  const birth = field(profile, 'birth');

  return {
    id,
    name: str(field(profile, 'name')) ?? '',
    firstName: str(field(profile, 'firstname')),
    lastName: str(field(profile, 'lastname')),
    // The country the player represents, and the API's own age.
    age: int(field(profile, 'age')) ?? 0,
    nationality: str(field(profile, 'nationality')) ?? '',
    photo: str(field(profile, 'photo')),
    height: str(field(profile, 'height')),
    weight: str(field(profile, 'weight')),
    position: primary?.position ?? null,
    rating: primary?.rating ?? null,
    clubTeam: primary?.teamName ?? null,
    birthDate: str(field(birth, 'date')),
    birthPlace: str(field(birth, 'place')),
    birthCountry: str(field(birth, 'country')),
    seasonStats: stats,
  };
}

/** `GET /players/squads` entries carry no nationality, so the team's country is used. */
export function mapSquadPlayer(value: unknown, teamName: string | null, nationality: string): Player | null {
  const id = int(field(value, 'id'));
  if (id === null) return null;
  const position = str(field(value, 'position'));
  return {
    id,
    name: str(field(value, 'name')) ?? '',
    firstName: null,
    lastName: null,
    age: int(field(value, 'age')) ?? 0,
    nationality,
    photo: str(field(value, 'photo')),
    height: null,
    weight: null,
    position: roleFromApi(position) ?? position,
    rating: null,
    clubTeam: teamName,
    birthDate: null,
    birthPlace: null,
    birthCountry: null,
    seasonStats: [],
  };
}

// MARK: - Events, statistics, standings

export function eventKind(type: string, detail: string): MatchEventKind {
  const lowerType = type.toLowerCase();
  const lowerDetail = detail.toLowerCase();
  if (lowerType === 'goal') {
    if (lowerDetail.includes('own')) return 'ownGoal';
    if (lowerDetail.includes('missed')) return 'penaltyMissed';
    return 'goal';
  }
  if (lowerType === 'card') return lowerDetail.includes('red') ? 'redCard' : 'yellowCard';
  if (lowerType.includes('subst')) return 'substitution';
  if (lowerType === 'var') return 'var';
  return 'other';
}

export const EVENT_SYMBOL: Record<MatchEventKind, string> = {
  goal: '⚽️',
  ownGoal: '🥅',
  penaltyMissed: '❌',
  yellowCard: '🟨',
  redCard: '🟥',
  substitution: '🔄',
  var: '📺',
  other: '•',
};

export function mapEvent(value: unknown, index: number): MatchEvent | null {
  const team = field(value, 'team');
  const teamId = int(field(team, 'id'));
  if (teamId === null) return null;
  const time = field(value, 'time');
  const player = field(value, 'player');
  const minute = int(field(time, 'elapsed')) ?? 0;
  return {
    id: `${index}-${teamId}-${minute}-${int(field(player, 'id')) ?? 0}`,
    minute,
    extraMinute: int(field(time, 'extra')),
    teamId,
    teamName: str(field(team, 'name')) ?? '',
    teamLogo: str(field(team, 'logo')),
    playerId: int(field(player, 'id')),
    playerName: str(field(player, 'name')),
    assistName: str(field(field(value, 'assist'), 'name')),
    type: str(field(value, 'type')) ?? '',
    detail: str(field(value, 'detail')) ?? '',
    comments: str(field(value, 'comments')),
  };
}

export function mapTeamStatistics(value: unknown): TeamMatchStatistics | null {
  const team = field(value, 'team');
  const teamId = int(field(team, 'id'));
  if (teamId === null) return null;
  const values: Record<string, string> = {};
  for (const entry of asArray(field(value, 'statistics'))) {
    const type = str(field(entry, 'type'));
    const raw = str(field(entry, 'value'));
    if (type && raw !== null) values[type] = raw;
  }
  return { teamId, teamName: str(field(team, 'name')) ?? '', values };
}

export function mapStandingRow(value: unknown): StandingRow | null {
  const team = mapTeam(field(value, 'team'));
  if (!team) return null;
  const all = field(value, 'all');
  const goals = field(all, 'goals');
  return {
    rank: int(field(value, 'rank')) ?? 0,
    team,
    points: int(field(value, 'points')) ?? 0,
    goalDifference: int(field(value, 'goalsDiff')) ?? 0,
    played: int(field(all, 'played')) ?? 0,
    wins: int(field(all, 'win')) ?? 0,
    draws: int(field(all, 'draw')) ?? 0,
    losses: int(field(all, 'lose')) ?? 0,
    goalsFor: int(field(goals, 'for')) ?? 0,
    goalsAgainst: int(field(goals, 'against')) ?? 0,
    group: str(field(value, 'group')),
    form: str(field(value, 'form')),
  };
}

export const MATCH_STAT_KEYS = [
  { api: 'Total Shots', label: 'Shots' },
  { api: 'Shots on Goal', label: 'Shots on Target' },
  { api: 'Corner Kicks', label: 'Corners' },
  { api: 'Fouls', label: 'Fouls' },
  { api: 'Yellow Cards', label: 'Yellow Cards' },
  { api: 'Red Cards', label: 'Red Cards' },
  { api: 'Offsides', label: 'Offsides' },
  { api: 'Passes %', label: 'Pass Accuracy' },
] as const;

export const POSSESSION_KEY = 'Ball Possession';
