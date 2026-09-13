import { useState } from 'react';
import type { ConfigStatus } from '../../shared/api';
import { api } from '../lib/api';

interface Props {
  config: ConfigStatus | null;
  onConfigChanged: (config: ConfigStatus) => void;
}

const SIGNUP_URL = 'https://dashboard.api-football.com/register';

export function SettingsScreen({ config, onConfigChanged }: Props) {
  const [key, setKey] = useState('');
  const [season, setSeason] = useState(String(config?.season ?? new Date().getFullYear()));
  const [status, setStatus] = useState<string | null>(null);

  const flash = (message: string) => {
    setStatus(message);
    setTimeout(() => setStatus(null), 2500);
  };

  return (
    <>
      <header className="page-header">
        <div>
          <h1 className="page-title">Settings</h1>
          <p className="page-subtitle">Your API key stays on this computer</p>
        </div>
        {status ? <span className="caption" style={{ color: 'var(--accent)' }}>{status}</span> : null}
      </header>

      <div className="card" style={{ marginBottom: 16 }}>
        <h2 className="section-title">API-Football key</h2>
        {config?.configured ? (
          <p className="caption">
            A key is set ({config.maskedKey}). LineupLab is ready to load live data.
          </p>
        ) : (
          <ol className="setup-steps" style={{ margin: '0 0 14px' }}>
            <li>
              <span>
                Create a free account at{' '}
                <button type="button" className="btn ghost" onClick={() => void api.openExternal(SIGNUP_URL)}>
                  dashboard.api-football.com
                </button>{' '}
                — the free tier allows 100 requests a day.
              </span>
            </li>
            <li>
              <span>Copy your API key from the dashboard.</span>
            </li>
            <li>
              <span>Paste it below and press Save. It is written to your app-data folder, never to the project.</span>
            </li>
          </ol>
        )}

        <div className="row" style={{ marginTop: 10 }}>
          <input
            className="input"
            type="password"
            placeholder="Paste your API key"
            value={key}
            onChange={(event) => setKey(event.target.value)}
            autoComplete="off"
          />
          <button
            type="button"
            className="btn primary"
            disabled={key.trim().length === 0}
            onClick={async () => {
              onConfigChanged(await api.setApiKey(key.trim()));
              setKey('');
              flash('API key saved');
            }}
          >
            Save
          </button>
          {config?.configured ? (
            <button
              type="button"
              className="btn danger"
              onClick={async () => {
                onConfigChanged(await api.clearApiKey());
                flash('API key removed');
              }}
            >
              Remove
            </button>
          ) : null}
        </div>
      </div>

      <div className="card" style={{ marginBottom: 16 }}>
        <h2 className="section-title">Season</h2>
        <p className="caption">
          Player profiles, searches and standings are requested for this season. European seasons roll over in July.
        </p>
        <div className="row" style={{ marginTop: 10 }}>
          <input
            className="input"
            style={{ maxWidth: 140 }}
            inputMode="numeric"
            value={season}
            onChange={(event) => setSeason(event.target.value.replace(/\D/g, ''))}
          />
          <button
            type="button"
            className="btn"
            onClick={async () => {
              const parsed = Number(season);
              if (!Number.isFinite(parsed) || parsed < 2000) return;
              onConfigChanged(await api.setSeason(parsed));
              flash('Season updated');
            }}
          >
            Update
          </button>
        </div>
      </div>

      <div className="card">
        <h2 className="section-title">Storage</h2>
        <p className="caption">
          Saved lineups, your key and cached responses live in{' '}
          <code className="inline">{config?.dataDirectory ?? '…'}</code>
        </p>
        <div className="row" style={{ marginTop: 10 }}>
          <button
            type="button"
            className="btn"
            onClick={async () => {
              const { removed } = await api.clearCache();
              flash(`Cleared ${removed} cached response${removed === 1 ? '' : 's'}`);
            }}
          >
            Clear cached data
          </button>
        </div>
        <p className="caption" style={{ marginTop: 12, marginBottom: 0 }}>
          Live data is cached for 5 minutes and player profiles for 24 hours, so the app stays inside the
          free tier's daily request budget and keeps working offline.
        </p>
      </div>
    </>
  );
}
