import Foundation
import Testing
@testable import Foody

struct FreshnessTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func olderThanSixtyMinutesIsStale() {
        #expect(Freshness.isStale(now.addingTimeInterval(-61 * 60), now: now))
    }

    @Test func withinSixtyMinutesIsFresh() {
        #expect(!Freshness.isStale(now.addingTimeInterval(-59 * 60), now: now))
    }
}
