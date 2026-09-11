import Foundation

// MARK: - Endpoint

/// How long a response stays fresh before the client goes back to the network.
enum CacheFreshness: Sendable, Hashable {
    /// Fixtures, lineups, live stats — five minutes.
    case live
    /// Player profiles, leagues, standings — a day.
    case reference
    /// Always hit the network (used by search).
    case always

    var ttl: TimeInterval {
        switch self {
        case .live: AppConstants.liveCacheTTL
        case .reference: AppConstants.referenceCacheTTL
        case .always: 0
        }
    }
}

struct Endpoint: Hashable, Sendable {
    let path: String
    let queryItems: [URLQueryItem]
    let freshness: CacheFreshness

    init(path: String, queryItems: [URLQueryItem] = [], freshness: CacheFreshness = .live) {
        self.path = path.hasPrefix("/") ? String(path.dropFirst()) : path
        self.queryItems = queryItems.sorted { $0.name < $1.name }
        self.freshness = freshness
    }
}

// MARK: - Results

/// Where a value came from, so the UI can show an "offline"/"cached" banner.
enum DataSource: Sendable, Hashable {
    case network
    case cache(storedAt: Date, reason: CacheReason)

    var isCache: Bool {
        if case .cache = self { return true }
        return false
    }
}

enum CacheReason: Sendable, Hashable {
    case fresh
    case offline
    case rateLimited
    case serverError
}

struct APIResponse<Value: Sendable>: Sendable {
    let value: Value
    let source: DataSource

    func map<T: Sendable>(_ transform: (Value) throws -> T) rethrows -> APIResponse<T> {
        APIResponse<T>(value: try transform(value), source: source)
    }
}

// MARK: - Errors

enum APIError: Error, Equatable, LocalizedError {
    case configuration(ConfigurationError)
    case invalidURL
    case invalidKey
    case rateLimited
    case offline
    case notFound
    case server(status: Int)
    case decoding(String)
    case service(String)
    case empty

    var errorDescription: String? {
        switch self {
        case .configuration(let error): error.errorDescription
        case .invalidURL: L10n.Errors.server
        case .invalidKey: L10n.Setup.invalidKey
        case .rateLimited: L10n.Errors.rateLimited
        case .offline: L10n.Errors.offline
        case .notFound: L10n.Errors.notFound
        case .server: L10n.Errors.server
        case .decoding: L10n.Errors.decoding
        case .service(let message): message
        case .empty: L10n.Errors.emptyResponse
        }
    }

    /// Errors the UI answers with setup instructions rather than a retry button.
    var needsSetup: Bool {
        switch self {
        case .configuration, .invalidKey: true
        default: false
        }
    }
}

// MARK: - Protocol

protocol APIClientProtocol: Sendable {
    func fetch<T: Decodable & Sendable>(_ endpoint: Endpoint, as type: T.Type) async throws -> APIResponse<T>
}

extension APIClientProtocol {
    func fetch<T: Decodable & Sendable>(_ endpoint: Endpoint) async throws -> APIResponse<T> {
        try await fetch(endpoint, as: T.self)
    }
}

// MARK: - Live implementation

/// Generic async/await networking for API-Football.
///
/// * Adds the `x-apisports-key` header from `AppConfig`.
/// * Serves fresh cached data without touching the network to protect the daily quota.
/// * Retries 429s with exponential backoff, then falls back to stale cache.
/// * Falls back to stale cache when the device is offline.
final class APIClient: APIClientProtocol, @unchecked Sendable {

    private let config: AppConfig
    private let session: URLSession
    private let cache: CacheManager
    private let decoder: JSONDecoder
    private let maxRetries: Int
    private let initialBackoff: TimeInterval
    private let sleeper: @Sendable (TimeInterval) async throws -> Void

    init(
        config: AppConfig,
        session: URLSession = CacheManager.makeSession(),
        cache: CacheManager = CacheManager(),
        maxRetries: Int = AppConstants.maxRetries,
        initialBackoff: TimeInterval = AppConstants.initialBackoff,
        sleeper: (@Sendable (TimeInterval) async throws -> Void)? = nil
    ) {
        self.config = config
        self.session = session
        self.cache = cache
        self.maxRetries = maxRetries
        self.initialBackoff = initialBackoff
        self.decoder = APIClient.makeDecoder()
        self.sleeper = sleeper ?? { seconds in
            try await Task.sleep(for: .seconds(seconds))
        }
    }

    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            guard let date = APIDateParsing.date(fromISO8601: raw) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unrecognised date: \(raw)")
            }
            return date
        }
        return decoder
    }

    func fetch<T: Decodable & Sendable>(_ endpoint: Endpoint, as type: T.Type) async throws -> APIResponse<T> {
        let request = try makeRequest(for: endpoint)
        guard let key = request.url?.absoluteString else { throw APIError.invalidURL }

        // 1. Fresh cache wins: it costs no quota at all.
        if endpoint.freshness != .always, let cached = await cache.entry(forKey: key),
           cached.isFresh(within: endpoint.freshness.ttl),
           let value = try? decode(type, from: cached.data) {
            return APIResponse(value: value, source: .cache(storedAt: cached.storedAt, reason: .fresh))
        }

        var attempt = 0
        var lastError: APIError = .server(status: 0)

        while attempt <= maxRetries {
            do {
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else {
                    throw APIError.server(status: 0)
                }

                switch http.statusCode {
                case 200..<300:
                    try validateServiceErrors(in: data)
                    let value = try decode(type, from: data)
                    await cache.store(data, forKey: key)
                    return APIResponse(value: value, source: .network)

                case 401, 403:
                    throw APIError.invalidKey

                case 404:
                    throw APIError.notFound

                case 429:
                    lastError = .rateLimited
                    if attempt == maxRetries {
                        if let stale = await staleResponse(type, key: key, reason: .rateLimited) { return stale }
                        throw APIError.rateLimited
                    }
                    try await sleeper(backoff(for: attempt, retryAfter: http.value(forHTTPHeaderField: "Retry-After")))
                    attempt += 1
                    continue

                case 500...599:
                    lastError = .server(status: http.statusCode)
                    if attempt == maxRetries {
                        if let stale = await staleResponse(type, key: key, reason: .serverError) { return stale }
                        throw lastError
                    }
                    try await sleeper(backoff(for: attempt, retryAfter: nil))
                    attempt += 1
                    continue

                default:
                    throw APIError.server(status: http.statusCode)
                }
            } catch let error as APIError {
                throw error
            } catch let error as DecodingError {
                throw APIError.decoding(String(describing: error))
            } catch let error as URLError where APIClient.isConnectivityError(error) {
                if let stale = await staleResponse(type, key: key, reason: .offline) { return stale }
                throw APIError.offline
            } catch {
                throw APIError.server(status: 0)
            }
        }

        if let stale = await staleResponse(type, key: key, reason: .rateLimited) { return stale }
        throw lastError
    }

    // MARK: - Helpers

    private func makeRequest(for endpoint: Endpoint) throws -> URLRequest {
        guard var components = URLComponents(
            url: config.baseURL.appendingPathComponent(endpoint.path),
            resolvingAgainstBaseURL: false
        ) else { throw APIError.invalidURL }

        if endpoint.queryItems.isEmpty == false {
            components.queryItems = endpoint.queryItems
        }
        guard let url = components.url else { throw APIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(config.apiKey, forHTTPHeaderField: "x-apisports-key")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = AppConstants.requestTimeout
        return request
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try decoder.decode(type, from: data)
        } catch let error as DecodingError {
            throw APIError.decoding(String(describing: error))
        }
    }

    /// API-Football answers 200 with an `errors` payload for quota and token problems.
    private func validateServiceErrors(in data: Data) throws {
        guard let probe = try? decoder.decode(APIErrorProbe.self, from: data),
              probe.errors.messages.isEmpty == false else { return }

        let joined = probe.errors.messages
            .map { "\($0.key): \($0.value)" }
            .sorted()
            .joined(separator: "\n")
        let lowered = joined.lowercased()

        if lowered.contains("token") || lowered.contains("api key") || lowered.contains("apikey") {
            throw APIError.invalidKey
        }
        if lowered.contains("requests") || lowered.contains("rate") || lowered.contains("limit") {
            throw APIError.rateLimited
        }
        throw APIError.service(joined)
    }

    private func staleResponse<T: Decodable & Sendable>(
        _ type: T.Type,
        key: String,
        reason: CacheReason
    ) async -> APIResponse<T>? {
        guard let cached = await cache.entry(forKey: key),
              let value = try? decode(type, from: cached.data) else { return nil }
        return APIResponse(value: value, source: .cache(storedAt: cached.storedAt, reason: reason))
    }

    private func backoff(for attempt: Int, retryAfter: String?) -> TimeInterval {
        if let retryAfter, let seconds = TimeInterval(retryAfter), seconds > 0 {
            return min(seconds, 30)
        }
        // 1s, 2s, 4s … plus a little jitter so parallel requests do not sync up.
        let exponential = initialBackoff * pow(2, Double(attempt))
        return exponential + Double.random(in: 0...0.3)
    }

    static func isConnectivityError(_ error: URLError) -> Bool {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost, .timedOut,
             .cannotConnectToHost, .cannotFindHost, .dataNotAllowed, .internationalRoamingOff,
             .secureConnectionFailed:
            true
        default:
            false
        }
    }
}

/// Minimal shape used to sniff the `errors` field before decoding the real payload.
private struct APIErrorProbe: Decodable {
    let errors: APIErrorPayload
}
