import Foundation

enum AppConfiguration {
    /// Waar de crawler `availability.json` publiceert. `nil` zolang er nog geen hosting is: dan
    /// gebruikt de app alleen de snapshot in de bundel. Invullen is de enige wijziging voor M1.
    static let availabilityURL: URL? = nil

    /// De loader voor de store: netwerk met lokale kopie en bundel als vangnet, of alleen de bundel.
    static func makeLoader() -> any AvailabilityLoading {
        let bundle = BundleAvailabilityLoader()
        guard let url = availabilityURL else { return bundle }
        return RemoteAvailabilityLoader(url: url, cacheURL: RemoteAvailabilityLoader.defaultCacheURL(), fallback: bundle)
    }
}
