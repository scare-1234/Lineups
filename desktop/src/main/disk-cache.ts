import { promises as fs } from 'node:fs';
import path from 'node:path';

export interface CacheEntry {
  text: string;
  storedAt: Date;
}

/**
 * TTL-aware cache of raw API responses. On a 100-requests-a-day plan this is what keeps
 * the app usable: fresh entries are served without touching the network, and stale ones
 * still answer when the quota is gone or the machine is offline.
 */
export class DiskCache {
  constructor(private readonly directory: string) {}

  /** FNV-1a keeps keys short, stable and safe as file names. */
  static fileName(key: string): string {
    let hash = 0xcbf29ce484222325n;
    const prime = 0x100000001b3n;
    const mask = 0xffffffffffffffffn;
    for (const byte of Buffer.from(key, 'utf8')) {
      hash = (hash ^ BigInt(byte)) & mask;
      hash = (hash * prime) & mask;
    }
    return `${hash.toString(16).padStart(16, '0')}.json`;
  }

  private filePath(key: string): string {
    return path.join(this.directory, DiskCache.fileName(key));
  }

  async read(key: string): Promise<CacheEntry | null> {
    try {
      const file = this.filePath(key);
      const [text, stats] = await Promise.all([fs.readFile(file, 'utf8'), fs.stat(file)]);
      return { text, storedAt: stats.mtime };
    } catch {
      return null;
    }
  }

  async write(key: string, text: string): Promise<void> {
    try {
      await fs.mkdir(this.directory, { recursive: true });
      await fs.writeFile(this.filePath(key), text, 'utf8');
    } catch {
      // A cache that cannot be written is not worth failing a request over.
    }
  }

  async clear(): Promise<number> {
    try {
      const entries = await fs.readdir(this.directory);
      await Promise.all(entries.map((entry) => fs.rm(path.join(this.directory, entry), { force: true })));
      return entries.length;
    } catch {
      return 0;
    }
  }

  /** Drops entries older than `maxAgeMs` so the cache folder cannot grow forever. */
  async prune(maxAgeMs = 7 * 24 * 60 * 60 * 1000): Promise<void> {
    try {
      const entries = await fs.readdir(this.directory);
      const cutoff = Date.now() - maxAgeMs;
      await Promise.all(
        entries.map(async (entry) => {
          const file = path.join(this.directory, entry);
          const stats = await fs.stat(file).catch(() => null);
          if (stats && stats.mtimeMs < cutoff) await fs.rm(file, { force: true });
        }),
      );
    } catch {
      // Pruning is best effort.
    }
  }
}
