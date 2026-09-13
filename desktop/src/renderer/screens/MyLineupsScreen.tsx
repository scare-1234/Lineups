import { parseFormation } from '../../shared/formation';
import { lineupAverageRating, playersBySlot } from '../../shared/lineup';
import { ratingText } from '../../shared/rating';
import type { CustomLineup } from '../../shared/types';
import { api } from '../lib/api';
import { relativeTime } from '../lib/format';
import { MiniPitch } from '../components/Pitch';
import { EmptyState } from '../components/States';

interface Props {
  lineups: CustomLineup[];
  onChanged: (lineups: CustomLineup[]) => void;
  onEdit: (lineup: CustomLineup) => void;
  onNew: () => void;
}

export function MyLineupsScreen({ lineups, onChanged, onEdit, onNew }: Props) {
  return (
    <>
      <header className="page-header">
        <div>
          <h1 className="page-title">My Lineups</h1>
          <p className="page-subtitle">Build a dream XI from any player in the database</p>
        </div>
        <button type="button" className="btn primary" onClick={onNew}>
          + New lineup
        </button>
      </header>

      {lineups.length === 0 ? (
        <EmptyState
          glyph="📋"
          title="No saved lineups"
          message="Pick a formation, fill the slots with any players you like, and save your XI."
          action={
            <button type="button" className="btn primary" onClick={onNew}>
              Build your first lineup
            </button>
          }
        />
      ) : (
        <div className="stack">
          {lineups.map((lineup) => {
            const formation = parseFormation(lineup.formation);
            const slots = formation?.slots.length ?? 11;
            const filled = Object.keys(playersBySlot(lineup)).length;
            return (
              <div className="row" key={lineup.id} style={{ gap: 10 }}>
                <button type="button" className="lineup-card" onClick={() => onEdit(lineup)}>
                  {formation ? <MiniPitch formation={formation} /> : null}
                  <span style={{ flex: 1, minWidth: 0 }}>
                    <strong style={{ display: 'block' }}>{lineup.name || 'Untitled lineup'}</strong>
                    <span style={{ color: 'var(--accent)', fontWeight: 700 }}>{lineup.formation}</span>
                    <span className="caption" style={{ display: 'block' }}>
                      ⭐ {ratingText(lineupAverageRating(lineup.players))} · 👥 {filled}/{slots} · edited{' '}
                      {relativeTime(lineup.updatedAt)}
                    </span>
                  </span>
                </button>
                <button
                  type="button"
                  className="btn"
                  title="Duplicate"
                  onClick={async () => onChanged(await api.duplicateLineup(lineup.id))}
                >
                  ⧉
                </button>
                <button
                  type="button"
                  className="btn danger"
                  title="Delete"
                  onClick={async () => onChanged(await api.deleteLineup(lineup.id))}
                >
                  🗑
                </button>
              </div>
            );
          })}
        </div>
      )}
    </>
  );
}
