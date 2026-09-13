import { useCallback, useMemo, useState } from 'react';
import {
  DEFAULT_FORMATION,
  SUPPORTED_FORMATIONS,
  bestSlotFor,
  formationSlot,
  parseFormation,
  remapAssignments,
  roleCompatibility,
  roleFromApi,
} from '../../shared/formation';
import type { Formation, FormationSlot } from '../../shared/formation';
import {
  emptyLineup,
  issueMessage,
  lineupAverageAge,
  lineupAverageRating,
  lineupPlayerFrom,
  lineupTotalAge,
  movedToSlot,
  nationalityBreakdown,
  playerFromCustom,
  playerRole,
  playersBySlot,
  validateLineup,
} from '../../shared/lineup';
import type { LineupIssue } from '../../shared/lineup';
import { flagEmoji } from '../../shared/flags';
import { ratingText } from '../../shared/rating';
import type { CustomLineup, CustomLineupPlayer, Player } from '../../shared/types';
import { api } from '../lib/api';
import { renderLineupImage } from '../lib/exportImage';
import { shortName } from '../lib/format';
import { Pitch, pitchPosition } from '../components/Pitch';
import { RatingBadge } from '../components/Badges';
import { Modal } from '../components/Modal';
import { PlayerPickerModal } from './PlayerPickerModal';

interface Props {
  initial: CustomLineup | null;
  seed: Player | null;
  onSaved: (lineups: CustomLineup[]) => void;
  onOpenPlayer: (player: Player) => void;
  onBack: () => void;
}

export function BuilderScreen({ initial, seed, onSaved, onOpenPlayer, onBack }: Props) {
  const [lineupId] = useState(() => initial?.id ?? emptyLineup().id);
  const [createdAt] = useState(() => initial?.createdAt ?? new Date().toISOString());
  const [name, setName] = useState(initial?.name ?? '');
  const [formationName, setFormationName] = useState(initial?.formation ?? DEFAULT_FORMATION);
  const [assignments, setAssignments] = useState<Record<string, CustomLineupPlayer>>(() =>
    initial ? playersBySlot(initial) : {},
  );
  const [unplaced, setUnplaced] = useState<CustomLineupPlayer[]>([]);
  const [pool, setPool] = useState<Player[]>(() => (seed ? [seed] : []));
  const [pickerSlot, setPickerSlot] = useState<FormationSlot | null>(null);
  const [pickerOpen, setPickerOpen] = useState(false);
  const [actionSlot, setActionSlot] = useState<FormationSlot | null>(null);
  const [dropTarget, setDropTarget] = useState<string | null>(null);
  const [issues, setIssues] = useState<LineupIssue[]>([]);
  const [status, setStatus] = useState<string | null>(null);

  const formation: Formation = useMemo(
    () => parseFormation(formationName) ?? parseFormation(DEFAULT_FORMATION) ?? { name: DEFAULT_FORMATION, lines: [], slots: [] },
    [formationName],
  );

  const orderedPlayers = useMemo(
    () => formation.slots.flatMap((slot) => (assignments[slot.id] ? [assignments[slot.id] as CustomLineupPlayer] : [])),
    [formation, assignments],
  );

  const usedPlayerIds = useMemo(
    () => new Set(Object.values(assignments).map((player) => player.playerId)),
    [assignments],
  );

  const currentLineup = useMemo<CustomLineup>(
    () => ({
      id: lineupId,
      name,
      formation: formation.name,
      players: orderedPlayers,
      createdAt,
      updatedAt: new Date().toISOString(),
    }),
    [lineupId, name, formation.name, orderedPlayers, createdAt],
  );

  /** A player can only appear once, so any earlier slot is cleared first. */
  const place = useCallback((player: CustomLineupPlayer, slot: FormationSlot) => {
    setAssignments((current) => {
      const next: Record<string, CustomLineupPlayer> = {};
      for (const [slotId, entry] of Object.entries(current)) {
        if (entry.playerId !== player.playerId && slotId !== slot.id) next[slotId] = entry;
      }
      next[slot.id] = movedToSlot(player, slot);
      return next;
    });
    setUnplaced((current) => current.filter((entry) => entry.playerId !== player.playerId));
  }, []);

  const assignPlayer = useCallback(
    (player: Player, slot: FormationSlot | null) => {
      const target = slot ?? bestSlotFor(roleFromApi(player.position), formation, new Set(Object.keys(assignments)));
      if (!target) return;
      place(lineupPlayerFrom(player, target), target);
    },
    [assignments, formation, place],
  );

  const removeSlot = useCallback((slotId: string) => {
    setAssignments((current) => {
      const next = { ...current };
      delete next[slotId];
      return next;
    });
  }, []);

  /** Drag and drop: swap two players, or move one into an empty slot. */
  const move = useCallback(
    (fromSlotId: string, toSlotId: string) => {
      if (fromSlotId === toSlotId) return;
      const from = formationSlot(formation, fromSlotId);
      const to = formationSlot(formation, toSlotId);
      if (!from || !to) return;
      setAssignments((current) => {
        const moving = current[fromSlotId];
        if (!moving) return current;
        const next = { ...current };
        const displaced = current[toSlotId];
        if (displaced) {
          next[fromSlotId] = movedToSlot(displaced, from);
        } else {
          delete next[fromSlotId];
        }
        next[toSlotId] = movedToSlot(moving, to);
        return next;
      });
    },
    [formation],
  );

  const changeFormation = useCallback(
    (next: string) => {
      const target = parseFormation(next);
      if (!target || target.name === formation.name) return;
      const result = remapAssignments(assignments, formation, target, playerRole);
      const remapped: Record<string, CustomLineupPlayer> = {};
      for (const [slotId, player] of Object.entries(result.assigned)) {
        const slot = formationSlot(target, slotId);
        if (slot) remapped[slotId] = movedToSlot(player, slot);
      }
      setAssignments(remapped);
      setUnplaced((current) => [...result.unplaced, ...current]);
      setFormationName(target.name);
    },
    [assignments, formation],
  );

  /** Fills every empty slot with the best available player from the pool. */
  const quickFill = useCallback(
    (candidates: Player[]) => {
      setAssignments((current) => {
        const next = { ...current };
        const used = new Set(Object.values(current).map((entry) => entry.playerId));
        for (const slot of formation.slots) {
          if (next[slot.id]) continue;
          // Rating weighted by how well the player suits this slot.
          const score = (player: Player) => {
            const rating = player.rating ?? 5.5;
            const role = roleFromApi(player.position);
            return role ? rating * roleCompatibility(role, slot.role) : rating * 0.8;
          };
          const best = candidates
            .filter((player) => !used.has(player.id))
            .sort((a, b) => score(b) - score(a))[0];
          if (!best) continue;
          next[slot.id] = lineupPlayerFrom(best, slot);
          used.add(best.id);
        }
        return next;
      });
    },
    [formation],
  );

  const save = useCallback(async () => {
    const found = validateLineup(currentLineup, false);
    setIssues(found);
    if (found.length > 0) return;
    const saved = await api.saveLineup(currentLineup);
    onSaved(saved);
    setStatus('Saved');
    setTimeout(() => setStatus(null), 2200);
  }, [currentLineup, onSaved]);

  const exportImage = useCallback(async () => {
    const dataUrl = renderLineupImage({
      title: name || 'Custom XI',
      formation,
      assignments,
      averageRating: lineupAverageRating(orderedPlayers),
    });
    if (!dataUrl) return;
    const result = await api.saveLineupImage(dataUrl, name || 'lineup');
    if (result.saved) {
      setStatus('Image saved');
      setTimeout(() => setStatus(null), 2200);
    }
  }, [assignments, formation, name, orderedPlayers]);

  const breakdown = nationalityBreakdown(orderedPlayers);
  const filled = orderedPlayers.length;

  return (
    <>
      <header className="page-header">
        <div>
          <button type="button" className="btn ghost" onClick={onBack} style={{ marginBottom: 10 }}>
            ← My Lineups
          </button>
          <h1 className="page-title">{initial ? 'Edit lineup' : 'New lineup'}</h1>
          <p className="page-subtitle">
            {filled} of {formation.slots.length} positions filled · drag players between slots to swap them
          </p>
        </div>
        <div className="row">
          {status ? <span className="caption" style={{ color: 'var(--accent)' }}>{status}</span> : null}
          <button type="button" className="btn" onClick={exportImage} disabled={filled === 0}>
            ⬇ Export PNG
          </button>
          <button type="button" className="btn primary" onClick={save}>
            Save lineup
          </button>
        </div>
      </header>

      <div className="chip-row" style={{ marginBottom: 16 }}>
        {SUPPORTED_FORMATIONS.map((entry) => (
          <button
            key={entry}
            type="button"
            className={`chip${entry === formation.name ? ' selected' : ''}`}
            onClick={() => changeFormation(entry)}
          >
            {entry}
          </button>
        ))}
      </div>

      <div className="builder-layout">
        <div className="card">
          <Pitch aspect={0.72}>
            {formation.slots.map((slot) => {
              const player = assignments[slot.id];
              return (
                <button
                  key={slot.id}
                  type="button"
                  className={`pitch-token${dropTarget === slot.id ? ' drop-target' : ''}`}
                  style={pitchPosition('full', slot.x, slot.y)}
                  draggable={Boolean(player)}
                  onDragStart={(event) => {
                    event.dataTransfer.setData('text/plain', slot.id);
                    event.dataTransfer.effectAllowed = 'move';
                  }}
                  onDragOver={(event) => {
                    event.preventDefault();
                    event.dataTransfer.dropEffect = 'move';
                    setDropTarget(slot.id);
                  }}
                  onDragLeave={() => setDropTarget((current) => (current === slot.id ? null : current))}
                  onDrop={(event) => {
                    event.preventDefault();
                    const from = event.dataTransfer.getData('text/plain');
                    setDropTarget(null);
                    if (from) move(from, slot.id);
                  }}
                  onClick={() => {
                    if (player) {
                      setActionSlot(slot);
                    } else {
                      setPickerSlot(slot);
                      setPickerOpen(true);
                    }
                  }}
                  title={player ? player.playerName : `Add a ${slot.label}`}
                >
                  <span className={`token-circle${player ? '' : ' empty'}`}>
                    {slot.label}
                    {player ? <RatingBadge rating={player.playerRating} size={20} /> : null}
                  </span>
                  {player ? (
                    <span className="token-name">
                      {flagEmoji(player.playerNationality) ?? ''} {shortName(player.playerName)}
                    </span>
                  ) : null}
                </button>
              );
            })}
          </Pitch>

          {unplaced.length > 0 ? (
            <div style={{ marginTop: 14 }}>
              <h3 className="section-title">Unplaced after the formation change</h3>
              <div className="chip-row">
                {unplaced.map((player) => (
                  <button
                    key={player.playerId}
                    type="button"
                    className="chip"
                    onClick={() => {
                      const slot = bestSlotFor(playerRole(player), formation, new Set(Object.keys(assignments)));
                      if (slot) place(player, slot);
                    }}
                  >
                    {player.playerName} · {ratingText(player.playerRating)}
                  </button>
                ))}
              </div>
            </div>
          ) : null}
        </div>

        <div className="stack">
          <div className="card">
            <label className="caption" htmlFor="lineup-name">
              Lineup name
            </label>
            <input
              id="lineup-name"
              className="input"
              value={name}
              placeholder="Dream XI"
              onChange={(event) => setName(event.target.value)}
              style={{ marginTop: 6 }}
            />
            <div className="row" style={{ marginTop: 12 }}>
              <button
                type="button"
                className="btn"
                onClick={() => {
                  setPickerSlot(formation.slots.find((slot) => !assignments[slot.id]) ?? null);
                  setPickerOpen(true);
                }}
              >
                + Add player
              </button>
              <button
                type="button"
                className="btn danger"
                onClick={() => {
                  setAssignments({});
                  setUnplaced([]);
                }}
              >
                Clear all
              </button>
            </div>
            {issues.length > 0 ? (
              <ul style={{ margin: '12px 0 0', paddingLeft: 18 }}>
                {issues.map((issue) => (
                  <li className="issue" key={issueMessage(issue)}>
                    {issueMessage(issue)}
                  </li>
                ))}
              </ul>
            ) : null}
          </div>

          <div className="card">
            <h3 className="section-title">Squad</h3>
            <div className="stat-grid" style={{ marginBottom: 12 }}>
              <div className="stat-tile">
                <strong>{ratingText(lineupAverageRating(orderedPlayers))}</strong>
                <span>Avg rating</span>
              </div>
              <div className="stat-tile">
                <strong>{lineupTotalAge(orderedPlayers)}</strong>
                <span>Total age</span>
              </div>
              <div className="stat-tile">
                <strong>
                  {lineupAverageAge(orderedPlayers) === null
                    ? '—'
                    : (lineupAverageAge(orderedPlayers) ?? 0).toFixed(1)}
                </strong>
                <span>Avg age</span>
              </div>
            </div>
            {breakdown.length > 0 ? (
              <div className="row" style={{ flexWrap: 'wrap', gap: 6 }}>
                {breakdown.map((entry) => (
                  <span className="nationality-chip" key={entry.nationality}>
                    {flagEmoji(entry.nationality) ?? '🏳️'} {entry.count} {entry.nationality}
                  </span>
                ))}
              </div>
            ) : (
              <p className="caption">Add players to see the nationality breakdown.</p>
            )}
          </div>

          <div className="card">
            <h3 className="section-title">Positions</h3>
            <div className="slot-list">
              {formation.slots.map((slot) => {
                const player = assignments[slot.id];
                return (
                  <button
                    key={slot.id}
                    type="button"
                    onClick={() => {
                      if (player) {
                        setActionSlot(slot);
                      } else {
                        setPickerSlot(slot);
                        setPickerOpen(true);
                      }
                    }}
                  >
                    <span className="slot-tag">{slot.label}</span>
                    <span style={{ flex: 1, minWidth: 0 }}>
                      {player ? (
                        <>
                          <span style={{ fontWeight: 600 }}>{player.playerName}</span>
                          <span className="sub" style={{ display: 'block' }}>
                            {flagEmoji(player.playerNationality) ?? ''} {player.playerNationality || '—'}
                            {player.playerAge > 0 ? ` · ${player.playerAge}` : ''}
                          </span>
                        </>
                      ) : (
                        <span className="muted">Empty — click to fill</span>
                      )}
                    </span>
                    <RatingBadge rating={player?.playerRating ?? null} size={24} />
                  </button>
                );
              })}
            </div>
          </div>
        </div>
      </div>

      {pickerOpen ? (
        <PlayerPickerModal
          slot={pickerSlot}
          usedPlayerIds={usedPlayerIds}
          pool={pool}
          onSelect={(player) => assignPlayer(player, pickerSlot)}
          onQuickFill={(candidates) => {
            quickFill(candidates);
            setPickerOpen(false);
          }}
          onDiscover={(players) =>
            setPool((current) => {
              const seen = new Set(current.map((entry) => entry.id));
              return [...current, ...players.filter((player) => !seen.has(player.id))];
            })
          }
          onClose={() => setPickerOpen(false)}
        />
      ) : null}

      {actionSlot ? (
        <Modal title={actionSlot.label} onClose={() => setActionSlot(null)} width={380}>
          <div className="stack">
            <button
              type="button"
              className="btn"
              onClick={() => {
                setPickerSlot(actionSlot);
                setActionSlot(null);
                setPickerOpen(true);
              }}
            >
              Replace player
            </button>
            <button
              type="button"
              className="btn"
              onClick={() => {
                const player = assignments[actionSlot.id];
                setActionSlot(null);
                if (player) onOpenPlayer(playerFromCustom(player));
              }}
            >
              View player details
            </button>
            <button
              type="button"
              className="btn danger"
              onClick={() => {
                removeSlot(actionSlot.id);
                setActionSlot(null);
              }}
            >
              Remove from lineup
            </button>
          </div>
        </Modal>
      ) : null}
    </>
  );
}
