import Foundation

/// Every user-facing string in the app funnels through here so the UI stays free of
/// hardcoded literals and the whole catalogue is localisation-ready.
enum L10n {

    enum App {
        static let name = String(localized: "LineupLab", comment: "App name")
        static let tabMatches = String(localized: "Matches", comment: "Tab title")
        static let tabBuilder = String(localized: "Lineups", comment: "Tab title")
        static let tabInternational = String(localized: "International", comment: "Tab title")
    }

    enum Common {
        static let cancel = String(localized: "Cancel", comment: "Button")
        static let done = String(localized: "Done", comment: "Button")
        static let save = String(localized: "Save", comment: "Button")
        static let delete = String(localized: "Delete", comment: "Button")
        static let duplicate = String(localized: "Duplicate", comment: "Button")
        static let close = String(localized: "Close", comment: "Button")
        static let retry = String(localized: "Try Again", comment: "Button")
        static let search = String(localized: "Search", comment: "Placeholder")
        static let all = String(localized: "All", comment: "Filter chip meaning no filter")
        static let none = String(localized: "None", comment: "Filter chip meaning no value")
        static let unknown = String(localized: "Unknown", comment: "Fallback value")
        static let noRating = String(localized: "—", comment: "Shown when a player has no rating")
        static let loading = String(localized: "Loading…", comment: "Loading indicator label")
    }

    enum Matches {
        static let title = String(localized: "Matches", comment: "Screen title")
        static let today = String(localized: "Today", comment: "Date strip label")
        static let tomorrow = String(localized: "Tomorrow", comment: "Date strip label")
        static let yesterday = String(localized: "Yesterday", comment: "Date strip label")
        static let live = String(localized: "LIVE", comment: "Match status badge")
        static let emptyTitle = String(localized: "No matches", comment: "Empty state title")
        static let emptyMessage = String(localized: "There are no fixtures for this day and filter.", comment: "Empty state message")
        static let venueUnknown = String(localized: "Venue TBC", comment: "Shown when the venue is missing")

        static func kickoff(_ time: String) -> String {
            String(localized: "Kick-off \(time)", comment: "Kick-off time row label")
        }
    }

    enum MatchDetail {
        static let lineups = String(localized: "Lineups", comment: "Segmented control tab")
        static let stats = String(localized: "Stats", comment: "Segmented control tab")
        static let events = String(localized: "Events", comment: "Segmented control tab")
        static let info = String(localized: "Info", comment: "Segmented control tab")
        static let substitutes = String(localized: "Substitutes", comment: "Section title")
        static let coach = String(localized: "Coach", comment: "Section title")
        static let referee = String(localized: "Referee", comment: "Info row")
        static let venue = String(localized: "Venue", comment: "Info row")
        static let city = String(localized: "City", comment: "Info row")
        static let attendance = String(localized: "Attendance", comment: "Info row")
        static let round = String(localized: "Round", comment: "Info row")
        static let season = String(localized: "Season", comment: "Info row")
        static let status = String(localized: "Status", comment: "Info row")
        static let possession = String(localized: "Possession", comment: "Stat row")
        static let lineupsPending = String(localized: "Lineups will be available ~1 hour before kick-off.", comment: "Empty state for unannounced lineups")
        static let noEvents = String(localized: "No events yet.", comment: "Empty state")
        static let noStats = String(localized: "No statistics available for this match.", comment: "Empty state")
        static let noInfo = String(localized: "No additional information available.", comment: "Empty state")
    }

    enum Player {
        static let detailsTitle = String(localized: "Player", comment: "Sheet title")
        static let position = String(localized: "Position", comment: "Field label")
        static let height = String(localized: "Height", comment: "Field label")
        static let weight = String(localized: "Weight", comment: "Field label")
        static let club = String(localized: "Club", comment: "Field label")
        static let born = String(localized: "Born", comment: "Field label")
        static let latestRating = String(localized: "Latest Rating", comment: "Field label")
        static let seasonStats = String(localized: "Season Stats", comment: "Section title")
        static let appearances = String(localized: "Apps", comment: "Stat label: appearances")
        static let goals = String(localized: "Goals", comment: "Stat label")
        static let assists = String(localized: "Assists", comment: "Stat label")
        static let minutes = String(localized: "Minutes", comment: "Stat label")
        static let averageRating = String(localized: "Avg Rating", comment: "Stat label")
        static let addToLineup = String(localized: "Add to Custom Lineup", comment: "Button")
        static let matchStats = String(localized: "Match Stats", comment: "Section title")

        static func age(_ value: Int) -> String {
            String(localized: "Age: \(value)", comment: "Player age, e.g. Age: 24")
        }
        static func shirtNumber(_ value: Int) -> String {
            String(localized: "Shirt number \(value)", comment: "Accessibility label")
        }
        static func ratingValue(_ value: String) -> String {
            String(localized: "Rating \(value)", comment: "Accessibility label")
        }
    }

    enum Builder {
        static let title = String(localized: "Lineup Builder", comment: "Screen title")
        static let myLineups = String(localized: "My Lineups", comment: "Screen title")
        static let newLineup = String(localized: "New Lineup", comment: "Button")
        static let chooseFormation = String(localized: "Choose Formation", comment: "Step title")
        static let fillPositions = String(localized: "Fill Positions", comment: "Step title")
        static let quickFill = String(localized: "Quick Fill", comment: "Button")
        static let clearAll = String(localized: "Clear All", comment: "Button")
        static let saveLineup = String(localized: "Save Lineup", comment: "Button")
        static let lineupName = String(localized: "Lineup name", comment: "Text field placeholder")
        static let nameYourLineup = String(localized: "Name your lineup", comment: "Alert title")
        static let replacePlayer = String(localized: "Replace Player", comment: "Context menu action")
        static let removePlayer = String(localized: "Remove Player", comment: "Context menu action")
        static let viewDetails = String(localized: "View Player Details", comment: "Context menu action")
        static let emptySlot = String(localized: "Empty slot", comment: "Accessibility label")
        static let pickPlayer = String(localized: "Pick a player", comment: "Sheet title")
        static let noPlayersFound = String(localized: "No players found. Try a different search.", comment: "Empty state")
        static let searchPrompt = String(localized: "Search players by name", comment: "Search field prompt")
        static let searchHint = String(localized: "Search any player from any league — the whole database is available.", comment: "Empty search state")
        static let minRating = String(localized: "Min rating", comment: "Filter label")
        static let nationality = String(localized: "Nationality", comment: "Filter label")
        static let teamAverageRating = String(localized: "Avg Rating", comment: "Summary stat")
        static let totalAge = String(localized: "Total Age", comment: "Summary stat")
        static let averageAge = String(localized: "Avg Age", comment: "Summary stat")
        static let nationalities = String(localized: "Nationalities", comment: "Section title")
        static let shareLineup = String(localized: "Share Lineup", comment: "Button")
        static let noLineupsTitle = String(localized: "No saved lineups", comment: "Empty state title")
        static let noLineupsMessage = String(localized: "Build your dream XI with any player in the database.", comment: "Empty state message")
        static let dragHint = String(localized: "Drag players between slots to swap them.", comment: "Hint text")
        static let editLineup = String(localized: "Edit Lineup", comment: "Button")

        static func slotsFilled(_ filled: Int, _ total: Int) -> String {
            String(localized: "\(filled) of \(total) positions filled", comment: "Progress label")
        }
        static func copyName(_ name: String) -> String {
            String(localized: "\(name) copy", comment: "Name for a duplicated lineup")
        }
        static func nationalityCount(_ count: Int, _ nationality: String) -> String {
            String(localized: "\(count) \(nationality)", comment: "Nationality breakdown, e.g. 5 Brazil")
        }
    }

    enum International {
        static let title = String(localized: "International", comment: "Screen title")
        static let competitions = String(localized: "Competitions", comment: "Section title")
        static let squads = String(localized: "National Team Squads", comment: "Section title")
        static let recentMatches = String(localized: "Recent Matches", comment: "Section title")
        static let selectCountry = String(localized: "Select a country", comment: "Prompt")
        static let noSquad = String(localized: "No squad data available for this team.", comment: "Empty state")
        static let searchCountry = String(localized: "Search countries", comment: "Search prompt")
    }

    enum Errors {
        static let genericTitle = String(localized: "Something went wrong", comment: "Error title")
        static let offlineBanner = String(localized: "Offline — showing cached data", comment: "Banner")
        static let rateLimitBanner = String(localized: "Daily limit reached. Cached data shown.", comment: "Banner")
        static let cachedBanner = String(localized: "Showing cached data", comment: "Banner")
        static let rateLimited = String(localized: "Daily limit reached. Cached data shown.", comment: "Error message")
        static let offline = String(localized: "You're offline. Connect to the internet to load fresh data.", comment: "Error message")
        static let decoding = String(localized: "The server returned data LineupLab could not read.", comment: "Error message")
        static let server = String(localized: "The football data service is unavailable right now.", comment: "Error message")
        static let notFound = String(localized: "That data could not be found.", comment: "Error message")
        static let emptyResponse = String(localized: "No data was returned for this request.", comment: "Error message")
    }

    enum Setup {
        static let title = String(localized: "API key required", comment: "Setup screen title")
        static let invalidKey = String(localized: "Your API key was rejected", comment: "Setup screen title")
        static let instructions = String(localized: """
            LineupLab reads live football data from API-Football.

            1. Create a free account at dashboard.api-football.com/register
            2. Copy your API key.
            3. Copy Config/Configuration.example.plist to LineupLab/Resources/Configuration.plist
            4. Paste the key into the APIFootballKey entry and run again.

            Configuration.plist is gitignored, so your key never leaves your machine.
            """, comment: "Setup instructions shown when the API key is missing or invalid")
        static let missingFile = String(localized: "Configuration.plist was not found in the app bundle.", comment: "Configuration error")
        static let missingKey = String(localized: "Configuration.plist has no APIFootballKey entry.", comment: "Configuration error")
        static let placeholderKey = String(localized: "Configuration.plist still contains the placeholder API key.", comment: "Configuration error")
        static let invalidBaseURL = String(localized: "Configuration.plist contains an invalid APIBaseURL.", comment: "Configuration error")
    }

    enum Formation {
        static let title = String(localized: "Formation", comment: "Section title")

        static func changed(_ name: String) -> String {
            String(localized: "Formation changed to \(name)", comment: "Accessibility announcement")
        }
    }

    enum Positions {
        static let goalkeeper = String(localized: "Goalkeeper", comment: "Player position")
        static let defender = String(localized: "Defender", comment: "Player position")
        static let midfielder = String(localized: "Midfielder", comment: "Player position")
        static let attacker = String(localized: "Attacker", comment: "Player position")
        static let goalkeeperShort = String(localized: "GK", comment: "Short player position")
        static let defenderShort = String(localized: "DEF", comment: "Short player position")
        static let midfielderShort = String(localized: "MID", comment: "Short player position")
        static let attackerShort = String(localized: "ATT", comment: "Short player position")
    }

    enum A11y {
        static let liveMatch = String(localized: "Match in progress", comment: "Accessibility label")
        static let ratingBadge = String(localized: "Match rating", comment: "Accessibility label")
        static let playerPhoto = String(localized: "Player photo", comment: "Accessibility label")
        static let pitch = String(localized: "Formation pitch", comment: "Accessibility label")
    }
}
