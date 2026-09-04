import Foundation
import Testing
@testable import Foody

struct BookingLinkTests {
    let day = Fixtures.day("2026-09-12")
    let slot = Slot(time: "19:30", service: .dinner, maxCovers: 2)

    @Test func fillsDateTimeAndCoversIntoTemplate() {
        let r = Fixtures.restaurant(deeplinkTemplate: "https://x.test/book?d={date}&t={time}&c={covers}")
        let url = BookingLink.url(for: r, day: day, slot: slot, covers: 2)
        #expect(url?.absoluteString == "https://x.test/book?d=2026-09-12&t=19:30&c=2")
    }

    @Test func fallsBackToBookingURLWithoutTemplate() {
        let r = Fixtures.restaurant(bookingURL: "https://x.test/reserveren", deeplinkTemplate: nil)
        #expect(BookingLink.url(for: r, day: day, slot: slot, covers: 2)?.absoluteString == "https://x.test/reserveren")
    }

    @Test func isNilWithoutAnyLink() {
        let r = Fixtures.restaurant(bookingURL: nil, deeplinkTemplate: nil)
        #expect(BookingLink.url(for: r, day: day, slot: slot, covers: 2) == nil)
    }

    @Test func leavesTimeEmptyWhenNoSlotIsChosen() {
        let r = Fixtures.restaurant(deeplinkTemplate: "https://x.test/book?d={date}&t={time}&c={covers}")
        let url = BookingLink.url(for: r, day: day, slot: nil, covers: 3)
        #expect(url?.absoluteString == "https://x.test/book?d=2026-09-12&t=&c=3")
    }
}
