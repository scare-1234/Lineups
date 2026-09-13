import { describe, expect, it } from 'vitest';
import {
  DEFAULT_FORMATION,
  SUPPORTED_FORMATIONS,
  bestSlotFor,
  formationSlot,
  gridCoordinate,
  layoutPoints,
  parseFormation,
  remapAssignments,
  roleCompatibility,
  roleFromApi,
} from './formation';
import type { CustomLineupPlayer, PitchRole } from './types';

function slotPlayer(id: number, slotId: string, grid: string, role: PitchRole): CustomLineupPlayer {
  return {
    playerId: id,
    playerName: slotId,
    playerNationality: 'Brazil',
    playerAge: 25,
    playerRating: 7,
    positionSlot: slotId,
    formationPosition: grid,
    playerPhoto: null,
    playerClub: null,
    playerPosition: role,
  };
}

describe('parseFormation', () => {
  it('turns every supported formation into eleven labelled slots', () => {
    for (const name of SUPPORTED_FORMATIONS) {
      const formation = parseFormation(name);
      expect(formation, name).not.toBeNull();
      expect(formation?.slots).toHaveLength(11);
      expect(formation?.slots.filter((slot) => slot.role === 'goalkeeper')).toHaveLength(1);

      const ids = new Set(formation?.slots.map((slot) => slot.id));
      expect(ids.size, `${name} has duplicate slot ids`).toBe(11);

      for (const slot of formation?.slots ?? []) {
        expect(slot.x).toBeGreaterThanOrEqual(0);
        expect(slot.x).toBeLessThanOrEqual(1);
        expect(slot.y).toBeGreaterThanOrEqual(0);
        expect(slot.y).toBeLessThanOrEqual(1);
        expect(gridCoordinate(slot.grid)).not.toBeNull();
      }
    }
  });

  it('reads the line counts from the name', () => {
    const formation = parseFormation('4-2-3-1');
    expect(formation?.lines).toEqual([4, 2, 3, 1]);
    expect(formation?.slots.filter((slot) => slot.role === 'defender')).toHaveLength(4);
    expect(formationSlot(formation!, 'CAM')?.role).toBe('midfielder');
    expect(formationSlot(formation!, 'ST')?.role).toBe('attacker');
    expect(formationSlot(formation!, 'GK')?.grid).toBe('1:1');
  });

  it('counts wing backs as defenders', () => {
    const formation = parseFormation('5-3-2');
    expect(formation?.slots.filter((slot) => slot.role === 'defender')).toHaveLength(5);
    expect(formationSlot(formation!, 'LWB')?.role).toBe('defender');
  });

  it('puts the keeper deepest and the strikers highest', () => {
    const formation = parseFormation(DEFAULT_FORMATION);
    expect(formationSlot(formation!, 'GK')!.y).toBeLessThan(formationSlot(formation!, 'ST')!.y);
  });

  it('rejects nonsense', () => {
    expect(parseFormation(null)).toBeNull();
    expect(parseFormation('')).toBeNull();
    expect(parseFormation('banana')).toBeNull();
    expect(parseFormation('4-3-x')).toBeNull();
    expect(parseFormation('9-9-9')).toBeNull();
    expect(parseFormation('11')).toBeNull();
  });

  it('accepts unusual shapes the API returns', () => {
    const formation = parseFormation('3-4-2-1');
    expect(formation?.slots).toHaveLength(11);
    expect(formation?.lines).toEqual([3, 4, 2, 1]);
  });
});

describe('grid coordinates', () => {
  it('parses row and column', () => {
    expect(gridCoordinate('2:3')).toEqual({ row: 2, column: 3 });
    expect(gridCoordinate('2')).toBeNull();
    expect(gridCoordinate('x:y')).toBeNull();
    expect(gridCoordinate(null)).toBeNull();
    expect(gridCoordinate('0:1')).toBeNull();
  });

  it('lays players out from their grids', () => {
    const grids = ['1:1', '2:1', '2:2', '2:3', '2:4', '3:1', '3:2', '3:3', '4:1', '4:2', '4:3'];
    const points = layoutPoints(grids, '4-3-3');
    expect(points).toHaveLength(11);
    expect(points[0]?.y).toBeCloseTo(0.07, 3);
    expect(points[10]!.y).toBeGreaterThan(points[0]!.y);
    // Column 1 renders to the left of column 4 in the same row.
    expect(points[1]!.x).toBeLessThan(points[4]!.x);
  });

  it('falls back to the formation when grids are missing', () => {
    const points = layoutPoints(Array.from({ length: 11 }, () => null), '4-4-2');
    expect(points).toHaveLength(11);
    expect(points[0]?.y).toBeCloseTo(0.07, 3);
  });

  it('still returns a point per player for an unknown formation', () => {
    const points = layoutPoints(Array.from({ length: 7 }, () => null), 'nonsense');
    expect(points).toHaveLength(7);
  });
});

describe('roles', () => {
  it('accepts short and long API codes', () => {
    expect(roleFromApi('G')).toBe('goalkeeper');
    expect(roleFromApi('D')).toBe('defender');
    expect(roleFromApi('M')).toBe('midfielder');
    expect(roleFromApi('F')).toBe('attacker');
    expect(roleFromApi('Goalkeeper')).toBe('goalkeeper');
    expect(roleFromApi('attacker')).toBe('attacker');
    expect(roleFromApi(null)).toBeNull();
    expect(roleFromApi('Coach')).toBeNull();
  });

  it('scores compatibility by distance up the pitch', () => {
    expect(roleCompatibility('attacker', 'attacker')).toBe(1);
    expect(roleCompatibility('midfielder', 'attacker')).toBeGreaterThan(
      roleCompatibility('defender', 'attacker'),
    );
    expect(roleCompatibility('goalkeeper', 'defender')).toBeLessThan(0.1);
    expect(roleCompatibility('attacker', 'goalkeeper')).toBeLessThan(0.1);
  });
});

describe('remapAssignments', () => {
  it('keeps everyone when the new formation has as many slots', () => {
    const from = parseFormation('4-3-3')!;
    const to = parseFormation('3-5-2')!;
    const assignments: Record<string, CustomLineupPlayer> = {};
    from.slots.forEach((slot, index) => {
      assignments[slot.id] = slotPlayer(index + 1, slot.id, slot.grid, slot.role);
    });

    const result = remapAssignments(assignments, from, to, (player) => (player.playerPosition as PitchRole) ?? null);

    expect(Object.keys(result.assigned)).toHaveLength(11);
    expect(result.unplaced).toHaveLength(0);
    expect(result.assigned.GK?.playerName).toBe('GK');

    const ids = Object.values(result.assigned).map((player) => player.playerId);
    expect(new Set(ids).size).toBe(ids.length);
    for (const slotId of Object.keys(result.assigned)) {
      expect(formationSlot(to, slotId)).toBeDefined();
    }
  });

  it('reports players who no longer fit', () => {
    const from = parseFormation('4-3-3')!;
    const to = parseFormation('3-3-1')!;
    const assignments: Record<string, CustomLineupPlayer> = {};
    from.slots.forEach((slot, index) => {
      assignments[slot.id] = slotPlayer(index + 1, slot.id, slot.grid, slot.role);
    });

    const result = remapAssignments(assignments, from, to, (player) => (player.playerPosition as PitchRole) ?? null);

    expect(Object.keys(result.assigned)).toHaveLength(to.slots.length);
    expect(Object.keys(result.assigned).length + result.unplaced.length).toBe(11);
  });
});

describe('bestSlotFor', () => {
  it('prefers the matching role and falls back when it is taken', () => {
    const formation = parseFormation('4-3-3')!;
    expect(bestSlotFor('goalkeeper', formation, new Set())?.id).toBe('GK');
    expect(bestSlotFor('attacker', formation, new Set())?.role).toBe('attacker');

    const attackersTaken = new Set(
      formation.slots.filter((slot) => slot.role === 'attacker').map((slot) => slot.id),
    );
    expect(bestSlotFor('attacker', formation, attackersTaken)?.role).not.toBe('attacker');

    const full = new Set(formation.slots.map((slot) => slot.id));
    expect(bestSlotFor('midfielder', formation, full)).toBeNull();
  });
});
