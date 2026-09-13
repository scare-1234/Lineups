export interface LeagueEntry {
  id: number;
  name: string;
  isInternational: boolean;
}

export const LEAGUES = {
  premierLeague: { id: 39, name: 'Premier League', isInternational: false },
  laLiga: { id: 140, name: 'La Liga', isInternational: false },
  serieA: { id: 135, name: 'Serie A', isInternational: false },
  bundesliga: { id: 78, name: 'Bundesliga', isInternational: false },
  ligue1: { id: 61, name: 'Ligue 1', isInternational: false },
  championsLeague: { id: 2, name: 'Champions League', isInternational: false },
  europaLeague: { id: 3, name: 'Europa League', isInternational: false },
  worldCup: { id: 1, name: 'World Cup', isInternational: true },
  euro: { id: 4, name: 'Euro Championship', isInternational: true },
  copaAmerica: { id: 9, name: 'Copa America', isInternational: true },
  afcon: { id: 6, name: 'Africa Cup of Nations', isInternational: true },
  asianCup: { id: 7, name: 'Asian Cup', isInternational: true },
  nationsLeague: { id: 5, name: 'UEFA Nations League', isInternational: true },
  worldCupQualifiers: { id: 32, name: 'World Cup Qualification', isInternational: true },
  friendlies: { id: 10, name: 'International Friendlies', isInternational: true },
} as const satisfies Record<string, LeagueEntry>;

/** Chips shown on the match list. */
export const CLUB_FILTERS: LeagueEntry[] = [
  LEAGUES.premierLeague,
  LEAGUES.laLiga,
  LEAGUES.serieA,
  LEAGUES.bundesliga,
  LEAGUES.ligue1,
  LEAGUES.championsLeague,
];

export const INTERNATIONAL_COMPETITIONS: LeagueEntry[] = [
  LEAGUES.worldCup,
  LEAGUES.euro,
  LEAGUES.copaAmerica,
  LEAGUES.afcon,
  LEAGUES.asianCup,
  LEAGUES.nationsLeague,
  LEAGUES.worldCupQualifiers,
  LEAGUES.friendlies,
];

export const INTERNATIONAL_IDS = new Set(INTERNATIONAL_COMPETITIONS.map((entry) => entry.id));

export const ALL_LEAGUES: LeagueEntry[] = [...CLUB_FILTERS, ...INTERNATIONAL_COMPETITIONS];

export function isInternationalLeague(id: number, country: string): boolean {
  return INTERNATIONAL_IDS.has(id) || country.toLowerCase() === 'world';
}

/** Countries with a national team worth listing in the picker. */
export const NATIONAL_TEAM_COUNTRIES = [
  'Argentina', 'Australia', 'Austria', 'Belgium', 'Brazil', 'Cameroon', 'Canada',
  'Chile', 'Colombia', 'Croatia', 'Denmark', 'Ecuador', 'Egypt', 'England',
  'France', 'Germany', 'Ghana', 'Italy', 'Ivory Coast', 'Japan', 'Mexico',
  'Morocco', 'Netherlands', 'Nigeria', 'Norway', 'Poland', 'Portugal',
  'Saudi Arabia', 'Scotland', 'Senegal', 'Serbia', 'South Korea', 'Spain',
  'Sweden', 'Switzerland', 'Turkey', 'United States', 'Uruguay', 'Wales',
];
