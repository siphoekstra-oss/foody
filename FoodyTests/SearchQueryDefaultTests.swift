import Foundation
import Testing
@testable import Foody

struct SearchQueryDefaultTests {
    private func amsterdam(_ iso: String, hour: Int) -> Date {
        AmsterdamTime.calendar.date(bySettingHour: hour, minute: 0, second: 0, of: Fixtures.day(iso))!
    }

    @Test func morningDefaultsToLunchToday() {
        let q = SearchQuery.default(now: amsterdam("2026-09-04", hour: 9))
        #expect(AmsterdamTime.isSameDay(q.day, Fixtures.day("2026-09-04")))
        #expect(q.service == .lunch)
        #expect(q.covers == 2)
    }

    @Test func afternoonDefaultsToDinnerToday() {
        let q = SearchQuery.default(now: amsterdam("2026-09-04", hour: 14))
        #expect(q.service == .dinner)
    }

    @Test func lateEveningStillDefaultsToToday() {
        let q = SearchQuery.default(now: amsterdam("2026-09-04", hour: 23))
        #expect(AmsterdamTime.isSameDay(q.day, Fixtures.day("2026-09-04")))
        #expect(q.service == .dinner)
    }
}
