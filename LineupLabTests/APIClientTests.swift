import XCTest
@testable import LineupLab

final class APIClientTests: XCTestCase {

    private var cacheDirectoryName = ""

    override func setUp() async throws {
        try await super.setUp()
        StubURLProtocol.reset()
        cacheDirectoryName = "tests-\(UUID().uuidString)"
    }

    override func tearDown() async throws {
        await makeCache().removeAll()
        StubURLProtocol.reset()
        try await super.tearDown()
    }

    private func makeCache() -> CacheManager {
        CacheManager(directoryName: cacheDirectoryName)
    }

    private func makeClient(cache: CacheManager? = nil, maxRetries: Int = 2) -> APIClient {
        let config = AppConfig(
            apiKey: "test-key",
            baseURL: URL(string: "https://v3.football.api-sports.io") ?? URL(fileURLWithPath: "/"),
            season: 2026
        )
        return APIClient(
            config: config,
            session: StubURLProtocol.makeSession(),
            cache: cache ?? makeCache(),
            maxRetries: maxRetries,
            initialBackoff: 0,
            sleeper: { _ in }
        )
    }

    private var fixturesEndpoint: Endpoint {
        Endpoint(path: "fixtures", queryItems: [URLQueryItem(name: "date", value: "2026-09-11")], freshness: .live)
    }

    func testSuccessfulRequestDecodesAndReportsNetworkSource() async throws {
        StubURLProtocol.enqueue(.init(data: SampleJSON.data(SampleJSON.fixtures)))
        let client = makeClient()

        let response: APIResponse<APIEnvelope<FixtureItemDTO>> = try await client.fetch(fixturesEndpoint)

        XCTAssertEqual(response.value.response.count, 2)
        XCTAssertEqual(response.source, .network)
        XCTAssertEqual(StubURLProtocol.requestCount, 1)
    }

    func testUnauthorizedStatusMapsToInvalidKey() async {
        StubURLProtocol.enqueue(.init(statusCode: 401))
        let client = makeClient()

        do {
            let _: APIResponse<APIEnvelope<FixtureItemDTO>> = try await client.fetch(fixturesEndpoint)
            XCTFail("Expected an invalid key error")
        } catch let error as APIError {
            XCTAssertEqual(error, .invalidKey)
            XCTAssertTrue(error.needsSetup)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testTokenErrorPayloadMapsToInvalidKey() async {
        StubURLProtocol.enqueue(.init(data: SampleJSON.data(SampleJSON.tokenError)))
        let client = makeClient()

        do {
            let _: APIResponse<APIEnvelope<FixtureItemDTO>> = try await client.fetch(fixturesEndpoint)
            XCTFail("Expected an invalid key error")
        } catch let error as APIError {
            XCTAssertEqual(error, .invalidKey)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testQuotaErrorPayloadMapsToRateLimited() async {
        StubURLProtocol.enqueue(.init(data: SampleJSON.data(SampleJSON.rateLimitError)))
        let client = makeClient()

        do {
            let _: APIResponse<APIEnvelope<FixtureItemDTO>> = try await client.fetch(fixturesEndpoint)
            XCTFail("Expected a rate limit error")
        } catch let error as APIError {
            XCTAssertEqual(error, .rateLimited)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testRateLimitIsRetriedThenServesCachedData() async throws {
        let cache = makeCache()
        let client = makeClient(cache: cache, maxRetries: 2)

        // Warm the cache with a good response.
        StubURLProtocol.enqueue(.init(data: SampleJSON.data(SampleJSON.fixtures)))
        let first: APIResponse<APIEnvelope<FixtureItemDTO>> = try await client.fetch(fixturesEndpoint)
        XCTAssertEqual(first.source, .network)

        // Every later attempt is rejected, and the cached copy is served instead.
        StubURLProtocol.reset()
        StubURLProtocol.enqueue(.init(statusCode: 429), times: 6)

        let endpoint = Endpoint(
            path: "fixtures",
            queryItems: [URLQueryItem(name: "date", value: "2026-09-11")],
            freshness: .always
        )
        let second: APIResponse<APIEnvelope<FixtureItemDTO>> = try await client.fetch(endpoint)

        XCTAssertEqual(second.value.response.count, 2)
        switch second.source {
        case .cache(_, let reason):
            XCTAssertEqual(reason, .rateLimited)
        case .network:
            XCTFail("Expected cached data")
        }
        // One initial attempt plus two retries.
        XCTAssertEqual(StubURLProtocol.requestCount, 3)
    }

    func testRateLimitWithoutCacheThrows() async {
        StubURLProtocol.enqueue(.init(statusCode: 429), times: 6)
        let client = makeClient(maxRetries: 1)

        do {
            let _: APIResponse<APIEnvelope<FixtureItemDTO>> = try await client.fetch(fixturesEndpoint)
            XCTFail("Expected a rate limit error")
        } catch let error as APIError {
            XCTAssertEqual(error, .rateLimited)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testOfflineServesCachedDataWhenAvailable() async throws {
        let cache = makeCache()
        let client = makeClient(cache: cache)

        StubURLProtocol.enqueue(.init(data: SampleJSON.data(SampleJSON.fixtures)))
        let _: APIResponse<APIEnvelope<FixtureItemDTO>> = try await client.fetch(fixturesEndpoint)

        StubURLProtocol.reset()
        StubURLProtocol.enqueue(.init(error: URLError(.notConnectedToInternet)), times: 4)

        let endpoint = Endpoint(
            path: "fixtures",
            queryItems: [URLQueryItem(name: "date", value: "2026-09-11")],
            freshness: .always
        )
        let response: APIResponse<APIEnvelope<FixtureItemDTO>> = try await client.fetch(endpoint)

        switch response.source {
        case .cache(_, let reason):
            XCTAssertEqual(reason, .offline)
        case .network:
            XCTFail("Expected cached data")
        }
    }

    func testOfflineWithoutCacheThrowsOffline() async {
        StubURLProtocol.enqueue(.init(error: URLError(.notConnectedToInternet)), times: 4)
        let client = makeClient()

        do {
            let _: APIResponse<APIEnvelope<FixtureItemDTO>> = try await client.fetch(fixturesEndpoint)
            XCTFail("Expected an offline error")
        } catch let error as APIError {
            XCTAssertEqual(error, .offline)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testFreshCacheSkipsTheNetworkEntirely() async throws {
        let cache = makeCache()
        let client = makeClient(cache: cache)
        let endpoint = Endpoint(
            path: "players",
            queryItems: [URLQueryItem(name: "id", value: "276")],
            freshness: .reference
        )

        StubURLProtocol.enqueue(.init(data: SampleJSON.data(SampleJSON.playerProfile)))
        let first: APIResponse<APIEnvelope<PlayerProfileItemDTO>> = try await client.fetch(endpoint)
        XCTAssertEqual(first.source, .network)
        XCTAssertEqual(StubURLProtocol.requestCount, 1)

        let second: APIResponse<APIEnvelope<PlayerProfileItemDTO>> = try await client.fetch(endpoint)
        XCTAssertTrue(second.source.isCache)
        XCTAssertEqual(StubURLProtocol.requestCount, 1, "A fresh cache must not spend a request")
    }

    func testNotFoundMapsToNotFound() async {
        StubURLProtocol.enqueue(.init(statusCode: 404))
        let client = makeClient()

        do {
            let _: APIResponse<APIEnvelope<FixtureItemDTO>> = try await client.fetch(fixturesEndpoint)
            XCTFail("Expected a not found error")
        } catch let error as APIError {
            XCTAssertEqual(error, .notFound)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testServiceLayerMapsFixturesAndPlayers() async throws {
        StubURLProtocol.enqueue(.init(data: SampleJSON.data(SampleJSON.fixtures)))
        let service = FootballAPIService(client: makeClient(), defaultSeason: 2026)

        let fixtures = try await service.fixtures(on: MockData.referenceDate, leagueID: nil)
        XCTAssertEqual(fixtures.value.count, 2)
        // Sorted by kick-off time.
        XCTAssertLessThanOrEqual(fixtures.value[0].date, fixtures.value[1].date)

        StubURLProtocol.reset()
        StubURLProtocol.enqueue(.init(data: SampleJSON.data(SampleJSON.playerProfile)))
        let player = try await service.player(id: 276, season: 2026)
        XCTAssertEqual(player.value.age, 24)
        XCTAssertEqual(player.value.nationality, "Brazil")
    }

    func testCacheKeyHashingIsStableAndFileSystemSafe() {
        let name = CacheManager.fileName(forKey: "https://v3.football.api-sports.io/fixtures?date=2026-09-11")
        XCTAssertEqual(name, CacheManager.fileName(forKey: "https://v3.football.api-sports.io/fixtures?date=2026-09-11"))
        XCTAssertNotEqual(name, CacheManager.fileName(forKey: "https://v3.football.api-sports.io/fixtures?date=2026-09-12"))
        XCTAssertFalse(name.contains("/"))
        XCTAssertTrue(name.hasSuffix(".json"))
    }
}
