import Foundation

/// Waar het contract-JSON vandaan komt. M0: de app-bundel. M1: een URL met de bundel als fallback.
protocol AvailabilityLoading: Sendable {
    func load() async throws -> Data
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

    func load() async throws -> Data {
        guard let url else { throw MissingResource(name: name) }
        return try Data(contentsOf: url)
    }
}
