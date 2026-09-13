import type { ReactNode } from 'react';
import type { ApiErrorPayload } from '../../shared/api';

export function Banner({ message, glyph }: { message: string; glyph: string }) {
  return (
    <div className="banner" role="status">
      <span aria-hidden="true">{glyph}</span>
      <span>{message}</span>
    </div>
  );
}

export function EmptyState({
  glyph = '⚽️',
  title,
  message,
  action,
}: {
  glyph?: string;
  title: string;
  message: string;
  action?: ReactNode;
}) {
  return (
    <div className="state">
      <div className="glyph" aria-hidden="true">
        {glyph}
      </div>
      <h3>{title}</h3>
      <p>{message}</p>
      {action}
    </div>
  );
}

export function ErrorState({
  error,
  onRetry,
  onOpenSettings,
}: {
  error: ApiErrorPayload;
  onRetry?: () => void;
  onOpenSettings?: () => void;
}) {
  return (
    <div className="state">
      <div className="glyph" aria-hidden="true">
        {error.needsSetup ? '🔑' : '⚠️'}
      </div>
      <h3>{error.needsSetup ? 'API key required' : 'Something went wrong'}</h3>
      <p>{error.message}</p>
      {error.needsSetup && onOpenSettings ? (
        <button type="button" className="btn primary" onClick={onOpenSettings}>
          Open settings
        </button>
      ) : null}
      {!error.needsSetup && onRetry ? (
        <button type="button" className="btn" onClick={onRetry}>
          Try again
        </button>
      ) : null}
    </div>
  );
}

export function SkeletonList({ rows = 5, height = 64 }: { rows?: number; height?: number }) {
  return (
    <div className="stack" aria-hidden="true">
      {Array.from({ length: rows }, (_, index) => (
        <div key={index} className="skeleton" style={{ height }} />
      ))}
    </div>
  );
}
