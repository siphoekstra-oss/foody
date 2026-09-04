import Foundation
import Testing
@testable import Foody

/// Sommige systemen (Guestplan) geven per dag alleen "vrij voor lunch/diner" zonder tijden.
struct DayLevelAvailabilityTests {
    let sept12 = Fixtures.day("2026-09-12")

    @Test func decodesServicesAvailableAndDefaultsToEmpty() throws {
        let json = AvailabilityDecodingTests.fullDocument.replacingOccurrences(
            of: "\"date\": \"2026-09-12\",",
            with: "\"date\": \"2026-09-12\", \"services_available\": [\"dinner\"],")
        let doc = try AvailabilityDecoder.decode(Data(json.utf8))
        #expect(doc.restaurants[0].availability[0].servicesAvailable == [.dinner])

        let plain = try AvailabilityDecoder.decode(Data(AvailabilityDecodingTests.fullDocument.utf8))
        #expect(plain.restaurants[0].availability[0].servicesAvailable.isEmpty)
    }

    @Test func dayLevelAvailabilityMatchesServiceAndDay() {
        let r = Fixtures.restaurant(availability: [
            DayAvailability(date: sept12, slots: [], servicesAvailable: [.dinner]),
        ])
        #expect(AvailabilityQuery.hasDayLevelAvailability(for: r, matching: SearchQuery(day: sept12, service: .dinner, covers: 2)))
        #expect(!AvailabilityQuery.hasDayLevelAvailability(for: r, matching: SearchQuery(day: sept12, service: .lunch, covers: 2)))
        #expect(!AvailabilityQuery.hasDayLevelAvailability(for: r, matching: SearchQuery(day: Fixtures.day("2026-09-13"), service: .dinner, covers: 2)))
    }

    @Test func nextAvailableDayCountsDayLevelAvailability() {
        let r = Fixtures.restaurant(availability: [
            DayAvailability(date: Fixtures.day("2026-09-15"), slots: [], servicesAvailable: [.lunch]),
            DayAvailability(date: Fixtures.day("2026-09-18"), slots: [], servicesAvailable: [.dinner]),
        ])
        let query = SearchQuery(day: sept12, service: .dinner, covers: 2)
        #expect(AvailabilityQuery.nextAvailableDay(for: r, after: query) == Fixtures.day("2026-09-18"))
    }

    @Test func resultsCarryDayLevelFlagAndRankAboveNothing() throws {
        let withSlots = Fixtures.restaurant(id: "slots", availability: [
            DayAvailability(date: sept12, slots: Fixtures.slots([("19:00", .dinner, 2)])),
        ])
        let dayLevel = Fixtures.restaurant(id: "daglevel", availability: [
            DayAvailability(date: sept12, slots: [], servicesAvailable: [.dinner]),
        ])
        let nothing = Fixtures.restaurant(id: "niets")
        let results = ResultRanking.results(from: [nothing, dayLevel, withSlots],
                                            query: SearchQuery(day: sept12, service: .dinner, covers: 2),
                                            userLocation: nil, sort: .availability)
        #expect(results.map(\.id) == ["slots", "daglevel", "niets"])
        #expect(try #require(results.first { $0.id == "daglevel" }).hasDayLevelAvailability)
        #expect(!(try #require(results.first { $0.id == "slots" }).hasDayLevelAvailability))
    }
}
