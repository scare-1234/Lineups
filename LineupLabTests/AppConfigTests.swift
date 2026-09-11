import XCTest
@testable import LineupLab

final class AppConfigTests: XCTestCase {

    /// The test bundle has no Configuration.plist, which is exactly the "not set up yet" case.
    private var testBundle: Bundle { Bundle(for: AppConfigTests.self) }

    func testMissingConfigurationIsReported() {
        let result = AppConfig.load(bundle: testBundle, environment: [:])
        switch result {
        case .success:
            XCTFail("Expected a configuration failure")
        case .failure(let error):
            XCTAssertEqual(error, .missingFile)
            XCTAssertNotNil(error.errorDescription)
            XCTAssertNotNil(error.recoverySuggestion)
        }
    }

    func testEnvironmentKeyOverridesTheFile() throws {
        let result = AppConfig.load(bundle: testBundle, environment: [AppConfig.environmentKeyName: "abc123"])
        let config = try XCTUnwrap(try? result.get())
        XCTAssertEqual(config.apiKey, "abc123")
        XCTAssertEqual(config.baseURL.absoluteString, AppConfig.fallbackBaseURL)
        XCTAssertGreaterThan(config.season, 2000)
    }

    func testPlaceholderKeyIsRejected() {
        let result = AppConfig.load(
            bundle: testBundle,
            environment: [AppConfig.environmentKeyName: AppConfig.placeholderKey]
        )
        switch result {
        case .success:
            XCTFail("The placeholder key must not be accepted")
        case .failure(let error):
            XCTAssertEqual(error, .placeholderKey)
        }
    }

    func testBlankEnvironmentKeyFallsBackToMissingFile() {
        let result = AppConfig.load(bundle: testBundle, environment: [AppConfig.environmentKeyName: "   "])
        switch result {
        case .success:
            XCTFail("A blank key is not a key")
        case .failure(let error):
            XCTAssertEqual(error, .missingFile)
        }
    }

    func testSeasonRollsOverInJuly() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))

        let september = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: 11)))
        XCTAssertEqual(AppConfig.currentSeason(now: september, calendar: calendar), 2026)

        let march = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 3, day: 1)))
        XCTAssertEqual(AppConfig.currentSeason(now: march, calendar: calendar), 2025)

        let july = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 1)))
        XCTAssertEqual(AppConfig.currentSeason(now: july, calendar: calendar), 2026)
    }

    func testUnconfiguredServiceAlwaysFailsWithSetupError() async {
        let service = UnconfiguredAPIService(error: .missingFile)
        do {
            _ = try await service.fixtures(on: Date(), leagueID: nil)
            XCTFail("Expected a configuration error")
        } catch let error as APIError {
            XCTAssertEqual(error, .configuration(.missingFile))
            XCTAssertTrue(error.needsSetup)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
