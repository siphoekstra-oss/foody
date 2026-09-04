import Foundation
import Testing
@testable import Foody

struct ResultRankingTests {
    let day = Fixtures.day("2026-09-12")
    let markt = Coordinate(lat: 51.6886843, lon: 5.3036562)
    var query: SearchQuery { SearchQuery(day: day, service: .dinner, covers: 2) }

    /// Dichtbij met één slot, verder weg met twee slots, en een link_only zaak zonder slots.
    var restaurants: [Restaurant] {
        [
            Fixtures.restaurant(id: "verweg", lat: 51.6561549, lon: 5.2724359, availability: [
                DayAvailability(date: day, slots: Fixtures.slots([("18:00", .dinner, 4), ("20:30", .dinner, 4)])),
            ]),
            Fixtures.restaurant(id: "dichtbij", lat: 51.6873245, lon: 5.3059731, availability: [
                DayAvailability(date: day, slots: Fixtures.slots([("19:30", .dinner, 2)])),
            ]),
            Fixtures.restaurant(id: "alleenlink", lat: 51.6876427, lon: 5.3058266, status: .linkOnly),
        ]
    }

    @Test func computesDistanceFromUserLocation() throws {
        let results = ResultRanking.results(from: restaurants, query: query, userLocation: markt, sort: .distance)
        let vught = try #require(results.first { $0.id == "verweg" })
        #expect(vught.distanceKm.map { $0 > 4.1 && $0 < 4.3 } == true)
    }

    @Test func sortsByDistanceAscending() {
        let results = ResultRanking.results(from: restaurants, query: query, userLocation: markt, sort: .distance)
        #expect(results.map(\.id) == ["alleenlink", "dichtbij", "verweg"])
    }

    @Test func sortsByMostAvailabilityThenDistance() {
        let results = ResultRanking.results(from: restaurants, query: query, userLocation: markt, sort: .availability)
        #expect(results.map(\.id) == ["verweg", "dichtbij", "alleenlink"])
    }

    @Test func withoutLocationDistanceIsNilAndOrderIsByName() {
        let results = ResultRanking.results(from: restaurants, query: query, userLocation: nil, sort: .distance)
        #expect(results.allSatisfy { $0.distanceKm == nil })
        #expect(results.map(\.id) == ["alleenlink", "dichtbij", "verweg"])
    }

    @Test func keepsLinkOnlyRestaurantsWithoutSlots() throws {
        let results = ResultRanking.results(from: restaurants, query: query, userLocation: markt, sort: .distance)
        let linkOnly = try #require(results.first { $0.id == "alleenlink" })
        #expect(linkOnly.slots.isEmpty)
        #expect(linkOnly.restaurant.status == .linkOnly)
    }

    @Test func carriesNextAvailableDayForEmptyDays() throws {
        let later = Fixtures.day("2026-09-19")
        let r = Fixtures.restaurant(id: "later", availability: [
            DayAvailability(date: later, slots: Fixtures.slots([("19:00", .dinner, 2)])),
        ])
        let results = ResultRanking.results(from: [r], query: query, userLocation: nil, sort: .distance)
        #expect(try #require(results.first).slots.isEmpty)
        #expect(try #require(results.first).nextAvailableDay == later)
    }
}
