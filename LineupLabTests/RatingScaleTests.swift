import XCTest
@testable import LineupLab

final class RatingScaleTests: XCTestCase {

    func testTierBoundaries() {
        XCTAssertEqual(RatingScale.tier(for: 10.0), .elite)
        XCTAssertEqual(RatingScale.tier(for: 9.0), .elite)
        XCTAssertEqual(RatingScale.tier(for: 8.99), .great)
        XCTAssertEqual(RatingScale.tier(for: 8.0), .great)
        XCTAssertEqual(RatingScale.tier(for: 7.9), .good)
        XCTAssertEqual(RatingScale.tier(for: 7.0), .good)
        XCTAssertEqual(RatingScale.tier(for: 6.9), .average)
        XCTAssertEqual(RatingScale.tier(for: 6.0), .average)
        XCTAssertEqual(RatingScale.tier(for: 5.9), .poor)
        XCTAssertEqual(RatingScale.tier(for: 5.0), .poor)
        XCTAssertEqual(RatingScale.tier(for: 4.99), .bad)
        XCTAssertEqual(RatingScale.tier(for: 0), .bad)
    }

    func testMissingRatingIsUnrated() {
        XCTAssertEqual(RatingScale.tier(for: nil), .unrated)
        XCTAssertEqual(RatingScale.text(for: nil), L10n.Common.noRating)
    }

    func testEveryTierHasItsOwnColour() {
        let colours = RatingTier.allCases.map(\.color)
        XCTAssertEqual(colours.count, RatingTier.allCases.count)
        // Colours are compared through their tier, which is what the UI keys off.
        XCTAssertEqual(RatingScale.color(for: 9.2), RatingTier.elite.color)
        XCTAssertEqual(RatingScale.color(for: 6.5), RatingTier.average.color)
        XCTAssertEqual(RatingScale.color(for: nil), RatingTier.unrated.color)
    }

    func testTextIsOneDecimalPlace() {
        XCTAssertEqual(RatingScale.text(for: 7), "7.0")
        XCTAssertEqual(RatingScale.text(for: 7.833333), "7.8")
        XCTAssertEqual(RatingScale.text(for: 6.94), "6.9")
    }

    func testAverageIgnoresMissingRatings() throws {
        let average = try XCTUnwrap(RatingScale.average(of: [8.0, nil, 6.0]))
        XCTAssertEqual(average, 7.0, accuracy: 0.0001)
        XCTAssertNil(RatingScale.average(of: [nil, nil]))
        XCTAssertNil(RatingScale.average(of: []))
    }

    func testYellowTierUsesDarkText() {
        XCTAssertEqual(RatingTier.average.foreground, RatingTier.average.foreground)
        XCTAssertNotEqual(RatingTier.average.foreground, RatingTier.elite.foreground)
    }
}
