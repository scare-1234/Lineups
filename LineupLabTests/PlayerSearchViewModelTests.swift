import XCTest
@testable import LineupLab

@MainActor
final class PlayerSearchViewModelTests: XCTestCase {

    func testSearchReturnsMatchesAndRemembersThem() async {
        let viewModel = PlayerSearchViewModel(service: PreviewFootballAPIService())
        await viewModel.search("Moreno")

        XCTAssertEqual(viewModel.results.count, 1)
        XCTAssertEqual(viewModel.results.first?.name, "Rafael Moreno")
        XCTAssertTrue(viewModel.hasSearched)
        XCTAssertEqual(viewModel.pool.count, 1, "Search results feed the Quick Fill pool")
        XCTAssertNil(viewModel.error)
    }

    func testResultsAreSortedByRating() async {
        let viewModel = PlayerSearchViewModel(service: PreviewFootballAPIService(), seed: MockData.searchResults)
        XCTAssertEqual(viewModel.filteredResults.first?.name, "Ken Ito")
        XCTAssertEqual(viewModel.filteredResults.last?.rating, nil)
    }

    func testRoleFilter() {
        let viewModel = PlayerSearchViewModel(service: PreviewFootballAPIService(), seed: MockData.searchResults)
        viewModel.roleFilter = .goalkeeper
        XCTAssertEqual(viewModel.filteredResults.count, 1)
        XCTAssertEqual(viewModel.filteredResults.first?.pitchRole, .goalkeeper)
    }

    func testNationalityAndRatingFilters() {
        let viewModel = PlayerSearchViewModel(service: PreviewFootballAPIService(), seed: MockData.searchResults)
        viewModel.nationalityFilter = "Brazil"
        XCTAssertEqual(viewModel.filteredResults.count, 1)

        viewModel.nationalityFilter = nil
        viewModel.minimumRating = 7.5
        XCTAssertTrue(viewModel.filteredResults.allSatisfy { ($0.rating ?? 0) >= 7.5 })

        viewModel.clearFilters()
        XCTAssertEqual(viewModel.filteredResults.count, MockData.searchResults.count)
        XCTAssertTrue(viewModel.availableNationalities.contains("Japan"))
    }

    func testShortQueriesAreNotSentToTheAPI() async {
        let viewModel = PlayerSearchViewModel(service: PreviewFootballAPIService(), seed: MockData.searchResults)
        viewModel.query = "ab"
        viewModel.queryChanged()
        XCTAssertTrue(viewModel.isQueryTooShort)
        await viewModel.searchNow()
        XCTAssertFalse(viewModel.hasSearched)
    }

    func testQuickFillCandidatesPreferTheRequestedRole() {
        let viewModel = PlayerSearchViewModel(service: PreviewFootballAPIService(), seed: MockData.searchResults)
        let candidates = viewModel.quickFillCandidates(excluding: [], role: .goalkeeper)
        XCTAssertEqual(candidates.first?.pitchRole, .goalkeeper)

        let excluded = Set(MockData.searchResults.compactMap { $0.pitchRole == .goalkeeper ? $0.id : nil })
        let withoutKeepers = viewModel.quickFillCandidates(excluding: excluded, role: .goalkeeper)
        XCTAssertFalse(withoutKeepers.contains { $0.pitchRole == .goalkeeper })
    }

    func testErrorsAreSurfaced() async {
        let viewModel = PlayerSearchViewModel(service: PreviewFootballAPIService(behaviour: .failure(.offline)))
        await viewModel.search("Moreno")
        XCTAssertEqual(viewModel.error, .offline)
        XCTAssertTrue(viewModel.results.isEmpty)
    }

    func testInternationalSquadLoading() async {
        let viewModel = InternationalViewModel(service: PreviewFootballAPIService())
        await viewModel.loadFixtures()
        XCTAssertEqual(viewModel.fixtures.count, MockData.fixtures.count)

        await viewModel.selectCountry("Brazil")
        XCTAssertEqual(viewModel.selectedTeam?.name, "Brazil")
        XCTAssertFalse(viewModel.squad.isEmpty)
        // Squads are listed keepers first.
        XCTAssertEqual(viewModel.squad.first?.pitchRole, .goalkeeper)
        XCTAssertNotNil(viewModel.squadAverageRating)
    }

    func testCountryFilter() {
        let viewModel = InternationalViewModel(service: PreviewFootballAPIService())
        viewModel.countryQuery = "bra"
        XCTAssertEqual(viewModel.filteredCountries, ["Brazil"])
        viewModel.countryQuery = ""
        XCTAssertEqual(viewModel.filteredCountries.count, InternationalViewModel.countries.count)
    }
}
