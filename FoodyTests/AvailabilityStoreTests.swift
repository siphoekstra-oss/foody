import Foundation
import Testing
@testable import Foody

struct StubLoader: AvailabilityLoading {
    struct Failure: Error {}
    var data: Data?

    func load() async throws -> LoadedAvailability {
        guard let data else { throw Failure() }
        return LoadedAvailability(data: data, origin: .bundle, refreshError: nil)
    }
}

@MainActor
struct AvailabilityStoreTests {
    let sept12 = Fixtures.day("2026-09-12")
    var query: SearchQuery { SearchQuery(day: sept12, service: .dinner, covers: 2) }
    var fixtureData: Data { Data(AvailabilityDecodingTests.fullDocument.utf8) }

    @Test func loadPublishesDocumentAndResults() async {
        let store = AvailabilityStore(loader: StubLoader(data: fixtureData), query: query)

        await store.load()

        #expect(store.document?.restaurants.count == 1)
        #expect(store.loadError == nil)
        #expect(store.results.map(\.id) == ["tante-pietje"])
        #expect(store.results.first?.slots.map(\.time) == ["19:30"])
    }

    @Test func loaderFailurePublishesReadableError() async {
        let store = AvailabilityStore(loader: StubLoader(data: nil), query: query)

        await store.load()

        #expect(store.document == nil)
        #expect(store.loadError?.isEmpty == false)
        #expect(store.results.isEmpty)
    }

    @Test func unreadableDataPublishesReadableError() async {
        let store = AvailabilityStore(loader: StubLoader(data: Data("nonsens".utf8)), query: query)

        await store.load()

        #expect(store.document == nil)
        #expect(store.loadError?.isEmpty == false)
    }

    @Test func newerSchemaGivesTheSchemaMessage() async {
        let newer = AvailabilityDecodingTests.fullDocument.replacingOccurrences(of: "\"schema_version\": 1", with: "\"schema_version\": 7")
        let store = AvailabilityStore(loader: StubLoader(data: Data(newer.utf8)), query: query)

        await store.load()

        #expect(store.loadError?.contains("dataformaat 7") == true)
    }

    @Test func changingTheQueryRecomputesResults() async {
        let store = AvailabilityStore(loader: StubLoader(data: fixtureData), query: query)
        await store.load()

        store.query.covers = 8

        #expect(store.results.first?.slots.isEmpty == true)
        #expect(store.results.first?.nextAvailableDay == nil)
    }

    @Test func documentOlderThanAnHourIsStale() async throws {
        let store = AvailabilityStore(loader: StubLoader(data: fixtureData), query: query)
        await store.load()
        let generated = try #require(store.document?.generatedAt)

        #expect(store.isStale(now: generated.addingTimeInterval(2 * 3600)))
        #expect(!store.isStale(now: generated.addingTimeInterval(10 * 60)))
    }

    @Test func storeExposesOriginAndRefreshError() async {
        struct CacheLoader: AvailabilityLoading {
            let data: Data
            func load() async throws -> LoadedAvailability { LoadedAvailability(data: data, origin: .cache, refreshError: "Geen verbinding") }
        }
        let store = AvailabilityStore(loader: CacheLoader(data: fixtureData), query: query)
        await store.load()
        #expect(store.origin == .cache)
        #expect(store.refreshError == "Geen verbinding")
        #expect(store.document != nil)
    }

    @Test func looksUpRestaurantById() async {
        let store = AvailabilityStore(loader: StubLoader(data: fixtureData), query: query)
        await store.load()
        #expect(store.restaurant(id: "tante-pietje")?.name == "Bistro Tante Pietje")
        #expect(store.restaurant(id: "bestaat-niet") == nil)
    }
}
