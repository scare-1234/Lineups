import { promises as fs } from 'node:fs';
import path from 'node:path';

export interface AppConfigValues {
  apiKey: string;
  baseUrl: string;
  season: number;
}

export const DEFAULT_BASE_URL = 'https://v3.football.api-sports.io';

/** European seasons roll over in July: September 2026 belongs to season 2026. */
export function currentSeason(now = new Date()): number {
  return now.getMonth() + 1 >= 7 ? now.getFullYear() : now.getFullYear() - 1;
}

/**
 * The API key lives in the user's app-data folder, never in the repository and never
 * in the renderer. Only a masked form is ever sent to the UI.
 */
export class ConfigStore {
  private values: AppConfigValues;

  constructor(private readonly filePath: string) {
    this.values = { apiKey: '', baseUrl: DEFAULT_BASE_URL, season: currentSeason() };
  }

  async load(): Promise<void> {
    try {
      const raw = await fs.readFile(this.filePath, 'utf8');
      const parsed: unknown = JSON.parse(raw);
      if (typeof parsed === 'object' && parsed !== null) {
        const record = parsed as Record<string, unknown>;
        const apiKey = typeof record.apiKey === 'string' ? record.apiKey.trim() : '';
        const baseUrl = typeof record.baseUrl === 'string' && record.baseUrl.trim().length > 0
          ? record.baseUrl.trim()
          : DEFAULT_BASE_URL;
        const season = typeof record.season === 'number' && Number.isFinite(record.season)
          ? Math.trunc(record.season)
          : currentSeason();
        this.values = { apiKey, baseUrl, season };
      }
    } catch {
      // No config yet: the app opens on the settings screen and explains what to do.
    }
    // An environment variable wins, which keeps CI and scripted runs key-file free.
    const fromEnvironment = process.env.API_FOOTBALL_KEY?.trim();
    if (fromEnvironment) this.values.apiKey = fromEnvironment;
  }

  private async persist(): Promise<void> {
    await fs.mkdir(path.dirname(this.filePath), { recursive: true });
    await fs.writeFile(this.filePath, `${JSON.stringify(this.values, null, 2)}\n`, 'utf8');
  }

  get apiKey(): string {
    return this.values.apiKey;
  }

  get baseUrl(): string {
    return this.values.baseUrl;
  }

  get season(): number {
    return this.values.season;
  }

  get isConfigured(): boolean {
    return this.values.apiKey.length > 0;
  }

  /** Last four characters only — enough to recognise a key, useless if leaked. */
  get maskedKey(): string | null {
    if (!this.isConfigured) return null;
    const key = this.values.apiKey;
    return key.length <= 4 ? '••••' : `••••${key.slice(-4)}`;
  }

  async setApiKey(key: string): Promise<void> {
    this.values.apiKey = key.trim();
    await this.persist();
  }

  async clearApiKey(): Promise<void> {
    this.values.apiKey = '';
    await this.persist();
  }

  async setSeason(season: number): Promise<void> {
    if (!Number.isFinite(season)) return;
    this.values.season = Math.trunc(season);
    await this.persist();
  }
}
