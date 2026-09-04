import Foundation

struct Coordinate: Equatable, Sendable {
    var lat: Double
    var lon: Double

    init(lat: Double, lon: Double) {
        self.lat = lat
        self.lon = lon
    }
}

/// Eén regel in de resultatenlijst: het restaurant met wat er voor deze zoekopdracht vrij is.
struct RestaurantResult: Identifiable, Equatable, Sendable {
    var restaurant: Restaurant
    var distanceKm: Double?
    var slots: [Slot]
    /// "Vrij" gemeld voor dit dagdeel zonder tijden; zie `DayAvailability.servicesAvailable`.
    var hasDayLevelAvailability: Bool
    /// Eerstvolgende dag met iets vrij, voor de lege staat. `nil` als er niets volgt.
    var nextAvailableDay: Date?

    var id: String { restaurant.id }

    /// Voor sorteren op "meeste beschikbaarheid": echte tijdsloten gaan altijd boven een dag-niveau-melding,
    /// die weer boven "niets" gaat.
    var availabilityScore: Int { slots.isEmpty ? (hasDayLevelAvailability ? 1 : 0) : slots.count + 1 }
}

enum ResultSort: String, CaseIterable, Sendable {
    case distance
    case availability
}

enum ResultRanking {
    static func results(
        from restaurants: [Restaurant],
        query: SearchQuery,
        userLocation: Coordinate?,
        sort: ResultSort
    ) -> [RestaurantResult] {
        let results = restaurants.map { restaurant in
            RestaurantResult(
                restaurant: restaurant,
                distanceKm: userLocation.map {
                    Distance.kilometers(fromLat: $0.lat, lon: $0.lon, toLat: restaurant.lat, lon: restaurant.lon)
                },
                slots: AvailabilityQuery.slots(for: restaurant, matching: query),
                hasDayLevelAvailability: AvailabilityQuery.hasDayLevelAvailability(for: restaurant, matching: query),
                nextAvailableDay: AvailabilityQuery.nextAvailableDay(for: restaurant, after: query)
            )
        }
        switch sort {
        case .distance:
            return results.sorted(by: isCloser)
        case .availability:
            return results.sorted { a, b in
                a.availabilityScore != b.availabilityScore ? a.availabilityScore > b.availabilityScore : isCloser(a, b)
            }
        }
    }

    /// Op afstand; zonder locatie op naam, zodat de volgorde altijd voorspelbaar is.
    private static func isCloser(_ a: RestaurantResult, _ b: RestaurantResult) -> Bool {
        switch (a.distanceKm, b.distanceKm) {
        case let (da?, db?) where da != db:
            return da < db
        default:
            return a.restaurant.name.localizedStandardCompare(b.restaurant.name) == .orderedAscending
        }
    }
}
