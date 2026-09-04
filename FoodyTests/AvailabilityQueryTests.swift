import Foundation
import Testing
@testable import Foody

struct AvailabilityQueryTests {
    let sept12 = Fixtures.day("2026-09-12")

    var restaurant: Restaurant {
        Fixtures.restaurant(availability: [
            DayAvailability(date: sept12, slots: Fixtures.slots([("19:30", .dinner, 2), ("12:15", .lunch, 4), ("18:00", .dinner, 6)])),
            DayAvailability(date: Fixtures.day("2026-09-15"), slots: Fixtures.slots([("20:00", .dinner, 2)])),
            DayAvailability(date: Fixtures.day("2026-09-20"), slots: Fixtures.slots([("19:00", .dinner, 4)])),
        ])
    }

    @Test func returnsOnlySlotsOfRequestedService() {
        let query = SearchQuery(day: sept12, service: .lunch, covers: 2)
        #expect(AvailabilityQuery.slots(for: restaurant, matching: query).map(\.time) == ["12:15"])
    }

    @Test func dropsSlotsTooSmallForTheParty() {
        let query = SearchQuery(day: sept12, service: .dinner, covers: 4)
        #expect(AvailabilityQuery.slots(for: restaurant, matching: query).map(\.time) == ["18:00"])
    }

    @Test func sortsSlotsByTime() {
        let query = SearchQuery(day: sept12, service: .dinner, covers: 2)
        #expect(AvailabilityQuery.slots(for: restaurant, matching: query).map(\.time) == ["18:00", "19:30"])
    }

    @Test func matchesTheDayRegardlessOfTimeOfDay() throws {
        let afternoon = try #require(AmsterdamTime.calendar.date(bySettingHour: 15, minute: 42, second: 0, of: sept12))
        let query = SearchQuery(day: afternoon, service: .lunch, covers: 1)
        #expect(AvailabilityQuery.slots(for: restaurant, matching: query).count == 1)
    }

    @Test func nextAvailableDaySkipsDaysWithoutRoomForTheParty() {
        let query = SearchQuery(day: sept12, service: .dinner, covers: 4)
        #expect(AvailabilityQuery.nextAvailableDay(for: restaurant, after: query) == Fixtures.day("2026-09-20"))
    }

    @Test func nextAvailableDayIsStrictlyAfterTheRequestedDay() {
        let query = SearchQuery(day: sept12, service: .dinner, covers: 2)
        #expect(AvailabilityQuery.nextAvailableDay(for: restaurant, after: query) == Fixtures.day("2026-09-15"))
    }

    @Test func nextAvailableDayIsNilWhenNothingFollows() {
        let query = SearchQuery(day: Fixtures.day("2026-09-20"), service: .dinner, covers: 2)
        #expect(AvailabilityQuery.nextAvailableDay(for: restaurant, after: query) == nil)
    }

    @Test func nextAvailableDayHonoursTheService() {
        let query = SearchQuery(day: sept12, service: .lunch, covers: 2)
        #expect(AvailabilityQuery.nextAvailableDay(for: restaurant, after: query) == nil)
    }
}
