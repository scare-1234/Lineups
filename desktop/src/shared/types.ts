/** Domain model shared by the Electron main process and the renderer. */

export type PitchRole = 'goalkeeper' | 'defender' | 'midfielder' | 'attacker';

export interface Team {
  id: number;
  name: string;
  logo: string | null;
  country: string | null;
  isNational: boolean;
}

export interface League {
  id: number;
  name: string;
  country: string;
  logo: string | null;
  season: number;
  /** "League" or "Cup". */
  type: string;
  flag: string | null;
  round: string | null;
}

export type FixtureStatusKind =
  | 'scheduled'
  | 'live'
  | 'halfTime'
  | 'finished'
  | 'postponed'
  | 'cancelled'
  | 'unknown';

export interface Fixture {
  id: number;
  /** ISO-8601 kick-off time. */
  date: string;
  /** API short status: "NS", "1H", "HT", "2H", "FT", "PST"… */
  status: string;
  statusDescription: string | null;
  elapsed: number | null;
  homeTeam: Team;
  awayTeam: Team;
  homeScore: number | null;
  awayScore: number | null;
  league: League;
  venue: string | null;
  venueCity: string | null;
  referee: string | null;
}

export interface PlayerSeasonStats {
  teamId: number | null;
  teamName: string | null;
  teamLogo: string | null;
  leagueId: number | null;
  leagueName: string | null;
  season: number | null;
  appearances: number | null;
  lineups: number | null;
  minutes: number | null;
  goals: number | null;
  assists: number | null;
  rating: number | null;
  position: string | null;
  yellowCards: number | null;
  redCards: number | null;
}

/**
 * `nationality` is the country the player represents (API field `player.nationality`),
 * `age` is the API's own `player.age`, and `rating` is the latest match rating
 * (API field `games.rating`).
 */
export interface Player {
  id: number;
  name: string;
  firstName: string | null;
  lastName: string | null;
  age: number;
  nationality: string;
  photo: string | null;
  height: string | null;
  weight: string | null;
  position: string | null;
  rating: number | null;
  clubTeam: string | null;
  birthDate: string | null;
  birthPlace: string | null;
  birthCountry: string | null;
  seasonStats: PlayerSeasonStats[];
}

export interface PlayerMatchStats {
  playerId: number;
  rating: number | null;
  minutes: number | null;
  position: string | null;
  number: number | null;
  isCaptain: boolean;
  isSubstitute: boolean;
  goals: number | null;
  assists: number | null;
  shotsTotal: number | null;
  shotsOn: number | null;
  passesTotal: number | null;
  passesKey: number | null;
  passAccuracy: number | null;
  tacklesTotal: number | null;
  blocks: number | null;
  interceptions: number | null;
  duelsTotal: number | null;
  duelsWon: number | null;
  dribbleAttempts: number | null;
  dribbleSuccess: number | null;
  foulsDrawn: number | null;
  foulsCommitted: number | null;
  yellowCards: number | null;
  redCards: number | null;
}

export interface LineupPlayer {
  player: Player;
  number: number;
  /** Raw API position code: "G", "D", "M", "F". */
  position: string;
  /** "1:1", "2:3"… used to place the player on the pitch. */
  grid: string | null;
  isStarting: boolean;
  rating: number | null;
  matchStats: PlayerMatchStats | null;
}

export interface MatchLineup {
  team: Team;
  formation: string;
  startXI: LineupPlayer[];
  substitutes: LineupPlayer[];
  coachName: string | null;
  coachPhoto: string | null;
}

export interface MatchLineups {
  home: MatchLineup | null;
  away: MatchLineup | null;
}

export interface MatchEvent {
  id: string;
  minute: number;
  extraMinute: number | null;
  teamId: number;
  teamName: string;
  teamLogo: string | null;
  playerId: number | null;
  playerName: string | null;
  assistName: string | null;
  /** "Goal", "Card", "subst", "Var". */
  type: string;
  detail: string;
  comments: string | null;
}

export type MatchEventKind =
  | 'goal'
  | 'ownGoal'
  | 'penaltyMissed'
  | 'yellowCard'
  | 'redCard'
  | 'substitution'
  | 'var'
  | 'other';

export interface TeamMatchStatistics {
  teamId: number;
  teamName: string;
  values: Record<string, string>;
}

export interface StandingRow {
  rank: number;
  team: Team;
  points: number;
  goalDifference: number;
  played: number;
  wins: number;
  draws: number;
  losses: number;
  goalsFor: number;
  goalsAgainst: number;
  group: string | null;
  form: string | null;
}

/** One player inside a saved custom lineup — denormalised so saved XIs work offline. */
export interface CustomLineupPlayer {
  playerId: number;
  playerName: string;
  playerNationality: string;
  playerAge: number;
  playerRating: number | null;
  /** Matches `FormationSlot.id`, e.g. "GK", "LCB". */
  positionSlot: string;
  /** Matches `FormationSlot.grid`, e.g. "2:3". */
  formationPosition: string;
  playerPhoto: string | null;
  playerClub: string | null;
  playerPosition: string | null;
}

export interface CustomLineup {
  id: string;
  name: string;
  formation: string;
  players: CustomLineupPlayer[];
  createdAt: string;
  updatedAt: string;
}
