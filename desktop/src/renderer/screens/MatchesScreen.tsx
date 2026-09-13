import { useMemo, useState } from 'react';
import type { Fixture } from '../../shared/types';
import { CLUB_FILTERS, LEAGUES } from '../../shared/leagues';
import { isLeagueInternational, statusKind } from '../../shared/mapping';
import { api } from '../lib/api';
import { bannerFor, useApiResource } from '../lib/useApiResource';
import { dayKey, dayLabel, kickoffTime, matchDayStrip, monthDay } from '../lib/format';
import { Banner, EmptyState, ErrorState, SkeletonList } from '../components/States';
import { Crest } from '../components/Avatar';
import { StatusBadge } from '../components/Badges';

type Filter = { kind: 'all' } | { kind: 'league'; id: number; name: string } | { kind: 'international' };

const FILTERS: Filter[] = [
  { kind: 'all' },
  ...CLUB_FILTERS.map((entry) => ({ kind: 'league' as const, id: entry.id, name: entry.name })),
  { kind: 'league' as const, id: LEAGUES.worldCup.id, name: LEAGUES.worldCup.name },
  { kind: 'international' },
];

function filterTitle(filter: Filter): string {
  if (filter.kind === 'all') return 'All';
  if (filter.kind === 'international') return 'International';
  return filter.name;
}

function matches(filter: Filter, fixture: Fixture): boolean {
  if (filter.kind === 'all') return true;
  if (filter.kind === 'international') return isLeagueInternational(fixture.league);
  return fixture.league.id === filter.id;
}

interface Props {
  onOpenFixture: (fixture: Fixture) => void;
  onOpenSettings: () => void;
}

export function MatchesScreen({ onOpenFixture, onOpenSettings }: Props) {
  const [selectedDate, setSelectedDate] = useState(() => new Date());
  const [filter, setFilter] = useState<Filter>({ kind: 'all' });
  const days = useMemo(() => matchDayStrip(), []);
  const key = dayKey(selectedDate);

  const fixtures = useApiResource(() => api.fixturesOn(key), [key]);
  const banner = bannerFor(fixtures.source);

  const groups = useMemo(() => {
    const list = (fixtures.data ?? []).filter((fixture) => matches(filter, fixture));
    const byLeague = new Map<number, Fixture[]>();
    for (const fixture of list) {
      const existing = byLeague.get(fixture.league.id) ?? [];
      existing.push(fixture);
      byLeague.set(fixture.league.id, existing);
    }
    return [...byLeague.values()]
      .map((entries) => ({ league: entries[0]?.league, fixtures: entries }))
      .filter((group): group is { league: Fixture['league']; fixtures: Fixture[] } => group.league !== undefined)
      .sort((a, b) => a.league.name.localeCompare(b.league.name));
  }, [fixtures.data, filter]);

  const liveCount = (fixtures.data ?? []).filter((fixture) => statusKind(fixture.status) === 'live').length;

  return (
    <>
      <header className="page-header">
        <div>
          <h1 className="page-title">Matches</h1>
          <p className="page-subtitle">
            {liveCount > 0 ? `${liveCount} match${liveCount === 1 ? '' : 'es'} in progress` : 'Fixtures, lineups and ratings'}
          </p>
        </div>
        <button type="button" className="btn" onClick={fixtures.reload}>
          ⟳ Refresh
        </button>
      </header>

      <div className="chip-row" style={{ marginBottom: 12 }}>
        {days.map((day) => {
          const selected = dayKey(day) === key;
          return (
            <button
              key={dayKey(day)}
              type="button"
              className={`chip day${selected ? ' selected' : ''}`}
              onClick={() => setSelectedDate(day)}
              aria-pressed={selected}
            >
              {dayLabel(day)}
              <small>{monthDay(day)}</small>
            </button>
          );
        })}
      </div>

      <div className="chip-row" style={{ marginBottom: 18 }}>
        {FILTERS.map((entry) => {
          const selected = filterTitle(entry) === filterTitle(filter);
          return (
            <button
              key={filterTitle(entry)}
              type="button"
              className={`chip${selected ? ' selected' : ''}`}
              onClick={() => setFilter(entry)}
              aria-pressed={selected}
            >
              {filterTitle(entry)}
            </button>
          );
        })}
      </div>

      {banner ? <Banner message={banner.message} glyph={banner.glyph} /> : null}

      {fixtures.loading && groups.length === 0 ? <SkeletonList rows={6} /> : null}

      {!fixtures.loading && fixtures.error ? (
        <ErrorState error={fixtures.error} onRetry={fixtures.reload} onOpenSettings={onOpenSettings} />
      ) : null}

      {!fixtures.loading && !fixtures.error && groups.length === 0 ? (
        <EmptyState
          glyph="📅"
          title="No matches"
          message="There are no fixtures for this day and filter."
        />
      ) : null}

      {groups.map((group) => (
        <section className="league-group" key={group.league.id}>
          <div className="league-head">
            {group.league.logo ? <img src={group.league.logo} alt="" width={18} height={18} /> : null}
            <h2 className="section-title" style={{ margin: 0 }}>
              {group.league.name}
            </h2>
            <span className="caption">{group.league.country}</span>
          </div>
          {group.fixtures.map((fixture) => (
            <button
              key={fixture.id}
              type="button"
              className="fixture"
              onClick={() => onOpenFixture(fixture)}
            >
              <div className="fixture-main">
                <span className="fixture-team">
                  <Crest team={fixture.homeTeam} />
                  <span>{fixture.homeTeam.name}</span>
                </span>
                <span className="fixture-score">
                  <strong>
                    {fixture.homeScore !== null && fixture.awayScore !== null
                      ? `${fixture.homeScore} – ${fixture.awayScore}`
                      : kickoffTime(fixture.date)}
                  </strong>
                  <StatusBadge fixture={fixture} />
                </span>
                <span className="fixture-team away">
                  <Crest team={fixture.awayTeam} />
                  <span>{fixture.awayTeam.name}</span>
                </span>
              </div>
              <div className="fixture-meta">
                <span>📍 {fixture.venue ?? 'Venue TBC'}</span>
                {fixture.venueCity ? <span>· {fixture.venueCity}</span> : null}
              </div>
            </button>
          ))}
        </section>
      ))}
    </>
  );
}
