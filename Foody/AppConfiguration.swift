import Foundation

enum AppConfiguration {
    /// Waar de crawler `availability.json` publiceert (GitHub Pages, elk half uur ververst door
    /// .github/workflows/crawl.yml). Op `nil` gebruikt de app alleen de snapshot in de bundel.
    static let availabilityURL: URL? = URL(string: "https://siphoekstra-oss.github.io/foody/availability.json")

    /// De loader voor de store: netwerk met lokale kopie en bundel als vangnet, of alleen de bundel.
    static func makeLoader() -> any AvailabilityLoading {
        let bundle = BundleAvailabilityLoader()
        guard let url = availabilityURL else { return bundle }
        return RemoteAvailabilityLoader(url: url, cacheURL: RemoteAvailabilityLoader.defaultCacheURL(), fallback: bundle)
    }
}
