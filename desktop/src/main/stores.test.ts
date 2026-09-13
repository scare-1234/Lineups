import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { promises as fs } from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { ConfigStore, currentSeason, DEFAULT_BASE_URL } from './config-store';
import { LineupStore } from './lineup-store';
import { parseFormation } from '../shared/formation';
import type { CustomLineup } from '../shared/types';

let directory: string;

beforeEach(async () => {
  directory = await fs.mkdtemp(path.join(os.tmpdir(), 'lineuplab-store-'));
});

afterEach(async () => {
  await fs.rm(directory, { recursive: true, force: true });
  delete process.env.API_FOOTBALL_KEY;
});

describe('ConfigStore', () => {
  it('starts unconfigured and never exposes the whole key', async () => {
    const store = new ConfigStore(path.join(directory, 'config.json'));
    await store.load();

    expect(store.isConfigured).toBe(false);
    expect(store.maskedKey).toBeNull();
    expect(store.baseUrl).toBe(DEFAULT_BASE_URL);

    await store.setApiKey('abcdef123456');
    expect(store.isConfigured).toBe(true);
    expect(store.maskedKey).toBe('••••3456');
    expect(store.maskedKey).not.toContain('abcdef');
  });

  it('persists the key and season across restarts', async () => {
    const file = path.join(directory, 'config.json');
    const first = new ConfigStore(file);
    await first.load();
    await first.setApiKey('  spaced-key  ');
    await first.setSeason(2026);

    const second = new ConfigStore(file);
    await second.load();
    expect(second.apiKey).toBe('spaced-key');
    expect(second.season).toBe(2026);
  });

  it('lets an environment variable win, which keeps CI key-file free', async () => {
    const file = path.join(directory, 'config.json');
    const store = new ConfigStore(file);
    await store.load();
    await store.setApiKey('from-file');

    process.env.API_FOOTBALL_KEY = 'from-environment';
    const reloaded = new ConfigStore(file);
    await reloaded.load();
    expect(reloaded.apiKey).toBe('from-environment');
  });

  it('survives a corrupt config file', async () => {
    const file = path.join(directory, 'config.json');
    await fs.writeFile(file, 'not json at all', 'utf8');
    const store = new ConfigStore(file);
    await store.load();
    expect(store.isConfigured).toBe(false);
  });

  it('rolls the season over in July', () => {
    expect(currentSeason(new Date('2026-09-11T12:00:00Z'))).toBe(2026);
    expect(currentSeason(new Date('2026-07-01T12:00:00Z'))).toBe(2026);
    expect(currentSeason(new Date('2026-03-01T12:00:00Z'))).toBe(2025);
  });
});

describe('LineupStore', () => {
  function lineup(id: string, name: string): CustomLineup {
    const formation = parseFormation('4-3-3')!;
    return {
      id,
      name,
      formation: '4-3-3',
      players: formation.slots.slice(0, 3).map((slot, index) => ({
        playerId: index + 1,
        playerName: `Player ${index + 1}`,
        playerNationality: 'Brazil',
        playerAge: 24,
        playerRating: 7.2,
        positionSlot: slot.id,
        formationPosition: slot.grid,
        playerPhoto: null,
        playerClub: null,
        playerPosition: slot.role,
      })),
      createdAt: '2026-09-11T10:00:00.000Z',
      updatedAt: '2026-09-11T10:00:00.000Z',
    };
  }

  it('saves, reloads, duplicates and deletes', async () => {
    const file = path.join(directory, 'lineups.json');
    const store = new LineupStore(file);
    await store.load();
    expect(store.list()).toEqual([]);

    await store.save(lineup('a', 'Dream XI'));
    expect(store.list()).toHaveLength(1);

    // Editing keeps one entry rather than creating a second.
    await store.save({ ...lineup('a', 'Dream XI v2') });
    expect(store.list()).toHaveLength(1);
    expect(store.list()[0]?.name).toBe('Dream XI v2');

    const duplicated = await store.duplicate('a');
    expect(duplicated).toHaveLength(2);
    expect(duplicated.some((entry) => entry.name === 'Dream XI v2 copy')).toBe(true);

    const reloaded = new LineupStore(file);
    expect(await reloaded.load()).toHaveLength(2);

    await store.remove('a');
    expect(store.list()).toHaveLength(1);
  });

  it('refuses to write an invalid lineup', async () => {
    const store = new LineupStore(path.join(directory, 'lineups.json'));
    await store.load();
    const broken = { ...lineup('b', 'Broken'), formation: 'banana' };
    await expect(store.save(broken)).rejects.toThrow();
  });

  it('ignores a corrupt lineups file', async () => {
    const file = path.join(directory, 'lineups.json');
    await fs.writeFile(file, '{ not an array }', 'utf8');
    const store = new LineupStore(file);
    expect(await store.load()).toEqual([]);
  });
});
