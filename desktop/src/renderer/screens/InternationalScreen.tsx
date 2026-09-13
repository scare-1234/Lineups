import { useState } from 'react';
import { INTERNATIONAL_COMPETITIONS, LEAGUES, NATIONAL_TEAM_COUNTRIES } from '../../shared/leagues';
import { flagLabel } from '../../shared/flags';
import { ROLE_DEPTH, roleFromApi } from '../../shared/formation';
import { averageRating } from '../../shared/rating';
import type { Fixture, Player } from '../../shared/types';
import { api } from '../lib/api';
import { bannerFor, useApiResource } from '../lib/useApiResource';
import { kickoffTime } from '../lib/format';
import { Crest } from '../components/Avatar';
import { RatingBadge, StatusBadge } from '../components/Badges';
import { Banner, EmptyState, ErrorState, SkeletonList } from '../components/States';
import { PlayerRowFromPlayer } from '../components/PlayerRow';

interface Props {
  onOpenFixture: (fixture: Fixture) => void;
  onOpenPlayer: (player: Player) => void;
  onOpenSettings: () => void;
}

export function InternationalScreen({ onOpenFixture, onOpenPlayer, onOpenSettings }: Props) {
  const [competition, setCompetition] = useState<number>(LEAGUES.worldCup.id);
  const [country, setCountry] = useState<string | null>(null);

  const fixtures = useApiResource(() => api.recentFixtures(competition, 20), [competition]);
  const teams = useApiResource(() => api.nationalTeams(country ?? ''), [country], { enabled: country !== null });
  const team = teams.data?.[0] ?? null;
  const squad = useApiResource(() => api.squad(team?.id ?? 0), [team?.id], { enabled: team !== null });

  const banner = bannerFor(fixtures.source);
  const players = [...(squad.data ?? [])].sort((a, b) => {
    const left = ROLE_DEPTH[roleFromApi(a.position) ?? 'attacker'];
    const right = ROLE_DEPTH[roleFromApi(b.position) ?? 'attacker'];
    return left === right ? a.name.localeCompare(b.name) : left - right;
  });

  return (
    <>
      <header className="page-header">
        <div>
          <h1 className="page-title">International</h1>
          <p className="page-subtitle">Competitions, recent internationals and national squads</p>
        </div>
      </header>

      <div className="chip-row" style={{ marginBottom: 16 }}>
        {INTERNATIONAL_COMPETITIONS.map((entry) => (
          <button
            key={entry.id}
            type="button"
            className={`chip${entry.id === competition ? ' selected' : ''}`}
            onClick={() => setCompetition(entry.id)}
          >
            🌍 {entry.name}
          </button>
        ))}
      </div>

      {banner ? <Banner message={banner.message} glyph={banner.glyph} /> : null}

      <h2 className="section-title">Recent matches</h2>
      {fixtures.loading ? <SkeletonList rows={4} /> : null}
      {!fixtures.loading && fixtures.error ? (
        <ErrorState error={fixtures.error} onRetry={fixtures.reload} onOpenSettings={onOpenSettings} />
      ) : null}
      {!fixtures.loading && !fixtures.error && (fixtures.data ?? []).length === 0 ? (
        <EmptyState glyph="🌍" title="No matches" message="No recent fixtures for this competition." />
      ) : null}
      {(fixtures.data ?? []).map((fixture) => (
        <button key={fixture.id} type="button" className="fixture" onClick={() => onOpenFixture(fixture)}>
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
        </button>
      ))}

      <h2 className="section-title" style={{ marginTop: 26 }}>
        National team squads
      </h2>
      <div className="chip-row" style={{ marginBottom: 14 }}>
        {NATIONAL_TEAM_COUNTRIES.map((entry) => (
          <button
            key={entry}
            type="button"
            className={`chip${entry === country ? ' selected' : ''}`}
            onClick={() => setCountry(entry)}
          >
            {flagLabel(entry)}
          </button>
        ))}
      </div>

      {country === null ? (
        <p className="caption">Pick a country to see its squad.</p>
      ) : teams.loading || squad.loading ? (
        <SkeletonList rows={5} height={54} />
      ) : teams.error ?? squad.error ? (
        <ErrorState
          error={(teams.error ?? squad.error) as NonNullable<typeof teams.error>}
          onRetry={teams.reload}
          onOpenSettings={onOpenSettings}
        />
      ) : players.length === 0 ? (
        <EmptyState glyph="👥" title="No squad data" message="No squad is available for this team." />
      ) : (
        <div className="card">
          {team ? (
            <div className="spread" style={{ marginBottom: 10 }}>
              <span className="row">
                <Crest team={team} size={30} />
                <strong>{team.name}</strong>
              </span>
              <RatingBadge rating={averageRating(players.map((player) => player.rating))} />
            </div>
          ) : null}
          {players.map((player) => (
            <PlayerRowFromPlayer key={player.id} player={player} onClick={() => onOpenPlayer(player)} />
          ))}
        </div>
      )}
    </>
  );
}
