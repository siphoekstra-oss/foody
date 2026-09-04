import Foundation
import Observation

/// De enige bron van waarheid voor de views. Views bevatten geen netwerk- of parseerlogica.
@MainActor
@Observable
final class AvailabilityStore {
    private(set) var document: AvailabilityDocument?
    /// Leesbare melding voor de gebruiker als laden of lezen mislukt.
    private(set) var loadError: String?
    private(set) var isLoading = false

    var query: SearchQuery
    var sort: ResultSort = .distance
    var userLocation: Coordinate?

    private let loader: any AvailabilityLoading

    init(loader: any AvailabilityLoading, query: SearchQuery) {
        self.loader = loader
        self.query = query
    }

    var results: [RestaurantResult] {
        guard let document else { return [] }
        return ResultRanking.results(from: document.restaurants, query: query, userLocation: userLocation, sort: sort)
    }

    /// Nepdata uit de bundel (M0). De UI toont hiervoor een badge.
    var isFixtureData: Bool { document?.source == "fixture" }

    func isStale(now: Date = Date()) -> Bool {
        guard let document else { return false }
        return Freshness.isStale(document.generatedAt, now: now)
    }

    func restaurant(id: String) -> Restaurant? {
        document?.restaurants.first { $0.id == id }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let data = try await loader.load()
            document = try AvailabilityDecoder.decode(data)
            loadError = nil
        } catch let error as AvailabilityDecodingError {
            loadError = error.errorDescription
        } catch is DecodingError {
            loadError = "De beschikbaarheidsdata kon niet worden gelezen."
        } catch {
            loadError = "De beschikbaarheidsdata kon niet worden geladen: \(error.localizedDescription)"
        }
    }
}
