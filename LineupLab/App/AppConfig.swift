import Foundation

/// Values that are not allowed to live in source control.
///
/// The API key is read from `Configuration.plist`, which is gitignored. Copy
/// `Config/Configuration.example.plist` to `LineupLab/Resources/Configuration.plist`
/// and paste your key there. A `API_FOOTBALL_KEY` environment variable overrides the
/// file, which is handy for CI.
struct AppConfig: Sendable, Equatable {
    let apiKey: String
    let baseURL: URL
    let season: Int

    static let placeholderKey = "YOUR_API_KEY_HERE"
    static let fallbackBaseURL = "https://v3.football.api-sports.io"
    static let configurationFileName = "Configuration"
    static let environmentKeyName = "API_FOOTBALL_KEY"

    static func load(
        bundle: Bundle = .main,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Result<AppConfig, ConfigurationError> {
        let values = plistValues(in: bundle)
        let environmentKey = environment[environmentKeyName]?.trimmingCharacters(in: .whitespacesAndNewlines)

        if values == nil, (environmentKey?.isEmpty ?? true) {
            return .failure(.missingFile)
        }

        let fileKey = (values?["APIFootballKey"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = (environmentKey?.isEmpty == false ? environmentKey : fileKey) ?? ""

        guard key.isEmpty == false else { return .failure(.missingKey) }
        guard key != placeholderKey else { return .failure(.placeholderKey) }

        let rawBaseURL = (values?["APIBaseURL"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseURLString = (rawBaseURL?.isEmpty == false ? rawBaseURL : fallbackBaseURL) ?? fallbackBaseURL
        guard let baseURL = URL(string: baseURLString), baseURL.host != nil else {
            return .failure(.invalidBaseURL)
        }

        let season = (values?["CurrentSeason"] as? Int) ?? AppConfig.currentSeason()
        return .success(AppConfig(apiKey: key, baseURL: baseURL, season: season))
    }

    /// European seasons roll over in July: September 2026 belongs to season 2026.
    static func currentSeason(now: Date = Date(), calendar: Calendar = .current) -> Int {
        let components = calendar.dateComponents([.year, .month], from: now)
        let year = components.year ?? 2026
        let month = components.month ?? 1
        return month >= 7 ? year : year - 1
    }

    private static func plistValues(in bundle: Bundle) -> [String: Any]? {
        guard let url = bundle.url(forResource: configurationFileName, withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) else {
            return nil
        }
        return plist as? [String: Any]
    }
}

enum ConfigurationError: Error, Equatable, LocalizedError {
    case missingFile
    case missingKey
    case placeholderKey
    case invalidBaseURL

    var errorDescription: String? {
        switch self {
        case .missingFile: L10n.Setup.missingFile
        case .missingKey: L10n.Setup.missingKey
        case .placeholderKey: L10n.Setup.placeholderKey
        case .invalidBaseURL: L10n.Setup.invalidBaseURL
        }
    }

    var recoverySuggestion: String? { L10n.Setup.instructions }
}

/// Tunables that are not secrets.
enum AppConstants {
    /// Live data (fixtures, lineups, in-match stats) is considered fresh for five minutes.
    static let liveCacheTTL: TimeInterval = 5 * 60
    /// Player profiles, leagues and standings are good for a day.
    static let referenceCacheTTL: TimeInterval = 24 * 60 * 60
    static let requestTimeout: TimeInterval = 20
    /// 429 responses are retried with exponential backoff.
    static let maxRetries = 3
    static let initialBackoff: TimeInterval = 1
    static let memoryCacheCapacity = 32 * 1024 * 1024
    static let diskCacheCapacity = 256 * 1024 * 1024
    static let searchDebounce: Duration = .milliseconds(350)
    static let minimumSearchLength = 4
}
