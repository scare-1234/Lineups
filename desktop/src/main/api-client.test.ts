import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { promises as fs } from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { ApiClient } from './api-client';
import { ConfigStore } from './config-store';
import { DiskCache } from './disk-cache';
import { envelopeResponse, mapFixture } from '../shared/mapping';
import { fixturesPayload, rateLimitErrorPayload, tokenErrorPayload } from '../shared/__fixtures__/sample-json';

const transform = (payload: unknown) => envelopeResponse(payload).map(mapFixture).filter(Boolean);

function jsonResponse(body: unknown, status = 200, headers: Record<string, string> = {}): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json', ...headers },
  });
}

describe('ApiClient', () => {
  let directory: string;
  let cache: DiskCache;
  let config: ConfigStore;
  let calls: string[];

  beforeEach(async () => {
    directory = await fs.mkdtemp(path.join(os.tmpdir(), 'lineuplab-test-'));
    cache = new DiskCache(path.join(directory, 'cache'));
    config = new ConfigStore(path.join(directory, 'config.json'));
    await config.setApiKey('test-key');
    calls = [];
  });

  afterEach(async () => {
    await fs.rm(directory, { recursive: true, force: true });
  });

  function makeClient(responses: (() => Promise<Response>)[], maxRetries = 2): ApiClient {
    let index = 0;
    const fetchImpl = (async (input: RequestInfo | URL) => {
      calls.push(String(input));
      const next = responses[Math.min(index, responses.length - 1)];
      index += 1;
      if (!next) throw new Error('no stubbed response');
      return next();
    }) as typeof fetch;

    return new ApiClient(config, cache, {
      fetchImpl,
      maxRetries,
      initialBackoffMs: 0,
      sleep: async () => {},
    });
  }

  const fixturesRequest = { path: 'fixtures', query: { date: '2026-09-11' } } as const;

  it('decodes a successful response and reports the network as the source', async () => {
    const client = makeClient([async () => jsonResponse(fixturesPayload)]);
    const result = await client.request(fixturesRequest, transform);

    expect(result.ok).toBe(true);
    if (!result.ok) return;
    expect(result.value).toHaveLength(2);
    expect(result.source).toEqual({ kind: 'network' });
    expect(calls).toHaveLength(1);
    expect(calls[0]).toContain('date=2026-09-11');
  });

  it('sends the API key as a header, never in the query string', async () => {
    let headers: Headers | undefined;
    const fetchImpl = (async (input: RequestInfo | URL, init?: RequestInit) => {
      calls.push(String(input));
      headers = new Headers(init?.headers);
      return jsonResponse(fixturesPayload);
    }) as typeof fetch;
    const client = new ApiClient(config, cache, { fetchImpl, sleep: async () => {} });

    await client.request(fixturesRequest, transform);

    expect(headers?.get('x-apisports-key')).toBe('test-key');
    expect(calls[0]).not.toContain('test-key');
  });

  it('reports a missing key as a setup problem without calling the network', async () => {
    await config.clearApiKey();
    const client = makeClient([async () => jsonResponse(fixturesPayload)]);

    const result = await client.request(fixturesRequest, transform);

    expect(result.ok).toBe(false);
    if (result.ok) return;
    expect(result.error.kind).toBe('configuration');
    expect(result.error.needsSetup).toBe(true);
    expect(calls).toHaveLength(0);
  });

  it('maps 401 and token errors to an invalid key', async () => {
    const unauthorised = await makeClient([async () => jsonResponse({}, 401)]).request(fixturesRequest, transform);
    expect(unauthorised.ok).toBe(false);
    if (!unauthorised.ok) {
      expect(unauthorised.error.kind).toBe('invalidKey');
      expect(unauthorised.error.needsSetup).toBe(true);
    }

    const tokenError = await makeClient([async () => jsonResponse(tokenErrorPayload)]).request(
      fixturesRequest,
      transform,
    );
    expect(tokenError.ok).toBe(false);
    if (!tokenError.ok) expect(tokenError.error.kind).toBe('invalidKey');
  });

  it('maps a quota payload to a rate limit', async () => {
    const result = await makeClient([async () => jsonResponse(rateLimitErrorPayload)]).request(
      fixturesRequest,
      transform,
    );
    expect(result.ok).toBe(false);
    if (!result.ok) expect(result.error.kind).toBe('rateLimited');
  });

  it('maps 404 to not found', async () => {
    const result = await makeClient([async () => jsonResponse({}, 404)]).request(fixturesRequest, transform);
    expect(result.ok).toBe(false);
    if (!result.ok) expect(result.error.kind).toBe('notFound');
  });

  it('retries 429 and then serves cached data', async () => {
    const warm = makeClient([async () => jsonResponse(fixturesPayload)]);
    const first = await warm.request(fixturesRequest, transform);
    expect(first.ok).toBe(true);

    calls = [];
    const limited = makeClient([async () => jsonResponse({}, 429)], 2);
    const second = await limited.request({ ...fixturesRequest, freshness: 'always' }, transform);

    expect(second.ok).toBe(true);
    if (!second.ok) return;
    expect(second.value).toHaveLength(2);
    expect(second.source).toMatchObject({ kind: 'cache', reason: 'rateLimited' });
    // One initial attempt plus two retries.
    expect(calls).toHaveLength(3);
  });

  it('fails with a rate limit when nothing is cached', async () => {
    const client = makeClient([async () => jsonResponse({}, 429)], 1);
    const result = await client.request(fixturesRequest, transform);

    expect(result.ok).toBe(false);
    if (!result.ok) expect(result.error.kind).toBe('rateLimited');
    expect(calls).toHaveLength(2);
  });

  it('falls back to cached data when the machine is offline', async () => {
    await makeClient([async () => jsonResponse(fixturesPayload)]).request(fixturesRequest, transform);

    const offline = makeClient([
      async () => {
        throw new TypeError('fetch failed');
      },
    ]);
    const result = await offline.request({ ...fixturesRequest, freshness: 'always' }, transform);

    expect(result.ok).toBe(true);
    if (result.ok) expect(result.source).toMatchObject({ kind: 'cache', reason: 'offline' });
  });

  it('reports being offline when there is no cache', async () => {
    const client = makeClient([
      async () => {
        throw new TypeError('fetch failed');
      },
    ]);
    const result = await client.request(fixturesRequest, transform);

    expect(result.ok).toBe(false);
    if (!result.ok) expect(result.error.kind).toBe('offline');
  });

  it('serves a fresh cache without spending a request', async () => {
    const client = makeClient([async () => jsonResponse(fixturesPayload)]);
    const first = await client.request({ ...fixturesRequest, freshness: 'reference' }, transform);
    expect(first.ok && first.source).toEqual({ kind: 'network' });
    expect(calls).toHaveLength(1);

    const second = await client.request({ ...fixturesRequest, freshness: 'reference' }, transform);
    expect(second.ok).toBe(true);
    if (second.ok) expect(second.source).toMatchObject({ kind: 'cache', reason: 'fresh' });
    expect(calls, 'a fresh cache must not spend a request').toHaveLength(1);
  });

  it('goes back to the network once the cache is stale', async () => {
    const client = new ApiClient(config, cache, {
      fetchImpl: (async () => {
        calls.push('call');
        return jsonResponse(fixturesPayload);
      }) as typeof fetch,
      sleep: async () => {},
      // Pretend it is a day later than whatever the cache recorded.
      now: () => new Date(Date.now() + 24 * 60 * 60 * 1000),
    });

    await client.request({ ...fixturesRequest, freshness: 'live' }, transform);
    await client.request({ ...fixturesRequest, freshness: 'live' }, transform);
    expect(calls).toHaveLength(2);
  });

  it('reports unreadable payloads as a decoding problem', async () => {
    const fetchImpl = (async () => new Response('not json', { status: 200 })) as typeof fetch;
    const client = new ApiClient(config, cache, { fetchImpl, sleep: async () => {} });
    const result = await client.request(fixturesRequest, transform);

    expect(result.ok).toBe(false);
    if (!result.ok) expect(result.error.kind).toBe('decoding');
  });
});

describe('DiskCache', () => {
  it('hashes keys into stable, file-system-safe names', () => {
    const name = DiskCache.fileName('https://v3.football.api-sports.io/fixtures?date=2026-09-11');
    expect(name).toBe(DiskCache.fileName('https://v3.football.api-sports.io/fixtures?date=2026-09-11'));
    expect(name).not.toBe(DiskCache.fileName('https://v3.football.api-sports.io/fixtures?date=2026-09-12'));
    expect(name).not.toContain('/');
    expect(name.endsWith('.json')).toBe(true);
  });

  it('reads back what it writes and clears on request', async () => {
    const directory = await fs.mkdtemp(path.join(os.tmpdir(), 'lineuplab-cache-'));
    const cache = new DiskCache(directory);

    expect(await cache.read('missing')).toBeNull();
    await cache.write('key', '{"a":1}');
    const entry = await cache.read('key');
    expect(entry?.text).toBe('{"a":1}');
    expect(entry?.storedAt).toBeInstanceOf(Date);

    expect(await cache.clear()).toBe(1);
    expect(await cache.read('key')).toBeNull();
    await fs.rm(directory, { recursive: true, force: true });
  });
});
