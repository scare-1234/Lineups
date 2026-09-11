import Foundation
import Observation

/// International football: competitions, national team squads and recent internationals.
@MainActor
@Observable
final class InternationalViewModel {

    private let service: FootballAPIServicing

    var selectedCompetition: LeagueCatalog.Entry
    var countryQuery: String = ""
    var selectedCountry: String?

    private(set) var fixtures: [Fixture] = []
    private(set) var teams: [Team] = []
    private(set) var squad: [Player] = []
    private(set) var selectedTeam: Team?
    private(set) var isLoadingFixtures = false
    private(set) var isLoadingSquad = false
    private(set) var error: APIError?
    private(set) var banner: DataBanner?
    private(set) var hasLoaded = false

    /// Countries with a national team worth listing in the picker.
    static let countries: [String] = [
        "Argentina", "Australia", "Austria", "Belgium", "Brazil", "Cameroon", "Canada",
        "Chile", "Colombia", "Croatia", "Denmark", "Ecuador", "Egypt", "England",
        "France", "Germany", "Ghana", "Italy", "Ivory Coast", "Japan", "Mexico",
        "Morocco", "Netherlands", "Nigeria", "Norway", "Poland", "Portugal",
        "Saudi Arabia", "Scotland", "Senegal", "Serbia", "South Korea", "Spain",
        "Sweden", "Switzerland", "Turkey", "United States", "Uruguay", "Wales"
    ]

    init(service: FootballAPIServicing, competition: LeagueCatalog.Entry = LeagueCatalog.worldCup) {
        self.service = service
        self.selectedCompetition = competition
    }

    var competitions: [LeagueCatalog.Entry] { LeagueCatalog.internationalCompetitions }

    var filteredCountries: [String] {
        let trimmed = countryQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return Self.countries }
        return Self.countries.filter { $0.localizedCaseInsensitiveContains(trimmed) }
    }

    var squadAverageRating: Double? { RatingScale.average(of: squad.map(\.rating)) }

    func loadIfNeeded() async {
        guard hasLoaded == false else { return }
        await loadFixtures()
        hasLoaded = true
    }

    func select(competition: LeagueCatalog.Entry) async {
        guard competition.id != selectedCompetition.id else { return }
        selectedCompetition = competition
        await loadFixtures()
    }

    func loadFixtures() async {
        isLoadingFixtures = true
        error = nil
        do {
            let response = try await service.recentFixtures(
                leagueID: selectedCompetition.id,
                season: nil,
                last: 20
            )
            fixtures = response.value
            banner = DataBanner(source: response.source)
        } catch {
            fixtures = []
            self.error = APIError.wrap(error)
        }
        isLoadingFixtures = false
    }

    func selectCountry(_ country: String) async {
        selectedCountry = country
        isLoadingSquad = true
        error = nil
        squad = []
        selectedTeam = nil
        do {
            let teamsResponse = try await service.nationalTeams(country: country)
            teams = teamsResponse.value
            guard let team = teamsResponse.value.first else {
                isLoadingSquad = false
                return
            }
            selectedTeam = team
            let squadResponse = try await service.squad(teamID: team.id)
            squad = squadResponse.value.sorted { lhs, rhs in
                let lhsRole = lhs.pitchRole?.depth ?? 4
                let rhsRole = rhs.pitchRole?.depth ?? 4
                if lhsRole != rhsRole { return lhsRole < rhsRole }
                return lhs.name < rhs.name
            }
            banner = DataBanner(source: squadResponse.source)
        } catch {
            self.error = APIError.wrap(error)
        }
        isLoadingSquad = false
    }

    func refresh() async {
        await loadFixtures()
        if let selectedCountry {
            await selectCountry(selectedCountry)
        }
    }
}
