import Foundation

/// Converts an API-Football nationality string ("Brazil", "England", …) into a flag emoji.
///
/// Countries that are not in the map return `nil` so the UI can fall back to plain text,
/// which is exactly what Section 7 of the spec asks for.
enum NationalityFlag {

    static func emoji(for nationality: String?) -> String? {
        guard let nationality else { return nil }
        let key = normalise(nationality)
        guard key.isEmpty == false else { return nil }

        if let subdivision = subdivisionCodes[key] {
            return subdivisionFlag(subdivision)
        }
        guard let code = regionCodes[key] else { return nil }
        return regionalIndicator(for: code)
    }

    /// Flag + name, or just the name when no flag exists for that country.
    static func label(for nationality: String?) -> String {
        let name = nationality?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard name.isEmpty == false else { return L10n.Common.unknown }
        guard let flag = emoji(for: name) else { return name }
        return "\(flag) \(name)"
    }

    // MARK: - Emoji construction

    /// Builds a 🇧🇷-style flag from an ISO 3166-1 alpha-2 code.
    static func regionalIndicator(for code: String) -> String? {
        let base: UInt32 = 0x1F1E6
        var scalars = String.UnicodeScalarView()
        let letters = code.uppercased().unicodeScalars
        guard letters.count == 2 else { return nil }
        for letter in letters {
            guard letter.value >= 65, letter.value <= 90,
                  let scalar = Unicode.Scalar(base + letter.value - 65) else { return nil }
            scalars.append(scalar)
        }
        return String(scalars)
    }

    /// Builds a 🏴󠁧󠁢󠁥󠁮󠁧󠁿-style flag (England, Scotland, Wales) from an ISO 3166-2 subdivision code.
    static func subdivisionFlag(_ code: String) -> String? {
        guard let waving = Unicode.Scalar(0x1F3F4), let terminator = Unicode.Scalar(0xE007F) else { return nil }
        var scalars = String.UnicodeScalarView()
        scalars.append(waving)
        for character in code.lowercased().unicodeScalars {
            guard let tag = Unicode.Scalar(0xE0000 + character.value) else { return nil }
            scalars.append(tag)
        }
        scalars.append(terminator)
        return String(scalars)
    }

    private static func normalise(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    }

    // MARK: - Maps

    private static let subdivisionCodes: [String: String] = [
        "england": "gbeng",
        "scotland": "gbsct",
        "wales": "gbwls"
    ]

    /// Football nations as API-Football spells them, plus the common aliases it also returns.
    private static let regionCodes: [String: String] = [
        "afghanistan": "AF", "albania": "AL", "algeria": "DZ", "andorra": "AD", "angola": "AO",
        "antigua and barbuda": "AG", "argentina": "AR", "armenia": "AM", "aruba": "AW",
        "australia": "AU", "austria": "AT", "azerbaijan": "AZ", "bahamas": "BS", "bahrain": "BH",
        "bangladesh": "BD", "barbados": "BB", "belarus": "BY", "belgium": "BE", "belize": "BZ",
        "benin": "BJ", "bermuda": "BM", "bhutan": "BT", "bolivia": "BO",
        "bosnia": "BA", "bosnia and herzegovina": "BA", "botswana": "BW", "brazil": "BR",
        "bulgaria": "BG", "burkina faso": "BF", "burundi": "BI", "cambodia": "KH",
        "cameroon": "CM", "canada": "CA", "cape verde": "CV", "cape verde islands": "CV",
        "central african republic": "CF", "chad": "TD", "chile": "CL", "china": "CN",
        "china pr": "CN", "colombia": "CO", "comoros": "KM", "congo": "CG",
        "congo dr": "CD", "democratic republic of congo": "CD", "costa rica": "CR",
        "croatia": "HR", "cuba": "CU", "curacao": "CW", "cyprus": "CY",
        "czech republic": "CZ", "czechia": "CZ", "denmark": "DK", "djibouti": "DJ",
        "dominica": "DM", "dominican republic": "DO", "ecuador": "EC", "egypt": "EG",
        "el salvador": "SV", "equatorial guinea": "GQ", "eritrea": "ER", "estonia": "EE",
        "eswatini": "SZ", "ethiopia": "ET", "faroe islands": "FO", "fiji": "FJ",
        "finland": "FI", "france": "FR", "gabon": "GA", "gambia": "GM", "georgia": "GE",
        "germany": "DE", "ghana": "GH", "gibraltar": "GI", "greece": "GR", "grenada": "GD",
        "guadeloupe": "GP", "guatemala": "GT", "guinea": "GN", "guinea-bissau": "GW",
        "guyana": "GY", "haiti": "HT", "honduras": "HN", "hong kong": "HK", "hungary": "HU",
        "iceland": "IS", "india": "IN", "indonesia": "ID", "iran": "IR", "iraq": "IQ",
        "ireland": "IE", "republic of ireland": "IE", "israel": "IL", "italy": "IT",
        "ivory coast": "CI", "cote d'ivoire": "CI", "jamaica": "JM", "japan": "JP",
        "jordan": "JO", "kazakhstan": "KZ", "kenya": "KE", "kosovo": "XK", "kuwait": "KW",
        "kyrgyzstan": "KG", "laos": "LA", "latvia": "LV", "lebanon": "LB", "lesotho": "LS",
        "liberia": "LR", "libya": "LY", "liechtenstein": "LI", "lithuania": "LT",
        "luxembourg": "LU", "madagascar": "MG", "malawi": "MW", "malaysia": "MY",
        "maldives": "MV", "mali": "ML", "malta": "MT", "martinique": "MQ",
        "mauritania": "MR", "mauritius": "MU", "mexico": "MX", "moldova": "MD",
        "monaco": "MC", "mongolia": "MN", "montenegro": "ME", "montserrat": "MS",
        "morocco": "MA", "mozambique": "MZ", "myanmar": "MM", "namibia": "NA",
        "nepal": "NP", "netherlands": "NL", "new caledonia": "NC", "new zealand": "NZ",
        "nicaragua": "NI", "niger": "NE", "nigeria": "NG", "north korea": "KP",
        "north macedonia": "MK", "macedonia": "MK", "northern ireland": "GB",
        "norway": "NO", "oman": "OM", "pakistan": "PK", "palestine": "PS", "panama": "PA",
        "papua new guinea": "PG", "paraguay": "PY", "peru": "PE", "philippines": "PH",
        "poland": "PL", "portugal": "PT", "puerto rico": "PR", "qatar": "QA",
        "reunion": "RE", "romania": "RO", "russia": "RU", "rwanda": "RW",
        "saint kitts and nevis": "KN", "saint lucia": "LC",
        "saint vincent and the grenadines": "VC", "samoa": "WS", "san marino": "SM",
        "saudi arabia": "SA", "senegal": "SN", "serbia": "RS", "sierra leone": "SL",
        "singapore": "SG", "slovakia": "SK", "slovenia": "SI", "somalia": "SO",
        "south africa": "ZA", "south korea": "KR", "korea republic": "KR",
        "south sudan": "SS", "spain": "ES", "sri lanka": "LK", "sudan": "SD",
        "suriname": "SR", "sweden": "SE", "switzerland": "CH", "syria": "SY",
        "tahiti": "PF", "taiwan": "TW", "tajikistan": "TJ", "tanzania": "TZ",
        "thailand": "TH", "togo": "TG", "trinidad and tobago": "TT", "tunisia": "TN",
        "turkey": "TR", "turkiye": "TR", "turkmenistan": "TM", "uganda": "UG",
        "ukraine": "UA", "united arab emirates": "AE", "united kingdom": "GB",
        "united states": "US", "usa": "US", "uruguay": "UY", "uzbekistan": "UZ",
        "venezuela": "VE", "vietnam": "VN", "yemen": "YE", "zambia": "ZM", "zimbabwe": "ZW"
    ]
}
