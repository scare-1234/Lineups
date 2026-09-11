import Foundation

struct Team: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    var name: String
    var logo: URL?
    var country: String?
    /// True for national teams, which API-Football flags as `national`.
    var isNational: Bool

    init(id: Int, name: String, logo: URL? = nil, country: String? = nil, isNational: Bool = false) {
        self.id = id
        self.name = name
        self.logo = logo
        self.country = country
        self.isNational = isNational
    }

    var flagEmoji: String? { NationalityFlag.emoji(for: country) }

    var initials: String {
        let words = name.split(separator: " ").prefix(3)
        return words.compactMap { $0.first }.map(String.init).joined().uppercased()
    }
}
