import Foundation

enum AvailabilityOrigin: Sendable, Equatable {
    case network
    case cache
    case bundle
}

/// Het geladen contract-JSON plus waar het vandaan komt. `refreshError` is gevuld als verversen via
/// het netwerk mislukte en er oudere data (cache of bundel) wordt getoond.
struct LoadedAvailability: Sendable, Equatable {
    var data: Data
    var origin: AvailabilityOrigin
    var refreshError: String?

    init(data: Data, origin: AvailabilityOrigin, refreshError: String? = nil) {
        self.data = data
        self.origin = origin
        self.refreshError = refreshError
    }
}

/// Waar het contract-JSON vandaan komt. De app-bundel als basis; met een URL erbovenop (M1).
protocol AvailabilityLoading: Sendable {
    func load() async throws -> LoadedAvailability
}

struct BundleAvailabilityLoader: AvailabilityLoading {
    struct MissingResource: Error, LocalizedError {
        let name: String
        var errorDescription: String? { "Het bestand \(name).json ontbreekt in de app." }
    }

    private let url: URL?
    private let name: String

    init(bundle: Bundle = .main, resourceName: String = "availability") {
        self.url = bundle.url(forResource: resourceName, withExtension: "json")
        self.name = resourceName
    }

    func load() async throws -> LoadedAvailability {
        guard let url else { throw MissingResource(name: name) }
        return LoadedAvailability(data: try Data(contentsOf: url), origin: .bundle)
    }
}
