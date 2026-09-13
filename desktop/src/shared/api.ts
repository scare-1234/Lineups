import type {
  CustomLineup,
  Fixture,
  League,
  MatchEvent,
  MatchLineups,
  Player,
  PlayerMatchStats,
  StandingRow,
  Team,
  TeamMatchStatistics,
} from './types';

export type CacheReason = 'fresh' | 'offline' | 'rateLimited' | 'serverError';

export type DataSource =
  | { kind: 'network' }
  | { kind: 'cache'; storedAt: string; reason: CacheReason };

export type ApiErrorKind =
  | 'configuration'
  | 'invalidKey'
  | 'rateLimited'
  | 'offline'
  | 'notFound'
  | 'server'
  | 'decoding'
  | 'service'
  | 'empty';

export interface ApiErrorPayload {
  kind: ApiErrorKind;
  message: string;
  /** True when the fix is "go and set up your API key" rather than "try again". */
  needsSetup: boolean;
}

export type ApiResponse<T> =
  | { ok: true; value: T; source: DataSource }
  | { ok: false; error: ApiErrorPayload };

export interface ConfigStatus {
  configured: boolean;
  /** Only ever the last four characters — the key itself never leaves the main process. */
  maskedKey: string | null;
  baseUrl: string;
  season: number;
  /** Where saved lineups and the cache live, shown on the settings screen. */
  dataDirectory: string;
}

export interface SaveImageResult {
  saved: boolean;
  path: string | null;
}

/** The surface the preload script exposes on `window.lineupLab`. */
export interface LineupLabApi {
  readonly appVersion: string;

  getConfig(): Promise<ConfigStatus>;
  setApiKey(key: string): Promise<ConfigStatus>;
  clearApiKey(): Promise<ConfigStatus>;
  setSeason(season: number): Promise<ConfigStatus>;
  clearCache(): Promise<{ removed: number }>;

  fixturesOn(date: string): Promise<ApiResponse<Fixture[]>>;
  fixture(id: number): Promise<ApiResponse<Fixture>>;
  recentFixtures(leagueId: number, last: number): Promise<ApiResponse<Fixture[]>>;
  lineups(fixtureId: number): Promise<ApiResponse<MatchLineups>>;
  playerMatchStats(fixtureId: number): Promise<ApiResponse<Record<number, PlayerMatchStats>>>;
  events(fixtureId: number): Promise<ApiResponse<MatchEvent[]>>;
  statistics(fixtureId: number): Promise<ApiResponse<TeamMatchStatistics[]>>;
  player(id: number): Promise<ApiResponse<Player>>;
  searchPlayers(query: string): Promise<ApiResponse<Player[]>>;
  squad(teamId: number): Promise<ApiResponse<Player[]>>;
  nationalTeams(country: string): Promise<ApiResponse<Team[]>>;
  league(id: number): Promise<ApiResponse<League>>;
  standings(leagueId: number): Promise<ApiResponse<StandingRow[]>>;

  listLineups(): Promise<CustomLineup[]>;
  saveLineup(lineup: CustomLineup): Promise<CustomLineup[]>;
  deleteLineup(id: string): Promise<CustomLineup[]>;
  duplicateLineup(id: string): Promise<CustomLineup[]>;

  saveLineupImage(pngDataUrl: string, suggestedName: string): Promise<SaveImageResult>;
  openExternal(url: string): Promise<void>;
}

export const IPC = {
  getConfig: 'config:get',
  setApiKey: 'config:setApiKey',
  clearApiKey: 'config:clearApiKey',
  setSeason: 'config:setSeason',
  clearCache: 'config:clearCache',

  fixturesOn: 'api:fixturesOn',
  fixture: 'api:fixture',
  recentFixtures: 'api:recentFixtures',
  lineups: 'api:lineups',
  playerMatchStats: 'api:playerMatchStats',
  events: 'api:events',
  statistics: 'api:statistics',
  player: 'api:player',
  searchPlayers: 'api:searchPlayers',
  squad: 'api:squad',
  nationalTeams: 'api:nationalTeams',
  league: 'api:league',
  standings: 'api:standings',

  listLineups: 'store:listLineups',
  saveLineup: 'store:saveLineup',
  deleteLineup: 'store:deleteLineup',
  duplicateLineup: 'store:duplicateLineup',

  saveLineupImage: 'shell:saveLineupImage',
  openExternal: 'shell:openExternal',
} as const;

export const MIN_SEARCH_LENGTH = 4;
