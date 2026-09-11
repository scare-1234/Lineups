import Foundation

extension DateFormatter {
    /// "yyyy-MM-dd" — the format API-Football expects for the `date` query parameter.
    static let apiDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    /// Weekday + day number for the date strip, e.g. "Mon 11".
    static let dayStrip: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEE d")
        return formatter
    }()

    static let monthDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMM d")
        return formatter
    }()

    static let kickoffTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()

    static let fullDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    static let birthDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter
    }()
}

extension ISO8601DateFormatter {
    static let withFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let standard: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

enum APIDateParsing {
    /// API-Football returns "2026-09-11T14:00:00+00:00"; some endpoints add fractional seconds.
    static func date(fromISO8601 string: String) -> Date? {
        if let date = ISO8601DateFormatter.standard.date(from: string) { return date }
        if let date = ISO8601DateFormatter.withFractionalSeconds.date(from: string) { return date }
        return DateFormatter.apiDay.date(from: string)
    }

    /// Player birth dates arrive as "1992-02-05".
    static func birthDate(from string: String?) -> Date? {
        guard let string, string.isEmpty == false else { return nil }
        return DateFormatter.apiDay.date(from: string)
    }
}

extension Date {
    var apiDayString: String { DateFormatter.apiDay.string(from: self) }

    var kickoffString: String { DateFormatter.kickoffTime.string(from: self) }

    var fullDateTimeString: String { DateFormatter.fullDateTime.string(from: self) }

    /// "Today" / "Tomorrow" / "Yesterday", otherwise "Mon 11".
    func dayStripLabel(calendar: Calendar = .current, relativeTo reference: Date = Date()) -> String {
        if calendar.isDate(self, inSameDayAs: reference) { return L10n.Matches.today }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: reference),
           calendar.isDate(self, inSameDayAs: tomorrow) {
            return L10n.Matches.tomorrow
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: reference),
           calendar.isDate(self, inSameDayAs: yesterday) {
            return L10n.Matches.yesterday
        }
        return DateFormatter.dayStrip.string(from: self)
    }

    func startOfDay(calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: self)
    }

    /// The date strip: seven days back, today, seven days forward.
    static func matchDayStrip(around reference: Date = Date(), calendar: Calendar = .current) -> [Date] {
        let today = calendar.startOfDay(for: reference)
        return (-7...7).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
    }
}
