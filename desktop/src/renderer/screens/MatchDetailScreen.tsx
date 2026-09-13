import { useMemo, useState } from 'react';
import type { Fixture, LineupPlayer, MatchLineup, Player, PlayerMatchStats } from '../../shared/types';
import { EVENT_SYMBOL, MATCH_STAT_KEYS, POSSESSION_KEY, eventKind, mergeRatings } from '../../shared/mapping';
import { layoutPoints } from '../../shared/formation';
import { averageRating, ratingText } from '../../shared/rating';
import { api } from '../lib/api';
import { bannerFor, useApiResource } from '../lib/useApiResource';
import { fullDateTime, kickoffTime, shortName } from '../lib/format';
import { Pitch, pitchPosition } from '../components/Pitch';
import { RatingBadge, StatusBadge } from '../components/Badges';
import { Crest } from '../components/Avatar';
import { Banner, EmptyState, ErrorState, SkeletonList } from '../components/States';
import { PlayerRowFromLineup } from '../components/PlayerRow';

type Tab = 'lineups' | 'stats' | 'events' | 'info';

const TABS: { id: Tab; label: string }[] = [
  { id: 'lineups', label: 'Lineups' },
  { id: 'stats', label: 'Stats' },
  { id: 'events', label: 'Events' },
  { id: 'info', label: 'Info' },
];

interface Props {
  fixture: Fixture;
  onBack: () => void;
  onOpenPlayer: (player: Player, stats: PlayerMatchStats | null) => void;
  onOpenSettings: () => void;
}

export function MatchDetailScreen({ fixture, onBack, onOpenPlayer, onOpenSettings }: Props) {
  const [tab, setTab] = useState<Tab>('lineups');

  const lineups = useApiResource(() => api.lineups(fixture.id), [fixture.id]);
  const playerStats = useApiResource(() => api.playerMatchStats(fixture.id), [fixture.id]);
  const events = useApiResource(() => api.events(fixture.id), [fixture.id]);
  const statistics = useApiResource(() => api.statistics(fixture.id), [fixture.id]);

  const merged = useMemo(() => {
    const base = lineups.data ?? { home: null, away: null };
    const stats = playerStats.data ?? {};
    const withRatings = mergeRatings(base, stats);
    // Make sure the two lineups line up with the fixture's home and away teams.
    const all = [withRatings.home, withRatings.away].filter((entry): entry is MatchLineup => entry !== null);
    const home = all.find((entry) => entry.team.id === fixture.homeTeam.id) ?? withRatings.home;
    const away = all.find((entry) => entry.team.id === fixture.awayTeam.id) ?? withRatings.away;
    return { home, away };
  }, [lineups.data, playerStats.data, fixture.homeTeam.id, fixture.awayTeam.id]);

  const banner = bannerFor(lineups.source ?? statistics.source);
  const homeStats = (statistics.data ?? []).find((entry) => entry.teamId === fixture.homeTeam.id);
  const awayStats = (statistics.data ?? []).find((entry) => entry.teamId === fixture.awayTeam.id);

  return (
    <>
      <header className="page-header">
        <div>
          <button type="button" className="btn ghost" onClick={onBack} style={{ marginBottom: 10 }}>
            ← Matches
          </button>
          <h1 className="page-title">{fixture.league.name}</h1>
          <p className="page-subtitle">{fullDateTime(fixture.date)}</p>
        </div>
      </header>

      <div className="card" style={{ marginBottom: 16 }}>
        <div className="fixture-main">
          <span className="fixture-team">
            <Crest team={fixture.homeTeam} size={38} />
            <span style={{ fontWeight: 600 }}>{fixture.homeTeam.name}</span>
          </span>
          <span className="fixture-score">
            <strong style={{ fontSize: 26 }}>
              {fixture.homeScore !== null && fixture.awayScore !== null
                ? `${fixture.homeScore} – ${fixture.awayScore}`
                : kickoffTime(fixture.date)}
            </strong>
            <StatusBadge fixture={fixture} />
          </span>
          <span className="fixture-team away">
            <Crest team={fixture.awayTeam} size={38} />
            <span style={{ fontWeight: 600 }}>{fixture.awayTeam.name}</span>
          </span>
        </div>
      </div>

      <div className="tabs" role="tablist">
        {TABS.map((entry) => (
          <button
            key={entry.id}
            type="button"
            role="tab"
            aria-selected={tab === entry.id}
            className={`tab${tab === entry.id ? ' active' : ''}`}
            onClick={() => setTab(entry.id)}
          >
            {entry.label}
          </button>
        ))}
      </div>

      {banner ? <Banner message={banner.message} glyph={banner.glyph} /> : null}

      {tab === 'lineups' ? (
        <LineupsTab
          loading={lineups.loading}
          error={lineups.error}
          home={merged.home}
          away={merged.away}
          onRetry={lineups.reload}
          onOpenSettings={onOpenSettings}
          onOpenPlayer={onOpenPlayer}
        />
      ) : null}

      {tab === 'stats' ? (
        statistics.loading ? (
          <SkeletonList rows={4} />
        ) : statistics.error ? (
          <ErrorState error={statistics.error} onRetry={statistics.reload} onOpenSettings={onOpenSettings} />
        ) : !homeStats && !awayStats ? (
          <EmptyState glyph="📊" title="No statistics" message="No statistics available for this match." />
        ) : (
          <div className="card">
            <PossessionBar
              home={Number(homeStats?.values[POSSESSION_KEY]?.replace('%', '') ?? 50)}
              away={Number(awayStats?.values[POSSESSION_KEY]?.replace('%', '') ?? 50)}
              homeName={fixture.homeTeam.name}
              awayName={fixture.awayTeam.name}
            />
            {MATCH_STAT_KEYS.map((entry) => (
              <StatRow
                key={entry.api}
                label={entry.label}
                home={homeStats?.values[entry.api] ?? null}
                away={awayStats?.values[entry.api] ?? null}
              />
            ))}
          </div>
        )
      ) : null}

      {tab === 'events' ? (
        events.loading ? (
          <SkeletonList rows={5} height={46} />
        ) : events.error ? (
          <ErrorState error={events.error} onRetry={events.reload} onOpenSettings={onOpenSettings} />
        ) : (events.data ?? []).length === 0 ? (
          <EmptyState glyph="⏱️" title="No events yet" message="Goals, cards and substitutions appear here." />
        ) : (
          <div className="card">
            {(events.data ?? []).map((event) => (
              <div className="timeline-row" key={event.id}>
                <span className="timeline-minute">
                  {event.extraMinute ? `${event.minute}+${event.extraMinute}'` : `${event.minute}'`}
                </span>
                <span aria-hidden="true">{EVENT_SYMBOL[eventKind(event.type, event.detail)]}</span>
                <span style={{ flex: 1 }}>
                  <strong>{event.playerName ?? event.teamName}</strong>
                  <span className="sub" style={{ display: 'block' }}>
                    {event.detail}
                    {event.assistName ? ` · ${event.assistName}` : ''}
                  </span>
                </span>
                <span className="caption">{event.teamName}</span>
              </div>
            ))}
          </div>
        )
      ) : null}

      {tab === 'info' ? <InfoTab fixture={fixture} /> : null}
    </>
  );
}

function LineupsTab({
  loading,
  error,
  home,
  away,
  onRetry,
  onOpenSettings,
  onOpenPlayer,
}: {
  loading: boolean;
  error: ReturnType<typeof useApiResource>['error'];
  home: MatchLineup | null;
  away: MatchLineup | null;
  onRetry: () => void;
  onOpenSettings: () => void;
  onOpenPlayer: (player: Player, stats: PlayerMatchStats | null) => void;
}) {
  if (loading) return <SkeletonList rows={3} height={120} />;
  if (error) return <ErrorState error={error} onRetry={onRetry} onOpenSettings={onOpenSettings} />;
  if (!home && !away) {
    return (
      <EmptyState
        glyph="👥"
        title="Lineups not announced"
        message="Lineups are usually published about an hour before kick-off."
      />
    );
  }

  return (
    <div className="stack">
      <div className="card">
        <div className="spread" style={{ marginBottom: 12 }}>
          <TeamFormation lineup={home} align="left" />
          <span className="caption">vs</span>
          <TeamFormation lineup={away} align="right" />
        </div>
        <Pitch aspect={0.62}>
          {home ? <TeamTokens lineup={home} orientation="bottomHalf" onOpenPlayer={onOpenPlayer} /> : null}
          {away ? <TeamTokens lineup={away} orientation="topHalf" onOpenPlayer={onOpenPlayer} /> : null}
        </Pitch>
      </div>

      {[home, away].filter((lineup): lineup is MatchLineup => lineup !== null).map((lineup) => (
        <div className="card" key={lineup.team.id}>
          <div className="spread" style={{ marginBottom: 8 }}>
            <span className="row">
              <Crest team={lineup.team} />
              <strong>{lineup.team.name}</strong>
            </span>
            <span className="caption">Substitutes</span>
          </div>
          {lineup.substitutes.length === 0 ? (
            <p className="caption">No substitutes listed.</p>
          ) : (
            lineup.substitutes.map((entry) => (
              <PlayerRowFromLineup
                key={entry.player.id}
                entry={entry}
                onClick={() => onOpenPlayer(entry.player, entry.matchStats)}
              />
            ))
          )}
          {lineup.coachName ? (
            <p className="caption" style={{ marginTop: 10 }}>
              Coach: {lineup.coachName}
            </p>
          ) : null}
        </div>
      ))}
    </div>
  );
}

function TeamFormation({ lineup, align }: { lineup: MatchLineup | null; align: 'left' | 'right' }) {
  const average = lineup ? averageRating(lineup.startXI.map((entry) => entry.rating)) : null;
  return (
    <span style={{ textAlign: align, minWidth: 0 }}>
      <strong style={{ display: 'block' }}>{lineup?.team.name ?? '—'}</strong>
      <span style={{ color: 'var(--accent)', fontWeight: 700 }}>{lineup?.formation || '—'}</span>
      <span className="caption" style={{ display: 'block' }}>
        Avg rating {ratingText(average)}
      </span>
    </span>
  );
}

function TeamTokens({
  lineup,
  orientation,
  onOpenPlayer,
}: {
  lineup: MatchLineup;
  orientation: 'bottomHalf' | 'topHalf';
  onOpenPlayer: (player: Player, stats: PlayerMatchStats | null) => void;
}) {
  const points = layoutPoints(
    lineup.startXI.map((entry) => entry.grid),
    lineup.formation,
  );
  return (
    <>
      {lineup.startXI.map((entry: LineupPlayer, index) => {
        const point = points[index] ?? { x: 0.5, y: 0.5 };
        return (
          <button
            key={entry.player.id}
            type="button"
            className="pitch-token"
            style={pitchPosition(orientation, point.x, point.y)}
            onClick={() => onOpenPlayer(entry.player, entry.matchStats)}
            title={entry.player.name}
          >
            <span className={`token-circle${orientation === 'topHalf' ? ' away' : ''}`}>
              {entry.number > 0 ? entry.number : '–'}
              <RatingBadge rating={entry.rating} size={20} />
            </span>
            <span className="token-name">{shortName(entry.player.name)}</span>
          </button>
        );
      })}
    </>
  );
}

function PossessionBar({
  home,
  away,
  homeName,
  awayName,
}: {
  home: number;
  away: number;
  homeName: string;
  awayName: string;
}) {
  const total = home + away || 100;
  const homeShare = (home / total) * 100;
  return (
    <div className="stat-row">
      <div className="spread">
        <span className="caption">{homeName}</span>
        <strong className="caption">Possession</strong>
        <span className="caption">{awayName}</span>
      </div>
      <div className="bar">
        <div className="home" style={{ width: `${homeShare}%` }} />
        <div className="away" style={{ width: `${100 - homeShare}%` }} />
      </div>
      <div className="spread">
        <strong>{Math.round(homeShare)}%</strong>
        <strong>{Math.round(100 - homeShare)}%</strong>
      </div>
    </div>
  );
}

function StatRow({ label, home, away }: { label: string; home: string | null; away: string | null }) {
  const homeValue = Number((home ?? '0').replace('%', '')) || 0;
  const awayValue = Number((away ?? '0').replace('%', '')) || 0;
  const total = homeValue + awayValue;
  // Each side owns half the width; the bars meet in the middle.
  const homeShare = total > 0 ? (homeValue / total) * 50 : 25;
  const awayShare = total > 0 ? (awayValue / total) * 50 : 25;
  return (
    <div className="stat-row">
      <div className="spread">
        <strong>{home ?? '—'}</strong>
        <span className="caption">{label}</span>
        <strong>{away ?? '—'}</strong>
      </div>
      <div className="bar" style={{ height: 6 }}>
        <div className="home" style={{ width: `${homeShare}%`, marginLeft: 'auto' }} />
        <div className="away" style={{ width: `${awayShare}%` }} />
      </div>
    </div>
  );
}

function InfoTab({ fixture }: { fixture: Fixture }) {
  const rows: [string, string | null][] = [
    ['Referee', fixture.referee],
    ['Venue', fixture.venue],
    ['City', fixture.venueCity],
    ['Round', fixture.league.round],
    ['Season', fixture.league.season > 0 ? String(fixture.league.season) : null],
    ['Status', fixture.statusDescription ?? fixture.status],
    ['Kick-off', fullDateTime(fixture.date)],
  ];
  return (
    <div className="card">
      {rows.map(([label, value]) => (
        <div className="spread" key={label} style={{ padding: '7px 0', borderBottom: '1px solid var(--separator)' }}>
          <span className="caption">{label}</span>
          <span>{value ?? '—'}</span>
        </div>
      ))}
      <p className="caption" style={{ marginTop: 12, marginBottom: 0 }}>
        Attendance and weather are not part of the API-Football fixtures payload.
      </p>
    </div>
  );
}
