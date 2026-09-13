import { describe, expect, it } from 'vitest';
import { flagEmoji, flagLabel, regionalIndicator, subdivisionFlag } from './flags';
import { NATIONAL_TEAM_COUNTRIES } from './leagues';

describe('nationality flags', () => {
  it('maps common football nations', () => {
    expect(flagEmoji('Brazil')).toBe('🇧🇷');
    expect(flagEmoji('France')).toBe('🇫🇷');
    expect(flagEmoji('Japan')).toBe('🇯🇵');
    expect(flagEmoji('Nigeria')).toBe('🇳🇬');
    expect(flagEmoji('Argentina')).toBe('🇦🇷');
  });

  it('handles aliases, case and diacritics', () => {
    expect(flagEmoji('brazil')).toBe('🇧🇷');
    expect(flagEmoji('  Brazil  ')).toBe('🇧🇷');
    expect(flagEmoji('USA')).toBe(flagEmoji('United States'));
    expect(flagEmoji('Czechia')).toBe(flagEmoji('Czech Republic'));
    expect(flagEmoji("Côte d'Ivoire")).toBe(flagEmoji('Ivory Coast'));
    expect(flagEmoji('Korea Republic')).toBe(flagEmoji('South Korea'));
  });

  it('uses subdivision flags for the home nations', () => {
    expect(flagEmoji('England')).toBe(subdivisionFlag('gbeng'));
    expect(flagEmoji('England')).not.toBe(flagEmoji('United Kingdom'));
    expect(flagEmoji('Scotland')).not.toBeNull();
    expect(flagEmoji('Wales')).not.toBeNull();
  });

  it('returns null for unknown countries so the UI can show text', () => {
    expect(flagEmoji('Atlantis')).toBeNull();
    expect(flagEmoji('')).toBeNull();
    expect(flagEmoji(null)).toBeNull();
  });

  it('falls back to the plain country name', () => {
    expect(flagLabel('Brazil')).toBe('🇧🇷 Brazil');
    expect(flagLabel('Atlantis')).toBe('Atlantis');
    expect(flagLabel(null)).toBe('Unknown');
    expect(flagLabel('   ')).toBe('Unknown');
  });

  it('builds regional indicators from ISO codes', () => {
    expect(regionalIndicator('br')).toBe('🇧🇷');
    expect(regionalIndicator('BR')).toBe('🇧🇷');
    expect(regionalIndicator('BRA')).toBeNull();
    expect(regionalIndicator('1')).toBeNull();
  });

  it('has a flag for every country offered in the app', () => {
    for (const country of NATIONAL_TEAM_COUNTRIES) {
      expect(flagEmoji(country), country).not.toBeNull();
    }
  });
});
