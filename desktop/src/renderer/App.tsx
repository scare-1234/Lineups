import { useCallback, useEffect, useState } from 'react';
import type { ConfigStatus } from '../shared/api';
import type { CustomLineup, Fixture, Player, PlayerMatchStats } from '../shared/types';
import { api } from './lib/api';
import { MatchesScreen } from './screens/MatchesScreen';
import { MatchDetailScreen } from './screens/MatchDetailScreen';
import { MyLineupsScreen } from './screens/MyLineupsScreen';
import { BuilderScreen } from './screens/BuilderScreen';
import { InternationalScreen } from './screens/InternationalScreen';
import { SettingsScreen } from './screens/SettingsScreen';
import { PlayerModal } from './screens/PlayerModal';

type View =
  | { name: 'matches' }
  | { name: 'match'; fixture: Fixture; from: 'matches' | 'international' }
  | { name: 'lineups' }
  | { name: 'builder'; lineup: CustomLineup | null; seed: Player | null }
  | { name: 'international' }
  | { name: 'settings' };

type NavId = 'matches' | 'lineups' | 'international' | 'settings';

const NAV: { id: NavId; label: string; glyph: string }[] = [
  { id: 'matches', label: 'Matches', glyph: '⚽️' },
  { id: 'lineups', label: 'My Lineups', glyph: '📋' },
  { id: 'international', label: 'International', glyph: '🌍' },
  { id: 'settings', label: 'Settings', glyph: '⚙️' },
];

function viewFor(id: NavId): View {
  switch (id) {
    case 'matches':
      return { name: 'matches' };
    case 'lineups':
      return { name: 'lineups' };
    case 'international':
      return { name: 'international' };
    case 'settings':
      return { name: 'settings' };
  }
}

/** A nav item stays highlighted while you are deeper in that section. */
function isNavActive(id: NavId, view: View): boolean {
  if (view.name === id) return true;
  if (view.name === 'builder') return id === 'lineups';
  if (view.name === 'match') return id === view.from;
  return false;
}

export function App() {
  const [view, setView] = useState<View>({ name: 'matches' });
  const [config, setConfig] = useState<ConfigStatus | null>(null);
  const [lineups, setLineups] = useState<CustomLineup[]>([]);
  const [playerSheet, setPlayerSheet] = useState<{ player: Player; stats: PlayerMatchStats | null } | null>(null);

  useEffect(() => {
    void api.getConfig().then(setConfig);
    void api.listLineups().then(setLineups);
  }, []);

  // First run: land on settings so the API key can be pasted straight away.
  useEffect(() => {
    if (config && !config.configured) {
      setView((current) => (current.name === 'matches' ? { name: 'settings' } : current));
    }
  }, [config]);

  const openSettings = useCallback(() => setView({ name: 'settings' }), []);
  const openPlayer = useCallback(
    (player: Player, stats: PlayerMatchStats | null = null) => setPlayerSheet({ player, stats }),
    [],
  );

  return (
    <div className="shell">
      <nav className="sidebar">
        <div className="brand">
          <span className="brand-mark" aria-hidden="true">
            ⚽️
          </span>
          LineupLab
        </div>
        {NAV.map((entry) => (
          <button
            key={entry.id}
            type="button"
            className={`nav-item${isNavActive(entry.id, view) ? ' active' : ''}`}
            onClick={() => setView(viewFor(entry.id))}
          >
            <span aria-hidden="true">{entry.glyph}</span>
            {entry.label}
          </button>
        ))}
        <span className="nav-spacer" />
        {config && !config.configured ? (
          <div className="sidebar-note">No API key yet — open Settings to add one.</div>
        ) : (
          <div className="sidebar-note">Season {config?.season ?? '—'} · data from API-Football</div>
        )}
      </nav>

      <main className="content">
        {view.name === 'matches' ? (
          <MatchesScreen
            onOpenFixture={(fixture) => setView({ name: 'match', fixture, from: 'matches' })}
            onOpenSettings={openSettings}
          />
        ) : null}

        {view.name === 'match' ? (
          <MatchDetailScreen
            fixture={view.fixture}
            onBack={() => setView(viewFor(view.from))}
            onOpenPlayer={openPlayer}
            onOpenSettings={openSettings}
          />
        ) : null}

        {view.name === 'lineups' ? (
          <MyLineupsScreen
            lineups={lineups}
            onChanged={setLineups}
            onEdit={(lineup) => setView({ name: 'builder', lineup, seed: null })}
            onNew={() => setView({ name: 'builder', lineup: null, seed: null })}
          />
        ) : null}

        {view.name === 'builder' ? (
          <BuilderScreen
            initial={view.lineup}
            seed={view.seed}
            onSaved={(saved) => {
              setLineups(saved);
            }}
            onOpenPlayer={(player) => openPlayer(player, null)}
            onBack={() => setView({ name: 'lineups' })}
          />
        ) : null}

        {view.name === 'international' ? (
          <InternationalScreen
            onOpenFixture={(fixture) => setView({ name: 'match', fixture, from: 'international' })}
            onOpenPlayer={(player) => openPlayer(player, null)}
            onOpenSettings={openSettings}
          />
        ) : null}

        {view.name === 'settings' ? <SettingsScreen config={config} onConfigChanged={setConfig} /> : null}
      </main>

      {playerSheet ? (
        <PlayerModal
          player={playerSheet.player}
          matchStats={playerSheet.stats}
          onClose={() => setPlayerSheet(null)}
          onAddToLineup={(player) => {
            setPlayerSheet(null);
            setView({ name: 'builder', lineup: null, seed: player });
          }}
        />
      ) : null}
    </div>
  );
}
