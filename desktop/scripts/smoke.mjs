/**
 * Headless smoke test: launches the built app, walks through every screen and saves a
 * screenshot of each one. It drives the app from the outside over the Chrome DevTools
 * Protocol, so no test-only code ships in the app itself.
 *
 *   npm run build && npm run smoke          (on Linux CI: xvfb-run -a npm run smoke)
 *
 * Screenshots land in release/smoke/.
 */
import { spawn } from 'node:child_process';
import { mkdirSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import electron from 'electron';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.join(here, '..');
const output = path.join(root, 'release', 'smoke');
const port = Number(process.env.LINEUPLAB_SMOKE_PORT ?? 9222);

mkdirSync(output, { recursive: true });

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

async function findPageTarget() {
  for (let attempt = 0; attempt < 60; attempt += 1) {
    try {
      const response = await fetch(`http://127.0.0.1:${port}/json/list`);
      const targets = await response.json();
      const page = targets.find((target) => target.type === 'page' && target.webSocketDebuggerUrl);
      if (page) return page;
    } catch {
      // The app is still starting up.
    }
    await sleep(250);
  }
  throw new Error('Timed out waiting for the app window');
}

function connect(url) {
  const socket = new WebSocket(url);
  const pending = new Map();
  let nextId = 1;

  const ready = new Promise((resolve, reject) => {
    socket.addEventListener('open', () => resolve());
    socket.addEventListener('error', (event) => reject(new Error(`DevTools socket failed: ${event.type}`)));
  });

  socket.addEventListener('message', (event) => {
    const message = JSON.parse(String(event.data));
    const handler = pending.get(message.id);
    if (!handler) return;
    pending.delete(message.id);
    if (message.error) handler.reject(new Error(message.error.message));
    else handler.resolve(message.result);
  });

  return {
    ready,
    send(method, params = {}) {
      const id = nextId++;
      return new Promise((resolve, reject) => {
        pending.set(id, { resolve, reject });
        socket.send(JSON.stringify({ id, method, params }));
      });
    },
    close: () => socket.close(),
  };
}

const child = spawn(String(electron), ['.', '--no-sandbox', '--disable-gpu', `--remote-debugging-port=${port}`], {
  cwd: root,
  env: { ...process.env },
  stdio: ['ignore', 'inherit', 'inherit'],
});

let failure = null;

try {
  const target = await findPageTarget();
  const client = connect(target.webSocketDebuggerUrl);
  await client.ready;
  await client.send('Page.enable');
  await sleep(1200);

  const capture = async (name) => {
    const result = await client.send('Page.captureScreenshot', { format: 'png' });
    writeFileSync(path.join(output, `${name}.png`), Buffer.from(result.data, 'base64'));
    console.log(`captured ${name}.png`);
  };

  const click = async (selector, text) => {
    const expression = `(() => {
      const nodes = [...document.querySelectorAll(${JSON.stringify(selector)})];
      const node = ${text === undefined ? 'nodes[0]' : `nodes.find((n) => (n.textContent ?? '').includes(${JSON.stringify(text)}))`};
      if (!node) return false;
      node.click();
      return true;
    })()`;
    const { result } = await client.send('Runtime.evaluate', { expression, returnByValue: true });
    if (result.value !== true) throw new Error(`Could not click ${selector}${text ? ` (${text})` : ''}`);
    await sleep(600);
  };

  // Every screen the app can show without an API key.
  await capture('01-settings');
  await click('.nav-item', 'Matches');
  await capture('02-matches');
  await click('.nav-item', 'My Lineups');
  await capture('03-my-lineups');
  await click('.btn', 'Build your first lineup');
  await capture('04-builder');
  await click('.chip', '3-5-2');
  await capture('05-builder-formation-changed');
  await click('.pitch-token');
  await capture('06-player-picker');
  await click('.btn', 'Close');
  await click('.nav-item', 'International');
  await capture('07-international');

  // Any renderer exception would have surfaced as a failed click above.
  const { result: errors } = await client.send('Runtime.evaluate', {
    expression: 'window.__lineupLabErrors ?? []',
    returnByValue: true,
  });
  if (Array.isArray(errors.value) && errors.value.length > 0) {
    throw new Error(`Renderer errors: ${errors.value.join('; ')}`);
  }

  client.close();
  console.log('Smoke test passed');
} catch (error) {
  failure = error;
  console.error(`Smoke test failed: ${error.message}`);
} finally {
  child.kill();
  await sleep(300);
  process.exit(failure ? 1 : 0);
}
