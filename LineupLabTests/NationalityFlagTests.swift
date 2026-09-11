import XCTest
@testable import LineupLab

final class NationalityFlagTests: XCTestCase {

    func testCommonFootballNations() {
        XCTAssertEqual(NationalityFlag.emoji(for: "Brazil"), "🇧🇷")
        XCTAssertEqual(NationalityFlag.emoji(for: "France"), "🇫🇷")
        XCTAssertEqual(NationalityFlag.emoji(for: "Japan"), "🇯🇵")
        XCTAssertEqual(NationalityFlag.emoji(for: "Nigeria"), "🇳🇬")
        XCTAssertEqual(NationalityFlag.emoji(for: "Argentina"), "🇦🇷")
    }

    func testAliasesAndCaseAndDiacritics() {
        XCTAssertEqual(NationalityFlag.emoji(for: "brazil"), "🇧🇷")
        XCTAssertEqual(NationalityFlag.emoji(for: "  Brazil  "), "🇧🇷")
        XCTAssertEqual(NationalityFlag.emoji(for: "USA"), NationalityFlag.emoji(for: "United States"))
        XCTAssertEqual(NationalityFlag.emoji(for: "Czechia"), NationalityFlag.emoji(for: "Czech Republic"))
        XCTAssertEqual(NationalityFlag.emoji(for: "Côte d'Ivoire"), NationalityFlag.emoji(for: "Ivory Coast"))
        XCTAssertEqual(NationalityFlag.emoji(for: "Korea Republic"), NationalityFlag.emoji(for: "South Korea"))
    }

    func testHomeNationsUseSubdivisionFlags() {
        let england = NationalityFlag.emoji(for: "England")
        XCTAssertNotNil(england)
        XCTAssertEqual(england, NationalityFlag.subdivisionFlag("gbeng"))
        XCTAssertNotEqual(england, NationalityFlag.emoji(for: "United Kingdom"))
        XCTAssertNotNil(NationalityFlag.emoji(for: "Scotland"))
        XCTAssertNotNil(NationalityFlag.emoji(for: "Wales"))
    }

    func testUnknownCountriesReturnNilSoTheUICanShowText() {
        XCTAssertNil(NationalityFlag.emoji(for: "Atlantis"))
        XCTAssertNil(NationalityFlag.emoji(for: ""))
        XCTAssertNil(NationalityFlag.emoji(for: nil))
    }

    func testLabelFallsBackToThePlainCountryName() {
        XCTAssertEqual(NationalityFlag.label(for: "Brazil"), "🇧🇷 Brazil")
        XCTAssertEqual(NationalityFlag.label(for: "Atlantis"), "Atlantis")
        XCTAssertEqual(NationalityFlag.label(for: nil), L10n.Common.unknown)
        XCTAssertEqual(NationalityFlag.label(for: "   "), L10n.Common.unknown)
    }

    func testRegionalIndicatorConstruction() {
        XCTAssertEqual(NationalityFlag.regionalIndicator(for: "br"), "🇧🇷")
        XCTAssertEqual(NationalityFlag.regionalIndicator(for: "BR"), "🇧🇷")
        XCTAssertNil(NationalityFlag.regionalIndicator(for: "BRA"))
        XCTAssertNil(NationalityFlag.regionalIndicator(for: "1"))
    }

    func testEveryMappedCountryProducesAFlag() {
        for country in InternationalViewModel.countries {
            XCTAssertNotNil(NationalityFlag.emoji(for: country), "\(country) should map to a flag")
        }
    }
}
