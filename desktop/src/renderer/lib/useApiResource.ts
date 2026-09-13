import { useCallback, useEffect, useState } from 'react';
import type { ApiErrorPayload, ApiResponse, DataSource } from '../../shared/api';

export interface ResourceState<T> {
  data: T | null;
  error: ApiErrorPayload | null;
  source: DataSource | null;
  loading: boolean;
  reload: () => void;
}

/**
 * Runs an IPC call and tracks loading, errors and where the data came from, so every
 * screen can show the same cached/offline banner.
 */
export function useApiResource<T>(
  loader: () => Promise<ApiResponse<T>>,
  deps: unknown[],
  options: { enabled?: boolean } = {},
): ResourceState<T> {
  const enabled = options.enabled ?? true;
  const [data, setData] = useState<T | null>(null);
  const [error, setError] = useState<ApiErrorPayload | null>(null);
  const [source, setSource] = useState<DataSource | null>(null);
  const [loading, setLoading] = useState(enabled);
  const [nonce, setNonce] = useState(0);

  const reload = useCallback(() => setNonce((value) => value + 1), []);

  useEffect(() => {
    if (!enabled) {
      setLoading(false);
      return;
    }
    let cancelled = false;
    setLoading(true);
    loader()
      .then((response) => {
        if (cancelled) return;
        if (response.ok) {
          setData(response.value);
          setSource(response.source);
          setError(null);
        } else {
          setError(response.error);
          setSource(null);
        }
      })
      .catch((cause: unknown) => {
        if (cancelled) return;
        setError({
          kind: 'server',
          message: cause instanceof Error ? cause.message : 'Something went wrong.',
          needsSetup: false,
        });
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [...deps, nonce, enabled]);

  return { data, error, source, loading, reload };
}

/** Cached data only earns a banner when it is stale — a fresh cache hit is invisible. */
export function bannerFor(source: DataSource | null): { message: string; glyph: string } | null {
  if (!source || source.kind !== 'cache' || source.reason === 'fresh') return null;
  switch (source.reason) {
    case 'offline':
      return { message: 'Offline — showing cached data', glyph: '📡' };
    case 'rateLimited':
      return { message: 'Daily limit reached. Cached data shown.', glyph: '⏳' };
    default:
      return { message: 'Showing cached data', glyph: '💾' };
  }
}
