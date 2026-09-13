import { useEffect, useMemo, useState } from 'react';
import { MIN_SEARCH_LENGTH } from '../../shared/api';
import { flagLabel } from '../../shared/flags';
import { ROLE_ABBREVIATION, roleCompatibility, roleFromApi } from '../../shared/formation';
import type { FormationSlot } from '../../shared/formation';
import type { PitchRole, Player } from '../../shared/types';
import { api } from '../lib/api';
import { Modal } from '../components/Modal';
import { PlayerRowFromPlayer } from '../components/PlayerRow';
import { EmptyState, ErrorState, SkeletonList } from '../components/States';
import type { ApiErrorPayload } from '../../shared/api';

const ROLES: PitchRole[] = ['goalkeeper', 'defender', 'midfielder', 'attacker'];
const RATING_STEPS = [6, 6.5, 7, 7.5, 8];

interface Props {
  slot: FormationSlot | null;
  usedPlayerIds: Set<number>;
  pool: Player[];
  onSelect: (player: Player) => void;
  onQuickFill: (candidates: Player[]) => void;
  onDiscover: (players: Player[]) => void;
  onClose: () => void;
}

/**
 * Searches the whole API-Football database, so any player from any league or country
 * can be dropped into a slot.
 */
export function PlayerPickerModal({
  slot,
  usedPlayerIds,
  pool,
  onSelect,
  onQuickFill,
  onDiscover,
  onClose,
}: Props) {
  const [query, setQuery] = useState('');
  const [results, setResults] = useState<Player[]>(pool);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<ApiErrorPayload | null>(null);
  const [searched, setSearched] = useState(false);
  const [role, setRole] = useState<PitchRole | null>(null);
  const [nationality, setNationality] = useState<string>('');
  const [minRating, setMinRating] = useState(0);

  const trimmed = query.trim();

  // Debounced search: the API only accepts four characters or more.
  useEffect(() => {
    if (trimmed.length < MIN_SEARCH_LENGTH) {
      setResults(pool);
      setLoading(false);
      setError(null);
      return;
    }
    let cancelled = false;
    setLoading(true);
    const timer = setTimeout(() => {
      api
        .searchPlayers(trimmed)
        .then((response) => {
          if (cancelled) return;
          if (response.ok) {
            setResults(response.value);
            setError(null);
            setSearched(true);
            onDiscover(response.value);
          } else {
            setResults([]);
            setError(response.error);
          }
        })
        .finally(() => {
          if (!cancelled) setLoading(false);
        });
    }, 350);
    return () => {
      cancelled = true;
      clearTimeout(timer);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [trimmed]);

  const nationalities = useMemo(
    () => [...new Set(results.map((player) => player.nationality).filter(Boolean))].sort(),
    [results],
  );

  const filtered = useMemo(
    () =>
      results
        .filter((player) => (role ? roleFromApi(player.position) === role : true))
        .filter((player) => (nationality ? player.nationality === nationality : true))
        .filter((player) => (minRating > 0 ? (player.rating ?? 0) >= minRating : true))
        .sort((a, b) => (b.rating ?? 0) - (a.rating ?? 0)),
    [results, role, nationality, minRating],
  );

  /** Highest-rated players not already in the XI, best match for this slot first. */
  const quickFillCandidates = useMemo(() => {
    const score = (player: Player) => {
      const rating = player.rating ?? 5.5;
      const playerRole = roleFromApi(player.position);
      if (!slot || !playerRole) return rating;
      return rating * roleCompatibility(playerRole, slot.role);
    };
    return pool.filter((player) => !usedPlayerIds.has(player.id)).sort((a, b) => score(b) - score(a));
  }, [pool, usedPlayerIds, slot]);

  return (
    <Modal
      title={slot ? `Pick a player — ${slot.label}` : 'Pick a player'}
      onClose={onClose}
      actions={
        <button
          type="button"
          className="btn"
          disabled={quickFillCandidates.length === 0}
          title={
            quickFillCandidates.length === 0
              ? 'Search for players first — Quick Fill uses everyone you have found this session'
              : 'Fill the remaining slots with the highest-rated players found so far'
          }
          onClick={() => onQuickFill(quickFillCandidates)}
        >
          ⚡ Quick Fill
        </button>
      }
    >
      <input
        className="input"
        placeholder="Search players by name"
        value={query}
        autoFocus
        onChange={(event) => setQuery(event.target.value)}
        style={{ marginBottom: 12 }}
      />

      <div className="chip-row" style={{ marginBottom: 10 }}>
        <button type="button" className={`chip${role === null ? ' selected' : ''}`} onClick={() => setRole(null)}>
          All
        </button>
        {ROLES.map((entry) => (
          <button
            key={entry}
            type="button"
            className={`chip${role === entry ? ' selected' : ''}`}
            onClick={() => setRole(role === entry ? null : entry)}
          >
            {ROLE_ABBREVIATION[entry]}
          </button>
        ))}
      </div>

      <div className="row" style={{ marginBottom: 14, gap: 8 }}>
        <select
          className="input"
          value={nationality}
          onChange={(event) => setNationality(event.target.value)}
          style={{ maxWidth: 220 }}
        >
          <option value="">All nationalities</option>
          {nationalities.map((entry) => (
            <option key={entry} value={entry}>
              {flagLabel(entry)}
            </option>
          ))}
        </select>
        <select
          className="input"
          value={String(minRating)}
          onChange={(event) => setMinRating(Number(event.target.value))}
          style={{ maxWidth: 160 }}
        >
          <option value="0">Any rating</option>
          {RATING_STEPS.map((value) => (
            <option key={value} value={String(value)}>
              {value.toFixed(1)}+
            </option>
          ))}
        </select>
      </div>

      {loading ? <SkeletonList rows={4} height={54} /> : null}

      {!loading && error ? <ErrorState error={error} /> : null}

      {!loading && !error && trimmed.length > 0 && trimmed.length < MIN_SEARCH_LENGTH ? (
        <EmptyState
          glyph="🔎"
          title="Keep typing"
          message={`API-Football needs at least ${MIN_SEARCH_LENGTH} characters to search.`}
        />
      ) : null}

      {!loading && !error && filtered.length === 0 && trimmed.length >= MIN_SEARCH_LENGTH ? (
        <EmptyState glyph="🕵️" title="No players found" message="Try a different search." />
      ) : null}

      {!loading && !error && filtered.length === 0 && trimmed.length === 0 ? (
        <EmptyState
          glyph="⚽️"
          title={searched ? 'No matching players' : 'Search any player'}
          message="Every player in the database is available — search by name to get started."
        />
      ) : null}

      {filtered.map((player) => (
        <PlayerRowFromPlayer
          key={player.id}
          player={player}
          onClick={() => {
            onSelect(player);
            onClose();
          }}
        />
      ))}
    </Modal>
  );
}
