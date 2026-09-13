import { ratingColor, ratingForeground, ratingText } from '../../shared/rating';
import type { Fixture } from '../../shared/types';
import { statusKind } from '../../shared/mapping';

export function RatingBadge({ rating, size = 28 }: { rating: number | null; size?: number }) {
  return (
    <span
      className="rating"
      style={{
        width: size,
        height: size,
        fontSize: Math.round(size * 0.42),
        background: ratingColor(rating),
        color: ratingForeground(rating),
      }}
      title={rating === null ? 'No rating yet' : `Match rating ${ratingText(rating)}`}
      aria-label={rating === null ? 'No rating' : `Rating ${ratingText(rating)}`}
    >
      {ratingText(rating)}
    </span>
  );
}

export function StatusBadge({ fixture }: { fixture: Fixture }) {
  const kind = statusKind(fixture.status);
  if (kind === 'live' || kind === 'halfTime') {
    return (
      <span className="live-badge">
        <span className="live-dot" />
        {kind === 'halfTime' ? 'HT' : fixture.elapsed ? `${fixture.elapsed}'` : 'LIVE'}
      </span>
    );
  }
  const label =
    kind === 'finished' ? 'FT' : kind === 'postponed' ? 'PST' : fixture.status.toUpperCase();
  return <span className="status-badge">{label}</span>;
}
