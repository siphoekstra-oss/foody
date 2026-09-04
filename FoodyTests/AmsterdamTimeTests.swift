import Foundation
import Testing
@testable import Foody

struct AmsterdamTimeTests {
    @Test func isoDateRoundTripsThroughStartOfDay() throws {
        let day = try #require(AmsterdamTime.day(fromISODate: "2026-09-12"))
        let comps = AmsterdamTime.calendar.dateComponents([.hour, .minute], from: day)
        #expect(comps.hour == 0)
        #expect(comps.minute == 0)
        #expect(AmsterdamTime.isoDate(from: day) == "2026-09-12")
    }

    @Test func rejectsMalformedISODates() {
        #expect(AmsterdamTime.day(fromISODate: "12-09-2026") == nil)
        #expect(AmsterdamTime.day(fromISODate: "2026-9-12") == nil)
        #expect(AmsterdamTime.day(fromISODate: "2026-02-30") == nil)
        #expect(AmsterdamTime.day(fromISODate: "") == nil)
    }

    @Test func slotDateTimeCombinesDayAndLocalTime() throws {
        let day = try #require(AmsterdamTime.day(fromISODate: "2026-09-12"))
        let slot = Slot(time: "19:30", service: .dinner, maxCovers: 2)

        let when = slot.dateTime(on: day)

        let local = AmsterdamTime.calendar.dateComponents([.year, .month, .day, .hour, .minute], from: when)
        #expect(local.year == 2026 && local.month == 9 && local.day == 12)
        #expect(local.hour == 19 && local.minute == 30)
        // Zomertijd: 19:30 in Amsterdam is 17:30 UTC.
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        #expect(utc.component(.hour, from: when) == 17)
    }

    @Test func sameDayIgnoresTimeOfDay() throws {
        let midnight = try #require(AmsterdamTime.day(fromISODate: "2026-09-12"))
        let afternoon = try #require(AmsterdamTime.calendar.date(bySettingHour: 15, minute: 42, second: 0, of: midnight))
        let nextDay = try #require(AmsterdamTime.day(fromISODate: "2026-09-13"))

        #expect(AmsterdamTime.isSameDay(afternoon, midnight))
        #expect(!AmsterdamTime.isSameDay(nextDay, midnight))
    }
}
