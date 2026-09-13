import { contextBridge, ipcRenderer } from 'electron';
import { IPC } from '../shared/api';
import type { LineupLabApi } from '../shared/api';

/**
 * The only channel between the UI and the outside world. The renderer never sees the
 * API key, never touches the file system and never makes network calls itself.
 */
const api: LineupLabApi = {
  appVersion: process.env.npm_package_version ?? '1.0.0',

  getConfig: () => ipcRenderer.invoke(IPC.getConfig),
  setApiKey: (key) => ipcRenderer.invoke(IPC.setApiKey, key),
  clearApiKey: () => ipcRenderer.invoke(IPC.clearApiKey),
  setSeason: (season) => ipcRenderer.invoke(IPC.setSeason, season),
  clearCache: () => ipcRenderer.invoke(IPC.clearCache),

  fixturesOn: (date) => ipcRenderer.invoke(IPC.fixturesOn, date),
  fixture: (id) => ipcRenderer.invoke(IPC.fixture, id),
  recentFixtures: (leagueId, last) => ipcRenderer.invoke(IPC.recentFixtures, leagueId, last),
  lineups: (fixtureId) => ipcRenderer.invoke(IPC.lineups, fixtureId),
  playerMatchStats: (fixtureId) => ipcRenderer.invoke(IPC.playerMatchStats, fixtureId),
  events: (fixtureId) => ipcRenderer.invoke(IPC.events, fixtureId),
  statistics: (fixtureId) => ipcRenderer.invoke(IPC.statistics, fixtureId),
  player: (id) => ipcRenderer.invoke(IPC.player, id),
  searchPlayers: (query) => ipcRenderer.invoke(IPC.searchPlayers, query),
  squad: (teamId) => ipcRenderer.invoke(IPC.squad, teamId),
  nationalTeams: (country) => ipcRenderer.invoke(IPC.nationalTeams, country),
  league: (id) => ipcRenderer.invoke(IPC.league, id),
  standings: (leagueId) => ipcRenderer.invoke(IPC.standings, leagueId),

  listLineups: () => ipcRenderer.invoke(IPC.listLineups),
  saveLineup: (lineup) => ipcRenderer.invoke(IPC.saveLineup, lineup),
  deleteLineup: (id) => ipcRenderer.invoke(IPC.deleteLineup, id),
  duplicateLineup: (id) => ipcRenderer.invoke(IPC.duplicateLineup, id),

  saveLineupImage: (pngDataUrl, suggestedName) =>
    ipcRenderer.invoke(IPC.saveLineupImage, pngDataUrl, suggestedName),
  openExternal: (url) => ipcRenderer.invoke(IPC.openExternal, url),
};

contextBridge.exposeInMainWorld('lineupLab', api);
