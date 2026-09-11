import Foundation

/// Two layers of caching:
///
/// 1. `URLCache` on the `URLSession` so HTTP-level revalidation is free.
/// 2. A small on-disk store keyed by request URL, which enforces LineupLab's own TTLs
///    (5 minutes for live data, 24 hours for player/league data) and — just as important
///    on a 100-requests-a-day plan — keeps serving data when the network or the quota is gone.
actor CacheManager {

    struct Entry: Sendable {
        let data: Data
        let storedAt: Date

        var age: TimeInterval { Date().timeIntervalSince(storedAt) }

        func isFresh(within ttl: TimeInterval) -> Bool { age <= ttl }
    }

    private let directory: URL?
    private let fileManager: FileManager

    init(directoryName: String = "APIResponses", fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
        if let caches {
            let directory = caches.appendingPathComponent("LineupLab", isDirectory: true)
                .appendingPathComponent(directoryName, isDirectory: true)
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            self.directory = directory
        } else {
            self.directory = nil
        }
    }

    func entry(forKey key: String) -> Entry? {
        guard let url = fileURL(forKey: key),
              let data = try? Data(contentsOf: url) else { return nil }
        let attributes = try? fileManager.attributesOfItem(atPath: url.path)
        let storedAt = (attributes?[.modificationDate] as? Date) ?? .distantPast
        return Entry(data: data, storedAt: storedAt)
    }

    func store(_ data: Data, forKey key: String) {
        guard let url = fileURL(forKey: key) else { return }
        try? data.write(to: url, options: .atomic)
    }

    func remove(forKey key: String) {
        guard let url = fileURL(forKey: key) else { return }
        try? fileManager.removeItem(at: url)
    }

    func removeAll() {
        guard let directory else { return }
        let contents = (try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        for url in contents {
            try? fileManager.removeItem(at: url)
        }
    }

    /// Drops entries older than `maxAge` so the cache directory cannot grow forever.
    func prune(olderThan maxAge: TimeInterval = 7 * 24 * 60 * 60) {
        guard let directory else { return }
        let contents = (try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey]
        )) ?? []
        let cutoff = Date().addingTimeInterval(-maxAge)
        for url in contents {
            let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
            if let modified = values?.contentModificationDate, modified < cutoff {
                try? fileManager.removeItem(at: url)
            }
        }
    }

    private func fileURL(forKey key: String) -> URL? {
        guard let directory else { return nil }
        return directory.appendingPathComponent(CacheManager.fileName(forKey: key))
    }

    /// FNV-1a keeps keys short, stable and free of characters the file system dislikes.
    static func fileName(forKey key: String) -> String {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in Array(key.utf8) {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01B3
        }
        return String(format: "%016llx.json", hash)
    }

    // MARK: - URLSession plumbing

    /// A session backed by a generously sized `URLCache`.
    static func makeSession(
        memoryCapacity: Int = AppConstants.memoryCacheCapacity,
        diskCapacity: Int = AppConstants.diskCacheCapacity
    ) -> URLSession {
        let cache = URLCache(memoryCapacity: memoryCapacity, diskCapacity: diskCapacity, directory: nil)
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = cache
        configuration.requestCachePolicy = .useProtocolCachePolicy
        configuration.timeoutIntervalForRequest = AppConstants.requestTimeout
        configuration.waitsForConnectivity = false
        configuration.httpAdditionalHeaders = ["Accept": "application/json"]
        return URLSession(configuration: configuration)
    }
}
