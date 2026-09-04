import Foundation

/// Haalt het contract-JSON van een URL, bewaart een leesbare kopie lokaal en valt bij problemen terug
/// op die kopie en daarna op de bundel. Nooit een lege app door een netwerkfout.
struct RemoteAvailabilityLoader: AvailabilityLoading {
    static let requestTimeout: TimeInterval = 15

    private let url: URL
    private let session: URLSession
    private let cacheURL: URL
    private let fallback: any AvailabilityLoading

    init(url: URL, session: URLSession = .shared, cacheURL: URL, fallback: any AvailabilityLoading) {
        self.url = url
        self.session = session
        self.cacheURL = cacheURL
        self.fallback = fallback
    }

    /// Standaardplek voor de lokale kopie: Application Support van de app.
    static func defaultCacheURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("availability-cache.json")
    }

    func load() async throws -> LoadedAvailability {
        do {
            let data = try await fetch()
            _ = try AvailabilityDecoder.decode(data) // alleen leesbare data bewaren
            try? data.write(to: cacheURL, options: .atomic)
            return LoadedAvailability(data: data, origin: .network)
        } catch {
            let message = Self.describe(error)
            if let cached = try? Data(contentsOf: cacheURL) {
                return LoadedAvailability(data: cached, origin: .cache, refreshError: message)
            }
            var fromBundle = try await fallback.load()
            fromBundle.refreshError = message
            return fromBundle
        }
    }

    private func fetch() async throws -> Data {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: Self.requestTimeout)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw RemoteError.noHTTPResponse }
        guard (200..<300).contains(http.statusCode) else { throw RemoteError.httpStatus(http.statusCode) }
        return data
    }

    enum RemoteError: Error {
        case noHTTPResponse
        case httpStatus(Int)
    }

    static func describe(_ error: Error) -> String {
        switch error {
        case let urlError as URLError where urlError.code == .notConnectedToInternet:
            return "Geen internetverbinding"
        case let urlError as URLError where urlError.code == .timedOut:
            return "De server reageerde niet op tijd"
        case is URLError:
            return "Geen verbinding met de server"
        case RemoteError.httpStatus(let status):
            return "De server gaf foutcode \(status)"
        case is DecodingError, is AvailabilityDecodingError:
            return "Het bestand van de server was onleesbaar"
        default:
            return "Verversen mislukt"
        }
    }
}
