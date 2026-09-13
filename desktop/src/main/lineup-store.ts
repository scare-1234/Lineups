import { promises as fs } from 'node:fs';
import path from 'node:path';
import { randomUUID } from 'node:crypto';
import type { CustomLineup } from '../shared/types';
import { isLineupValid } from '../shared/lineup';

/** Saved custom lineups, kept as one JSON document in the user's app-data folder. */
export class LineupStore {
  private lineups: CustomLineup[] = [];
  private loaded = false;

  constructor(private readonly filePath: string) {}

  async load(): Promise<CustomLineup[]> {
    if (this.loaded) return this.list();
    try {
      const raw = await fs.readFile(this.filePath, 'utf8');
      const parsed: unknown = JSON.parse(raw);
      this.lineups = Array.isArray(parsed) ? parsed.filter(isCustomLineup) : [];
    } catch {
      this.lineups = [];
    }
    this.loaded = true;
    return this.list();
  }

  private async persist(): Promise<void> {
    await fs.mkdir(path.dirname(this.filePath), { recursive: true });
    await fs.writeFile(this.filePath, `${JSON.stringify(this.lineups, null, 2)}\n`, 'utf8');
  }

  /** Newest edit first, which is the order the UI shows. */
  list(): CustomLineup[] {
    return [...this.lineups].sort((a, b) => b.updatedAt.localeCompare(a.updatedAt));
  }

  async save(lineup: CustomLineup): Promise<CustomLineup[]> {
    await this.load();
    if (!isCustomLineup(lineup) || !isLineupValid(lineup, false)) {
      throw new Error('Refusing to save an invalid lineup');
    }
    const updated: CustomLineup = { ...lineup, updatedAt: new Date().toISOString() };
    const index = this.lineups.findIndex((entry) => entry.id === updated.id);
    if (index >= 0) {
      this.lineups[index] = updated;
    } else {
      this.lineups.push(updated);
    }
    await this.persist();
    return this.list();
  }

  async remove(id: string): Promise<CustomLineup[]> {
    await this.load();
    this.lineups = this.lineups.filter((entry) => entry.id !== id);
    await this.persist();
    return this.list();
  }

  async duplicate(id: string): Promise<CustomLineup[]> {
    await this.load();
    const original = this.lineups.find((entry) => entry.id === id);
    if (!original) return this.list();
    const now = new Date().toISOString();
    this.lineups.push({
      ...original,
      id: randomUUID(),
      name: `${original.name} copy`,
      createdAt: now,
      updatedAt: now,
    });
    await this.persist();
    return this.list();
  }
}

function isCustomLineup(value: unknown): value is CustomLineup {
  if (typeof value !== 'object' || value === null) return false;
  const record = value as Record<string, unknown>;
  return (
    typeof record.id === 'string' &&
    typeof record.name === 'string' &&
    typeof record.formation === 'string' &&
    typeof record.createdAt === 'string' &&
    typeof record.updatedAt === 'string' &&
    Array.isArray(record.players)
  );
}
