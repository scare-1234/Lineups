import { describe, expect, it } from 'vitest';
import { parseFormation } from './formation';
import {
  isLineupValid,
  lineupAverageAge,
  lineupAverageRating,
  lineupTotalAge,
  nationalityBreakdown,
  playersBySlot,
  validateLineup,
} from './lineup';
import type { CustomLineup, CustomLineupPlayer } from './types';

function completeLineup(formationName = '4-3-3'): CustomLineup {
  const formation = parseFormation(formationName)!;
  const players: CustomLineupPlayer[] = formation.slots.map((slot, index) => ({
    playerId: index + 1,
    playerName: `Player ${index + 1}`,
    playerNationality: 'Brazil',
    playerAge: 25,
    playerRating: 7.5,
    positionSlot: slot.id,
    formationPosition: slot.grid,
    playerPhoto: null,
    playerClub: null,
    playerPosition: slot.role,
  }));
  return {
    id: 'lineup-1',
    name: 'Dream XI',
    formation: formationName,
    players,
    createdAt: '2026-09-11T10:00:00.000Z',
    updatedAt: '2026-09-11T10:00:00.000Z',
  };
}

describe('lineup validation', () => {
  it('accepts a complete lineup', () => {
    const lineup = completeLineup();
    expect(validateLineup(lineup)).toEqual([]);
    expect(isLineupValid(lineup)).toBe(true);
    expect(lineup.players).toHaveLength(11);
  });

  it('rejects a duplicated player', () => {
    const lineup = completeLineup();
    const last = lineup.players.length - 1;
    lineup.players[last] = { ...lineup.players[0]!, positionSlot: lineup.players[last]!.positionSlot };
    expect(validateLineup(lineup)).toContainEqual({ kind: 'duplicatePlayer', name: 'Player 1' });
  });

  it('rejects the wrong number of players only when completeness is required', () => {
    const lineup = completeLineup();
    lineup.players.pop();
    expect(validateLineup(lineup)).toContainEqual({ kind: 'wrongPlayerCount', expected: 11, actual: 10 });
    expect(isLineupValid(lineup, false)).toBe(true);
  });

  it('rejects unknown and duplicated slots', () => {
    const unknown = completeLineup();
    unknown.players[0] = { ...unknown.players[0]!, positionSlot: 'SWEEPER' };
    expect(validateLineup(unknown)).toContainEqual({ kind: 'unknownSlot', slot: 'SWEEPER' });

    const duplicate = completeLineup();
    const slot = duplicate.players[1]!.positionSlot;
    duplicate.players[0] = { ...duplicate.players[0]!, positionSlot: slot };
    expect(validateLineup(duplicate)).toContainEqual({ kind: 'duplicateSlot', slot });
  });

  it('rejects an unknown formation and a missing name', () => {
    expect(validateLineup({ ...completeLineup(), formation: 'banana' })).toEqual([
      { kind: 'unknownFormation', formation: 'banana' },
    ]);
    expect(validateLineup({ ...completeLineup(), name: '   ' })).toContainEqual({ kind: 'missingName' });
  });
});

describe('squad statistics', () => {
  it('summarises age, rating and nationalities', () => {
    const formation = parseFormation('4-3-3')!;
    const players: CustomLineupPlayer[] = formation.slots.map((slot, index) => ({
      playerId: index + 1,
      playerName: `Player ${index}`,
      playerNationality: index < 5 ? 'Brazil' : 'France',
      playerAge: 20 + index,
      playerRating: index === 0 ? null : 7,
      positionSlot: slot.id,
      formationPosition: slot.grid,
      playerPhoto: null,
      playerClub: null,
      playerPosition: slot.role,
    }));

    expect(lineupTotalAge(players)).toBe(275);
    expect(lineupAverageRating(players)).toBeCloseTo(7, 5);
    expect(lineupAverageAge(players)).toBeCloseTo(25, 5);

    const breakdown = nationalityBreakdown(players);
    expect(breakdown[0]).toEqual({ nationality: 'France', count: 6 });
    expect(breakdown[1]).toEqual({ nationality: 'Brazil', count: 5 });

    const bySlot = playersBySlot({ ...completeLineup(), players });
    expect(bySlot.GK?.playerId).toBe(1);
  });
});
