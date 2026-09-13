import { DEFAULT_FORMATION, formationSlot, parseFormation, roleFromApi } from './formation';
import type { FormationSlot } from './formation';
import { averageRating } from './rating';
import type { CustomLineup, CustomLineupPlayer, PitchRole, Player } from './types';

export type LineupIssue =
  | { kind: 'unknownFormation'; formation: string }
  | { kind: 'duplicatePlayer'; name: string }
  | { kind: 'wrongPlayerCount'; expected: number; actual: number }
  | { kind: 'unknownSlot'; slot: string }
  | { kind: 'duplicateSlot'; slot: string }
  | { kind: 'missingName' };

export function issueMessage(issue: LineupIssue): string {
  switch (issue.kind) {
    case 'unknownFormation':
      return `${issue.formation} is not a formation LineupLab understands.`;
    case 'duplicatePlayer':
      return `${issue.name} appears more than once.`;
    case 'wrongPlayerCount':
      return `This formation needs ${issue.expected} players, but ${issue.actual} are selected.`;
    case 'unknownSlot':
      return `${issue.slot} is not a position in this formation.`;
    case 'duplicateSlot':
      return `Two players are assigned to ${issue.slot}.`;
    case 'missingName':
      return 'Give your lineup a name.';
  }
}

/**
 * Checks a lineup is saveable: a known formation, the right number of players,
 * no duplicated players and no duplicated or unknown slots.
 */
export function validateLineup(lineup: CustomLineup, requireComplete = true): LineupIssue[] {
  const issues: LineupIssue[] = [];

  if (lineup.name.trim().length === 0) {
    issues.push({ kind: 'missingName' });
  }

  const formation = parseFormation(lineup.formation);
  if (!formation) {
    issues.push({ kind: 'unknownFormation', formation: lineup.formation });
    return issues;
  }

  if (requireComplete && lineup.players.length !== formation.slots.length) {
    issues.push({ kind: 'wrongPlayerCount', expected: formation.slots.length, actual: lineup.players.length });
  }

  const seenPlayers = new Set<number>();
  for (const player of lineup.players) {
    if (seenPlayers.has(player.playerId)) {
      issues.push({ kind: 'duplicatePlayer', name: player.playerName });
    }
    seenPlayers.add(player.playerId);
  }

  const seenSlots = new Set<string>();
  for (const player of lineup.players) {
    if (!formationSlot(formation, player.positionSlot)) {
      issues.push({ kind: 'unknownSlot', slot: player.positionSlot });
    }
    if (seenSlots.has(player.positionSlot)) {
      issues.push({ kind: 'duplicateSlot', slot: player.positionSlot });
    }
    seenSlots.add(player.positionSlot);
  }

  return issues;
}

export function isLineupValid(lineup: CustomLineup, requireComplete = true): boolean {
  return validateLineup(lineup, requireComplete).length === 0;
}

export function playersBySlot(lineup: CustomLineup): Record<string, CustomLineupPlayer> {
  const map: Record<string, CustomLineupPlayer> = {};
  for (const player of lineup.players) {
    if (!(player.positionSlot in map)) map[player.positionSlot] = player;
  }
  return map;
}

export function lineupAverageRating(players: CustomLineupPlayer[]): number | null {
  return averageRating(players.map((player) => player.playerRating));
}

export function lineupTotalAge(players: CustomLineupPlayer[]): number {
  return players.reduce((sum, player) => sum + player.playerAge, 0);
}

export function lineupAverageAge(players: CustomLineupPlayer[]): number | null {
  if (players.length === 0) return null;
  return lineupTotalAge(players) / players.length;
}

export interface NationalityCount {
  nationality: string;
  count: number;
}

/** Most represented first, e.g. 5 Brazil, 3 France. */
export function nationalityBreakdown(players: CustomLineupPlayer[]): NationalityCount[] {
  const counts = new Map<string, number>();
  for (const player of players) {
    counts.set(player.playerNationality, (counts.get(player.playerNationality) ?? 0) + 1);
  }
  return [...counts.entries()]
    .map(([nationality, count]) => ({ nationality, count }))
    .sort((a, b) => (a.count === b.count ? a.nationality.localeCompare(b.nationality) : b.count - a.count));
}

export function playerRole(player: CustomLineupPlayer): PitchRole | null {
  return roleFromApi(player.playerPosition);
}

export function lineupPlayerFrom(player: Player, slot: FormationSlot): CustomLineupPlayer {
  return {
    playerId: player.id,
    playerName: player.name,
    playerNationality: player.nationality,
    playerAge: player.age,
    playerRating: player.rating,
    positionSlot: slot.id,
    formationPosition: slot.grid,
    playerPhoto: player.photo,
    playerClub: player.clubTeam,
    playerPosition: player.position,
  };
}

export function movedToSlot(player: CustomLineupPlayer, slot: FormationSlot): CustomLineupPlayer {
  return { ...player, positionSlot: slot.id, formationPosition: slot.grid };
}

/** Rebuilds a Player from a saved lineup entry so the detail view can open from the builder. */
export function playerFromCustom(player: CustomLineupPlayer): Player {
  return {
    id: player.playerId,
    name: player.playerName,
    firstName: null,
    lastName: null,
    age: player.playerAge,
    nationality: player.playerNationality,
    photo: player.playerPhoto,
    height: null,
    weight: null,
    position: player.playerPosition,
    rating: player.playerRating,
    clubTeam: player.playerClub,
    birthDate: null,
    birthPlace: null,
    birthCountry: null,
    seasonStats: [],
  };
}

/** UUID that works in the renderer too, where `crypto.randomUUID` may be unavailable. */
export function generateId(): string {
  const webCrypto = globalThis.crypto;
  if (webCrypto && typeof webCrypto.randomUUID === 'function') {
    return webCrypto.randomUUID();
  }
  const random = () => Math.floor(Math.random() * 0x10000).toString(16).padStart(4, '0');
  return `${random()}${random()}-${random()}-${random()}-${random()}-${random()}${random()}${random()}`;
}

export function emptyLineup(name = ''): CustomLineup {
  const now = new Date().toISOString();
  return {
    id: generateId(),
    name,
    formation: DEFAULT_FORMATION,
    players: [],
    createdAt: now,
    updatedAt: now,
  };
}
