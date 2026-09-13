import type { ApiErrorKind, ApiErrorPayload, ApiResponse, CacheReason } from '../shared/api';
import { errorMessages } from '../shared/mapping';
import type { ConfigStore } from './config-store';
import type { DiskCache } from './disk-cache';

export type Freshness = 'live' | 'reference' | 'always';

/** Live data is good for five minutes; profiles, leagues and standings for a day. */
export const TTL: Record<Freshness, number> = {
  live: 5 * 60 * 1000,
  reference: 24 * 60 * 60 * 1000,
  always: 0,
};

export interface ApiClientOptions {
  maxRetries?: number;
  initialBackoffMs?: number;
  requestTimeoutMs?: number;
  sleep?: (ms: number) => Promise<void>;
  fetchImpl?: typeof fetch;
  now?: () => Date;
}

export interface RequestOptions {
  path: string;
  query?: Record<string, string | number>;
  freshness?: Freshness;
}

function failure(kind: ApiErrorKind, message: string, needsSetup = false): { ok: false; error: ApiErrorPayload } {
  return { ok: false, error: { kind, message, needsSetup } };
}

const MESSAGES: Record<ApiErrorKind, string> = {
  configuration: 'Add your API-Football key in Settings to load live data.',
  invalidKey: 'Your API key was rejected. Check it in Settings.',
  rateLimited: 'Daily limit reached. Cached data shown where available.',
  offline: "You're offline. Connect to the internet to load fresh data.",
  notFound: 'That data could not be found.',
  server: 'The football data service is unavailable right now.',
  decoding: 'The server returned data LineupLab could not read.',
  service: 'The football data service reported a problem.',
  empty: 'No data was returned for this request.',
};

/**
 * Networking for API-Football. Runs in the main process so the API key never reaches
 * the renderer and there is no CORS to work around.
 *
 * - Fresh cache hits skip the network entirely, protecting the daily quota.
 * - 429 is retried with exponential backoff, then falls back to cached data.
 * - Connectivity failures fall back to cached data.
 * - Nothing throws: every path returns a typed result that survives IPC.
 */
export class ApiClient {
  private readonly maxRetries: number;
  private readonly initialBackoffMs: number;
  private readonly requestTimeoutMs: number;
  private readonly sleep: (ms: number) => Promise<void>;
  private readonly fetchImpl: typeof fetch;
  private readonly now: () => Date;

  constructor(
    private readonly config: ConfigStore,
    private readonly cache: DiskCache,
    options: ApiClientOptions = {},
  ) {
    this.maxRetries = options.maxRetries ?? 3;
    this.initialBackoffMs = options.initialBackoffMs ?? 1000;
    this.requestTimeoutMs = options.requestTimeoutMs ?? 20000;
    this.sleep = options.sleep ?? ((ms) => new Promise((resolve) => setTimeout(resolve, ms)));
    this.fetchImpl = options.fetchImpl ?? ((input, init) => fetch(input, init));
    this.now = options.now ?? (() => new Date());
  }

  private url(request: RequestOptions): string {
    const base = this.config.baseUrl.replace(/\/+$/, '');
    const path = request.path.replace(/^\/+/, '');
    const url = new URL(`${base}/${path}`);
    for (const [key, value] of Object.entries(request.query ?? {}).sort(([a], [b]) => a.localeCompare(b))) {
      url.searchParams.set(key, String(value));
    }
    return url.toString();
  }

  private backoff(attempt: number, retryAfter: string | null): number {
    const parsed = retryAfter ? Number(retryAfter) : Number.NaN;
    if (Number.isFinite(parsed) && parsed > 0) return Math.min(parsed * 1000, 30000);
    // 1s, 2s, 4s … plus jitter so parallel requests do not sync up.
    return this.initialBackoffMs * 2 ** attempt + Math.random() * 300;
  }

  private async cached<T>(
    key: string,
    reason: CacheReason,
    transform: (payload: unknown) => T,
  ): Promise<ApiResponse<T> | null> {
    const entry = await this.cache.read(key);
    if (!entry) return null;
    try {
      return {
        ok: true,
        value: transform(JSON.parse(entry.text)),
        source: { kind: 'cache', storedAt: entry.storedAt.toISOString(), reason },
      };
    } catch {
      return null;
    }
  }

  /** API-Football answers 200 with an `errors` payload for quota and token problems. */
  private serviceError(payload: unknown): ApiErrorPayload | null {
    const messages = errorMessages((payload as Record<string, unknown> | null)?.errors);
    const entries = Object.entries(messages);
    if (entries.length === 0) return null;

    const joined = entries.map(([key, value]) => `${key}: ${value}`).join('\n');
    const lowered = joined.toLowerCase();
    if (lowered.includes('token') || lowered.includes('api key') || lowered.includes('apikey')) {
      return { kind: 'invalidKey', message: MESSAGES.invalidKey, needsSetup: true };
    }
    if (lowered.includes('requests') || lowered.includes('rate') || lowered.includes('limit')) {
      return { kind: 'rateLimited', message: MESSAGES.rateLimited, needsSetup: false };
    }
    return { kind: 'service', message: joined, needsSetup: false };
  }

  async request<T>(request: RequestOptions, transform: (payload: unknown) => T): Promise<ApiResponse<T>> {
    if (!this.config.isConfigured) {
      return failure('configuration', MESSAGES.configuration, true);
    }

    const freshness = request.freshness ?? 'live';
    const key = this.url(request);

    if (freshness !== 'always') {
      const entry = await this.cache.read(key);
      if (entry && this.now().getTime() - entry.storedAt.getTime() <= TTL[freshness]) {
        try {
          return {
            ok: true,
            value: transform(JSON.parse(entry.text)),
            source: { kind: 'cache', storedAt: entry.storedAt.toISOString(), reason: 'fresh' },
          };
        } catch {
          // A corrupt cache entry just means we go to the network.
        }
      }
    }

    let attempt = 0;
    let lastKind: ApiErrorKind = 'server';

    while (attempt <= this.maxRetries) {
      let response: Response;
      try {
        response = await this.fetchImpl(key, {
          method: 'GET',
          headers: {
            'x-apisports-key': this.config.apiKey,
            accept: 'application/json',
          },
          signal: AbortSignal.timeout(this.requestTimeoutMs),
        });
      } catch {
        // fetch only rejects for connectivity, abort and timeout problems.
        const stale = await this.cached(key, 'offline', transform);
        return stale ?? failure('offline', MESSAGES.offline);
      }

      if (response.status === 401 || response.status === 403) {
        return failure('invalidKey', MESSAGES.invalidKey, true);
      }
      if (response.status === 404) {
        return failure('notFound', MESSAGES.notFound);
      }

      if (response.status === 429 || response.status >= 500) {
        const reason: CacheReason = response.status === 429 ? 'rateLimited' : 'serverError';
        lastKind = response.status === 429 ? 'rateLimited' : 'server';
        if (attempt === this.maxRetries) {
          const stale = await this.cached(key, reason, transform);
          return stale ?? failure(lastKind, MESSAGES[lastKind]);
        }
        await this.sleep(this.backoff(attempt, response.headers.get('retry-after')));
        attempt += 1;
        continue;
      }

      if (!response.ok) {
        return failure('server', MESSAGES.server);
      }

      const text = await response.text().catch(() => '');
      let payload: unknown;
      try {
        payload = JSON.parse(text);
      } catch {
        return failure('decoding', MESSAGES.decoding);
      }

      const serviceError = this.serviceError(payload);
      if (serviceError) {
        if (serviceError.kind === 'rateLimited') {
          const stale = await this.cached(key, 'rateLimited', transform);
          if (stale) return stale;
        }
        return { ok: false, error: serviceError };
      }

      try {
        const value = transform(payload);
        await this.cache.write(key, text);
        return { ok: true, value, source: { kind: 'network' } };
      } catch {
        return failure('decoding', MESSAGES.decoding);
      }
    }

    const stale = await this.cached(key, 'rateLimited', transform);
    return stale ?? failure(lastKind, MESSAGES[lastKind]);
  }
}
