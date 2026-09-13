import { flagLabel } from '../../shared/flags';
import { ROLE_NAME, roleFromApi } from '../../shared/formation';
import { ratingColor, ratingText } from '../../shared/rating';
import type { Player, PlayerMatchStats } from '../../shared/types';
import { api } from '../lib/api';
import { useApiResource } from '../lib/useApiResource';
import { dateOnly } from '../lib/format';
import { Avatar } from '../components/Avatar';
import { Modal } from '../components/Modal';

interface Props {
  player: Player;
  matchStats: PlayerMatchStats | null;
  onClose: () => void;
  onAddToLineup: (player: Player) => void;
}

/** Full profile: nationality, age, position, club, ratings and season statistics. */
export function PlayerModal({ player, matchStats, onClose, onAddToLineup }: Props) {
  const profile = useApiResource(() => api.player(player.id), [player.id]);
  const merged: Player = profile.data
    ? {
        ...profile.data,
        rating: profile.data.rating ?? player.rating,
        position: profile.data.position ?? player.position,
        clubTeam: profile.data.clubTeam ?? player.clubTeam,
      }
    : player;

  const season = [...merged.seasonStats].sort((a, b) => (b.minutes ?? 0) - (a.minutes ?? 0))[0];
  const headline = matchStats?.rating ?? merged.rating ?? season?.rating ?? null;
  const role = roleFromApi(merged.position);

  return (
    <Modal
      title="Player"
      onClose={onClose}
      actions={
        <button type="button" className="btn primary" onClick={() => onAddToLineup(merged)}>
          + Add to lineup
        </button>
      }
    >
      <div className="row" style={{ alignItems: 'flex-start', gap: 18, marginBottom: 18 }}>
        <Avatar url={merged.photo} name={merged.name} size={96} />
        <div style={{ flex: 1, minWidth: 0 }}>
          <h3 style={{ margin: '0 0 4px', fontSize: 20 }}>
            {[merged.firstName, merged.lastName].filter(Boolean).join(' ') || merged.name}
          </h3>
          <p style={{ margin: '0 0 2px' }}>{flagLabel(merged.nationality)}</p>
          <p className="caption" style={{ margin: 0 }}>
            Age: {merged.age > 0 ? merged.age : '—'} · {role ? ROLE_NAME[role] : merged.position ?? 'Unknown'}
          </p>
          {merged.clubTeam ? <p className="caption" style={{ margin: 0 }}>{merged.clubTeam}</p> : null}
        </div>
        <div style={{ textAlign: 'center' }}>
          <div style={{ fontSize: 40, fontWeight: 800, color: ratingColor(headline), lineHeight: 1 }}>
            {ratingText(headline)}
          </div>
          <span className="caption">{matchStats ? 'Match rating' : 'Latest rating'}</span>
        </div>
      </div>

      <div className="stat-grid" style={{ marginBottom: 18 }}>
        <Tile label="Height" value={merged.height} />
        <Tile label="Weight" value={merged.weight} />
        <Tile label="Born" value={dateOnly(merged.birthDate)} />
        <Tile label="Birthplace" value={merged.birthPlace} />
      </div>

      {season ? (
        <>
          <h4 className="section-title">Season stats {season.leagueName ? `· ${season.leagueName}` : ''}</h4>
          <div className="stat-grid" style={{ marginBottom: 18 }}>
            <Tile label="Apps" value={season.appearances} />
            <Tile label="Goals" value={season.goals} />
            <Tile label="Assists" value={season.assists} />
            <Tile label="Minutes" value={season.minutes} />
            <Tile label="Avg rating" value={ratingText(season.rating)} />
          </div>
        </>
      ) : null}

      {matchStats ? (
        <>
          <h4 className="section-title">Match stats</h4>
          <div className="stat-grid">
            <Tile label="Minutes" value={matchStats.minutes} />
            <Tile label="Goals" value={matchStats.goals} />
            <Tile label="Assists" value={matchStats.assists} />
            <Tile
              label="Shots"
              value={matchStats.shotsTotal !== null ? `${matchStats.shotsTotal}/${matchStats.shotsOn ?? 0}` : null}
            />
            <Tile
              label="Passes"
              value={
                matchStats.passesTotal !== null
                  ? `${matchStats.passesTotal}${matchStats.passAccuracy !== null ? ` · ${matchStats.passAccuracy}%` : ''}`
                  : null
              }
            />
            <Tile
              label="Duels"
              value={matchStats.duelsTotal !== null ? `${matchStats.duelsWon ?? 0}/${matchStats.duelsTotal}` : null}
            />
            <Tile
              label="Dribbles"
              value={
                matchStats.dribbleAttempts !== null
                  ? `${matchStats.dribbleSuccess ?? 0}/${matchStats.dribbleAttempts}`
                  : null
              }
            />
            <Tile label="Tackles" value={matchStats.tacklesTotal} />
            <Tile label="Fouls" value={matchStats.foulsCommitted} />
          </div>
        </>
      ) : null}

      {profile.loading ? <p className="caption" style={{ marginTop: 14 }}>Loading full profile…</p> : null}
    </Modal>
  );
}

function Tile({ label, value }: { label: string; value: string | number | null | undefined }) {
  const text = value === null || value === undefined || value === '' ? '—' : String(value);
  return (
    <div className="stat-tile">
      <strong>{text}</strong>
      <span>{label}</span>
    </div>
  );
}
