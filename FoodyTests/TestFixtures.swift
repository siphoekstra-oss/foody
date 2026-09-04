import Foundation
@testable import Foody

enum Fixtures {
    static func day(_ iso: String) -> Date { AmsterdamTime.day(fromISODate: iso)! }

    static func restaurant(
        id: String = "r",
        lat: Double = 51.6873245,
        lon: Double = 5.3059731,
        status: AvailabilityStatus = .live,
        bookingURL: String? = "https://example.com/book",
        deeplinkTemplate: String? = nil,
        availability: [DayAvailability] = []
    ) -> Restaurant {
        Restaurant(
            id: id, name: id.capitalized, cuisine: "Bistro", guides: Guides(), priceIndicationEUR: nil,
            lat: lat, lon: lon, address: "Teststraat 1, Den Bosch", websiteURL: nil, imageURL: nil, phone: nil,
            bookingProvider: "guestplan", bookingURL: bookingURL, deeplinkTemplate: deeplinkTemplate,
            status: status, lastChecked: nil, availability: availability
        )
    }

    static func slots(_ specs: [(String, Service, Int)]) -> [Slot] {
        specs.map { Slot(time: $0.0, service: $0.1, maxCovers: $0.2) }
    }
}
