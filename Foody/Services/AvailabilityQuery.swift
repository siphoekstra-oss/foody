import Foundation

/// Wat de gebruiker zoekt: een dag, middag of avond, en de grootte van het gezelschap.
struct SearchQuery: Equatable, Sendable {
    var day: Date
    var service: Service
    var covers: Int

    init(day: Date, service: Service, covers: Int) {
        self.day = day
        self.service = service
        self.covers = covers
    }

    /// Startwaarde bij opstarten: vandaag, vóór 14:00 de middag en daarna de avond, voor twee personen.
    static func `default`(now: Date = Date()) -> SearchQuery {
        let hour = AmsterdamTime.calendar.component(.hour, from: now)
        return SearchQuery(
            day: AmsterdamTime.calendar.startOfDay(for: now),
            service: hour < 14 ? .lunch : .dinner,
            covers: 2
        )
    }
}

enum AvailabilityQuery {
    /// Tijdsloten op de gevraagde dag en in het gevraagde dagdeel met plek voor het gezelschap, op tijd gesorteerd.
    static func slots(for restaurant: Restaurant, matching query: SearchQuery) -> [Slot] {
        restaurant.availability
            .filter { AmsterdamTime.isSameDay($0.date, query.day) }
            .flatMap { day in matchingSlots(in: day, for: query) }
            .sorted { $0.dateTime(on: query.day) < $1.dateTime(on: query.day) }
    }

    /// Eerstvolgende dag ná de gevraagde dag waarop dit restaurant iets heeft voor dit dagdeel en gezelschap.
    static func nextAvailableDay(for restaurant: Restaurant, after query: SearchQuery) -> Date? {
        let requested = AmsterdamTime.calendar.startOfDay(for: query.day)
        return restaurant.availability
            .filter { $0.date > requested && !AmsterdamTime.isSameDay($0.date, requested) }
            .filter { !matchingSlots(in: $0, for: query).isEmpty }
            .map(\.date)
            .min()
    }

    private static func matchingSlots(in day: DayAvailability, for query: SearchQuery) -> [Slot] {
        day.slots.filter { $0.service == query.service && $0.maxCovers >= query.covers }
    }
}
