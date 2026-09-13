import { app, BrowserWindow, shell } from 'electron';
import path from 'node:path';
import { ApiClient } from './api-client';
import { ConfigStore } from './config-store';
import { DiskCache } from './disk-cache';
import { FootballService } from './football-service';
import { LineupStore } from './lineup-store';
import { registerIpcHandlers } from './ipc';

/** Set by `npm run dev` so the window loads the Vite dev server instead of the bundle. */
const devServerUrl = process.env.LINEUPLAB_DEV_SERVER;

let mainWindow: BrowserWindow | null = null;

function createWindow(): void {
  mainWindow = new BrowserWindow({
    width: 1320,
    height: 900,
    minWidth: 980,
    minHeight: 660,
    show: false,
    title: 'LineupLab',
    backgroundColor: '#121212',
    autoHideMenuBar: true,
    icon: path.join(__dirname, '../../build/icon.png'),
    webPreferences: {
      preload: path.join(__dirname, '../preload/index.js'),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
      webSecurity: true,
      spellcheck: false,
    },
  });

  mainWindow.once('ready-to-show', () => mainWindow?.show());

  // The window only ever shows LineupLab's own UI; everything else opens in the browser.
  mainWindow.webContents.setWindowOpenHandler(({ url }) => {
    if (/^https:\/\//i.test(url)) void shell.openExternal(url);
    return { action: 'deny' };
  });

  mainWindow.webContents.on('will-navigate', (event, url) => {
    const isDevServer = devServerUrl !== undefined && url.startsWith(devServerUrl);
    if (!isDevServer && !url.startsWith('file://')) {
      event.preventDefault();
      if (/^https:\/\//i.test(url)) void shell.openExternal(url);
    }
  });

  if (devServerUrl) {
    void mainWindow.loadURL(devServerUrl);
  } else {
    void mainWindow.loadFile(path.join(__dirname, '../renderer/index.html'));
  }

  mainWindow.on('closed', () => {
    mainWindow = null;
  });
}

async function bootstrap(): Promise<void> {
  const userData = app.getPath('userData');
  const cacheDirectory = path.join(userData, 'api-cache');

  const config = new ConfigStore(path.join(userData, 'config.json'));
  await config.load();

  const cache = new DiskCache(cacheDirectory);
  void cache.prune();

  const client = new ApiClient(config, cache);
  const service = new FootballService(client, config);
  const lineups = new LineupStore(path.join(userData, 'lineups.json'));
  await lineups.load();

  registerIpcHandlers({ config, cache, service, lineups, dataDirectory: userData });
  createWindow();
}

// A second launch focuses the window that is already open rather than starting again.
if (!app.requestSingleInstanceLock()) {
  app.quit();
} else {
  app.on('second-instance', () => {
    if (!mainWindow) return;
    if (mainWindow.isMinimized()) mainWindow.restore();
    mainWindow.focus();
  });

  app.whenReady().then(bootstrap).catch((error: unknown) => {
    console.error('LineupLab failed to start', error);
    app.quit();
  });

  app.on('window-all-closed', () => {
    if (process.platform !== 'darwin') app.quit();
  });

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
}
