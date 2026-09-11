import Foundation

/// Non-blocking message shown above content when data did not come straight from the network.
enum DataBanner: Equatable, Sendable {
    case offline(storedAt: Date)
    case rateLimited(storedAt: Date)
    case cached(storedAt: Date)

    init?(source: DataSource) {
        switch source {
        case .network:
            return nil
        case .cache(let storedAt, let reason):
            switch reason {
            case .fresh: return nil
            case .offline: self = .offline(storedAt: storedAt)
            case .rateLimited: self = .rateLimited(storedAt: storedAt)
            case .serverError: self = .cached(storedAt: storedAt)
            }
        }
    }

    var message: String {
        switch self {
        case .offline: L10n.Errors.offlineBanner
        case .rateLimited: L10n.Errors.rateLimitBanner
        case .cached: L10n.Errors.cachedBanner
        }
    }

    var systemImage: String {
        switch self {
        case .offline: "wifi.slash"
        case .rateLimited: "hourglass"
        case .cached: "externaldrive.badge.checkmark"
        }
    }

    var storedAt: Date {
        switch self {
        case .offline(let date), .rateLimited(let date), .cached(let date): date
        }
    }
}

/// Maps any thrown error onto an `APIError` so the UI only ever handles one type.
extension APIError {
    static func wrap(_ error: Error) -> APIError {
        if let apiError = error as? APIError { return apiError }
        if let urlError = error as? URLError, APIClient.isConnectivityError(urlError) { return .offline }
        if error is CancellationError { return .server(status: 0) }
        return .server(status: 0)
    }
}
