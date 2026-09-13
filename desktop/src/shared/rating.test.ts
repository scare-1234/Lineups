import { describe, expect, it } from 'vitest';
import { NO_RATING, averageRating, ratingColor, ratingText, ratingTier } from './rating';

describe('rating tiers', () => {
  it('matches the documented boundaries', () => {
    expect(ratingTier(10)).toBe('elite');
    expect(ratingTier(9)).toBe('elite');
    expect(ratingTier(8.99)).toBe('great');
    expect(ratingTier(8)).toBe('great');
    expect(ratingTier(7.9)).toBe('good');
    expect(ratingTier(7)).toBe('good');
    expect(ratingTier(6.9)).toBe('average');
    expect(ratingTier(6)).toBe('average');
    expect(ratingTier(5.9)).toBe('poor');
    expect(ratingTier(5)).toBe('poor');
    expect(ratingTier(4.99)).toBe('bad');
    expect(ratingTier(0)).toBe('bad');
  });

  it('treats a missing rating as unrated', () => {
    expect(ratingTier(null)).toBe('unrated');
    expect(ratingTier(undefined)).toBe('unrated');
    expect(ratingText(null)).toBe(NO_RATING);
  });

  it('gives every tier its own colour', () => {
    expect(ratingColor(9.2)).not.toBe(ratingColor(8.2));
    expect(ratingColor(6.5)).not.toBe(ratingColor(5.5));
    expect(ratingColor(null)).toBe(ratingColor(undefined));
  });

  it('formats to one decimal place', () => {
    expect(ratingText(7)).toBe('7.0');
    expect(ratingText(7.833333)).toBe('7.8');
    expect(ratingText(6.94)).toBe('6.9');
  });

  it('averages only the ratings that exist', () => {
    expect(averageRating([8, null, 6])).toBeCloseTo(7, 5);
    expect(averageRating([null, undefined])).toBeNull();
    expect(averageRating([])).toBeNull();
  });
});
