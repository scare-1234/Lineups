/**
 * Match rating colour scale:
 * 9.0+ dark green · 8.0–8.9 green · 7.0–7.9 light green · 6.0–6.9 yellow
 * 5.0–5.9 orange · below 5.0 red · missing ratings render as a grey dash.
 */

export type RatingTier = 'elite' | 'great' | 'good' | 'average' | 'poor' | 'bad' | 'unrated';

export const NO_RATING = '—';

export function ratingTier(rating: number | null | undefined): RatingTier {
  if (rating === null || rating === undefined || Number.isNaN(rating)) return 'unrated';
  if (rating >= 9) return 'elite';
  if (rating >= 8) return 'great';
  if (rating >= 7) return 'good';
  if (rating >= 6) return 'average';
  if (rating >= 5) return 'poor';
  return 'bad';
}

export const TIER_COLOR: Record<RatingTier, string> = {
  elite: '#1B5E20',
  great: '#2E7D32',
  good: '#66BB6A',
  average: '#FDD835',
  poor: '#FB8C00',
  bad: '#E53935',
  unrated: 'rgba(158, 158, 158, 0.18)',
};

/** Yellow backgrounds need dark text to stay legible. */
export const TIER_FOREGROUND: Record<RatingTier, string> = {
  elite: '#FFFFFF',
  great: '#FFFFFF',
  good: '#FFFFFF',
  average: 'rgba(0, 0, 0, 0.82)',
  poor: '#FFFFFF',
  bad: '#FFFFFF',
  unrated: '#9E9E9E',
};

export function ratingColor(rating: number | null | undefined): string {
  return TIER_COLOR[ratingTier(rating)];
}

export function ratingForeground(rating: number | null | undefined): string {
  return TIER_FOREGROUND[ratingTier(rating)];
}

/** One decimal place, or an em dash when the rating is missing. */
export function ratingText(rating: number | null | undefined): string {
  if (rating === null || rating === undefined || Number.isNaN(rating)) return NO_RATING;
  return rating.toFixed(1);
}

export function averageRating(ratings: (number | null | undefined)[]): number | null {
  const values = ratings.filter((value): value is number => typeof value === 'number' && !Number.isNaN(value));
  if (values.length === 0) return null;
  return values.reduce((sum, value) => sum + value, 0) / values.length;
}
