import { BrowserWindow, dialog, ipcMain, shell } from 'electron';
import { promises as fs } from 'node:fs';
import { IPC } from '../shared/api';
import type { ConfigStatus, SaveImageResult } from '../shared/api';
import type { CustomLineup } from '../shared/types';
import type { ConfigStore } from './config-store';
import type { DiskCache } from './disk-cache';
import type { FootballService } from './football-service';
import type { LineupStore } from './lineup-store';

interface Dependencies {
  config: ConfigStore;
  cache: DiskCache;
  service: FootballService;
  lineups: LineupStore;
  dataDirectory: string;
}

function asNumber(value: unknown, fallback = 0): number {
  return typeof value === 'number' && Number.isFinite(value) ? Math.trunc(value) : fallback;
}

function asString(value: unknown): string {
  return typeof value === 'string' ? value : '';
}

export function registerIpcHandlers(deps: Dependencies): void {
  const { config, cache, service, lineups, dataDirectory } = deps;

  const status = (): ConfigStatus => ({
    configured: config.isConfigured,
    maskedKey: config.maskedKey,
    baseUrl: config.baseUrl,
    season: config.season,
    dataDirectory,
  });

  ipcMain.handle(IPC.getConfig, () => status());

  ipcMain.handle(IPC.setApiKey, async (_event, key: unknown) => {
    await config.setApiKey(asString(key));
    return status();
  });

  ipcMain.handle(IPC.clearApiKey, async () => {
    await config.clearApiKey();
    return status();
  });

  ipcMain.handle(IPC.setSeason, async (_event, season: unknown) => {
    await config.setSeason(asNumber(season, config.season));
    return status();
  });

  ipcMain.handle(IPC.clearCache, async () => ({ removed: await cache.clear() }));

  // Football data
  ipcMain.handle(IPC.fixturesOn, (_event, date: unknown) => service.fixturesOn(asString(date)));
  ipcMain.handle(IPC.fixture, (_event, id: unknown) => service.fixture(asNumber(id)));
  ipcMain.handle(IPC.recentFixtures, (_event, leagueId: unknown, last: unknown) =>
    service.recentFixtures(asNumber(leagueId), asNumber(last, 20)),
  );
  ipcMain.handle(IPC.lineups, (_event, fixtureId: unknown) => service.lineups(asNumber(fixtureId)));
  ipcMain.handle(IPC.playerMatchStats, (_event, fixtureId: unknown) => service.playerMatchStats(asNumber(fixtureId)));
  ipcMain.handle(IPC.events, (_event, fixtureId: unknown) => service.events(asNumber(fixtureId)));
  ipcMain.handle(IPC.statistics, (_event, fixtureId: unknown) => service.statistics(asNumber(fixtureId)));
  ipcMain.handle(IPC.player, (_event, id: unknown) => service.player(asNumber(id)));
  ipcMain.handle(IPC.searchPlayers, (_event, query: unknown) => service.searchPlayers(asString(query)));
  ipcMain.handle(IPC.squad, (_event, teamId: unknown) => service.squad(asNumber(teamId)));
  ipcMain.handle(IPC.nationalTeams, (_event, country: unknown) => service.nationalTeams(asString(country)));
  ipcMain.handle(IPC.league, (_event, id: unknown) => service.league(asNumber(id)));
  ipcMain.handle(IPC.standings, (_event, leagueId: unknown) => service.standings(asNumber(leagueId)));

  // Saved lineups
  ipcMain.handle(IPC.listLineups, () => lineups.load());
  ipcMain.handle(IPC.saveLineup, (_event, lineup: unknown) => lineups.save(lineup as CustomLineup));
  ipcMain.handle(IPC.deleteLineup, (_event, id: unknown) => lineups.remove(asString(id)));
  ipcMain.handle(IPC.duplicateLineup, (_event, id: unknown) => lineups.duplicate(asString(id)));

  // Sharing a lineup as a PNG
  ipcMain.handle(IPC.saveLineupImage, async (event, dataUrl: unknown, suggestedName: unknown): Promise<SaveImageResult> => {
    const url = asString(dataUrl);
    const prefix = 'data:image/png;base64,';
    if (!url.startsWith(prefix)) return { saved: false, path: null };

    const window = BrowserWindow.fromWebContents(event.sender);
    const safeName = asString(suggestedName).replace(/[^\w\- ]+/g, '').trim() || 'lineup';
    const result = window
      ? await dialog.showSaveDialog(window, {
          title: 'Save lineup image',
          defaultPath: `${safeName}.png`,
          filters: [{ name: 'PNG image', extensions: ['png'] }],
        })
      : await dialog.showSaveDialog({ defaultPath: `${safeName}.png` });

    if (result.canceled || !result.filePath) return { saved: false, path: null };
    await fs.writeFile(result.filePath, Buffer.from(url.slice(prefix.length), 'base64'));
    return { saved: true, path: result.filePath };
  });

  ipcMain.handle(IPC.openExternal, async (_event, url: unknown) => {
    const target = asString(url);
    // Only ever hand https links to the system browser.
    if (/^https:\/\//i.test(target)) {
      await shell.openExternal(target);
    }
  });
}
