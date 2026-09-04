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
    /// Waar de getoonde data vandaan komt; `nil` zolang er niets geladen is.
    private(set) var origin: AvailabilityOrigin?
    /// Verversen via het netwerk mislukte; de getoonde data is ouder (cache of bundel).
    private(set) var refreshError: String?

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
            let loaded = try await loader.load()
            document = try AvailabilityDecoder.decode(loaded.data)
            origin = loaded.origin
            refreshError = loaded.refreshError
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
