import { describe, expect, it } from 'vitest';
import {
  errorMessages,
  envelopeResponse,
  eventKind,
  int,
  mapEvent,
  mapFixture,
  mapFixturePlayerStats,
  mapLineup,
  mapMatchStats,
  mapPlayer,
  mapTeamStatistics,
  mergeRatings,
  num,
  statusKind,
  str,
} from './mapping';
import {
  eventsPayload,
  fixturePlayersPayload,
  fixturesPayload,
  lineupsPayload,
  playerProfilePayload,
  rateLimitErrorPayload,
  statisticsPayload,
  tokenErrorPayload,
} from './__fixtures__/sample-json';
import type { MatchLineup } from './types';

describe('fixtures', () => {
  it('maps a live fixture', () => {
    const fixtures = envelopeResponse(fixturesPayload).map(mapFixture);
    expect(fixtures).toHaveLength(2);

    const live = fixtures[0]!;
    expect(live.id).toBe(1001);
    expect(live.status).toBe('2H');
    expect(statusKind(live.status)).toBe('live');
    expect(live.elapsed).toBe(67);
    expect(live.homeScore).toBe(2);
    expect(live.awayScore).toBe(1);
    expect(live.homeTeam.name).toBe('Riverside United');
    expect(live.league.id).toBe(39);
    expect(live.league.round).toBe('Regular Season - 4');
    expect(live.venue).toBe('Riverside Stadium');
    expect(live.referee).toBe('A. Fielding');
  });

  it('copes with nulls and marks international competitions', () => {
    const upcoming = envelopeResponse(fixturesPayload).map(mapFixture)[1]!;
    expect(upcoming.homeScore).toBeNull();
    expect(upcoming.venue).toBeNull();
    expect(upcoming.referee).toBeNull();
    expect(statusKind(upcoming.status)).toBe('scheduled');
    expect(upcoming.homeTeam.isNational).toBe(true);
    expect(upcoming.league.country).toBe('World');
  });
});

describe('lineups', () => {
  it('maps both teams with grids and substitutes', () => {
    const lineups = envelopeResponse(lineupsPayload).map(mapLineup).filter(Boolean) as MatchLineup[];
    expect(lineups).toHaveLength(2);

    const home = lineups[0]!;
    expect(home.formation).toBe('4-3-3');
    expect(home.startXI).toHaveLength(11);
    expect(home.substitutes).toHaveLength(2);
    expect(home.coachName).toBe('R. Calder');

    const keeper = home.startXI[0]!;
    expect(keeper.number).toBe(1);
    expect(keeper.grid).toBe('1:1');
    expect(keeper.position).toBe('G');
    expect(keeper.isStarting).toBe(true);
    expect(home.substitutes[0]?.grid).toBeNull();
  });
});

describe('per-player match statistics', () => {
  it('reads the rating and the loose number formats', () => {
    const entries = mapFixturePlayerStats(envelopeResponse(fixturePlayersPayload));

    const scorer = entries[9]!;
    expect(scorer.rating).toBe(8.4);
    expect(scorer.minutes).toBe(90);
    expect(scorer.goals).toBe(2);
    expect(scorer.assists).toBe(1);
    expect(scorer.shotsTotal).toBe(5);
    // "82" arrives as a string and has to survive as a number.
    expect(scorer.passAccuracy).toBe(82);
    expect(scorer.duelsWon).toBe(9);
    expect(scorer.isSubstitute).toBe(false);

    const bench = entries[10]!;
    expect(bench.rating).toBeNull();
    expect(bench.shotsTotal).toBeNull();
    // The same field can arrive as a bare number.
    expect(bench.passAccuracy).toBe(75);
    expect(bench.isSubstitute).toBe(true);
    expect(bench.yellowCards).toBe(1);
  });

  it('returns null for a missing statistics block', () => {
    expect(mapMatchStats(1, undefined)).toBeNull();
  });

  it('folds ratings into the lineups', () => {
    const lineups = envelopeResponse(lineupsPayload).map(mapLineup).filter(Boolean) as MatchLineup[];
    const stats = mapFixturePlayerStats(envelopeResponse(fixturePlayersPayload));
    const merged = mergeRatings({ home: lineups[0] ?? null, away: lineups[1] ?? null }, stats);

    const scorer = merged.home?.startXI.find((entry) => entry.player.id === 9);
    expect(scorer?.rating).toBe(8.4);
    expect(scorer?.player.rating).toBe(8.4);
    expect(scorer?.matchStats?.goals).toBe(2);

    const unrated = merged.home?.startXI.find((entry) => entry.player.id === 2);
    expect(unrated?.rating).toBeNull();
  });
});

describe('player profiles', () => {
  it('reads age, nationality and the busiest season', () => {
    const player = mapPlayer(envelopeResponse(playerProfilePayload)[0])!;
    expect(player.id).toBe(276);
    expect(player.age).toBe(24);
    expect(player.nationality).toBe('Brazil');
    expect(player.height).toBe('175 cm');
    expect(player.birthPlace).toBe('Riverside');
    expect(player.seasonStats).toHaveLength(2);

    // The league with the most minutes is the one summarised.
    expect(player.clubTeam).toBe('Riverside United');
    expect(player.position).toBe('Attacker');
    expect(player.rating).toBeCloseTo(7.833333, 6);
    expect(player.seasonStats[0]?.appearances).toBe(28);
    expect(player.seasonStats[0]?.goals).toBe(14);
    expect(player.seasonStats[0]?.minutes).toBe(2240);
  });
});

describe('events and statistics', () => {
  it('classifies events and formats added time', () => {
    const events = envelopeResponse(eventsPayload)
      .map((entry, index) => mapEvent(entry, index))
      .filter(Boolean);
    expect(events).toHaveLength(2);

    const card = events.find((event) => event?.type === 'Card')!;
    expect(eventKind(card.type, card.detail)).toBe('yellowCard');
    expect(card.minute).toBe(45);
    expect(card.extraMinute).toBe(2);

    const goal = events.find((event) => event?.type === 'Goal')!;
    expect(eventKind(goal.type, goal.detail)).toBe('goal');
    expect(goal.assistName).toBe('Ken Ito');
  });

  it('keeps statistic values as strings and drops nulls', () => {
    const stats = mapTeamStatistics(envelopeResponse(statisticsPayload)[0])!;
    expect(stats.values['Ball Possession']).toBe('58%');
    expect(stats.values['Shots on Goal']).toBe('6');
    expect(stats.values['Red Cards']).toBeUndefined();
  });
});

describe('loose primitives and errors', () => {
  it('reads numbers however they arrive', () => {
    expect(num('85')).toBe(85);
    expect(num('87%')).toBe(87);
    expect(num(7)).toBe(7);
    expect(num(null)).toBeNull();
    expect(num('abc')).toBeNull();
    expect(int('85.6')).toBe(85);
    expect(str(12)).toBe('12');
    expect(str(null)).toBeNull();
  });

  it('understands both shapes of the errors field', () => {
    expect(errorMessages(fixturesPayload.errors)).toEqual({});
    expect(errorMessages(tokenErrorPayload.errors)).toEqual({ token: 'Error/Missing application key.' });
    expect(errorMessages(rateLimitErrorPayload.errors).requests).toContain('request limit');
  });

  it('treats a missing response as empty', () => {
    expect(envelopeResponse({ results: 0 })).toEqual([]);
    expect(envelopeResponse(null)).toEqual([]);
  });
});
