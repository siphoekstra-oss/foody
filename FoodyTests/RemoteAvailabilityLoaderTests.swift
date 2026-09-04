import Foundation
import Testing
@testable import Foody

/// Speelt de server voor URLSession: per test één script van antwoorden.
final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) throws -> (Int, Data))?
    nonisolated(unsafe) static var requests: [URLRequest] = []

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.requests.append(request)
        do {
            guard let handler = Self.handler else { throw URLError(.notConnectedToInternet) }
            let (status, body) = try handler(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: body)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

/// Geserialiseerd: de stub-handler is gedeelde staat.
@Suite(.serialized)
struct RemoteAvailabilityLoaderTests {
    let url = URL(string: "https://example.test/availability.json")!
    let validJSON = Data(AvailabilityDecodingTests.fullDocument.utf8)

    private func makeLoader(bundleData: Data? = nil) -> (RemoteAvailabilityLoader, URL) {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        let cacheURL = FileManager.default.temporaryDirectory.appendingPathComponent("foody-test-\(UUID().uuidString).json")
        let loader = RemoteAvailabilityLoader(url: url, session: URLSession(configuration: config), cacheURL: cacheURL,
                                              fallback: StubLoader(data: bundleData))
        return (loader, cacheURL)
    }

    @Test func networkSuccessReturnsFreshDataAndWritesCache() async throws {
        let (loader, cacheURL) = makeLoader()
        let json = validJSON
        StubURLProtocol.handler = { _ in (200, json) }

        let loaded = try await loader.load()

        #expect(loaded.origin == .network)
        #expect(loaded.refreshError == nil)
        #expect(loaded.data == json)
        #expect(FileManager.default.fileExists(atPath: cacheURL.path))
    }

    @Test func networkFailureFallsBackToCacheWithError() async throws {
        let (loader, cacheURL) = makeLoader()
        try validJSON.write(to: cacheURL)
        StubURLProtocol.handler = { _ in throw URLError(.notConnectedToInternet) }

        let loaded = try await loader.load()

        #expect(loaded.origin == .cache)
        #expect(loaded.refreshError?.isEmpty == false)
        #expect(loaded.data == validJSON)
    }

    @Test func networkFailureWithoutCacheFallsBackToBundle() async throws {
        let (loader, _) = makeLoader(bundleData: validJSON)
        StubURLProtocol.handler = { _ in (503, Data()) }

        let loaded = try await loader.load()

        #expect(loaded.origin == .bundle)
        #expect(loaded.refreshError?.isEmpty == false)
    }

    @Test func corruptRemoteDataIsNotCachedAndFallsBack() async throws {
        let (loader, cacheURL) = makeLoader(bundleData: validJSON)
        StubURLProtocol.handler = { _ in (200, Data("nonsens".utf8)) }

        let loaded = try await loader.load()

        #expect(loaded.origin == .bundle)
        #expect(!FileManager.default.fileExists(atPath: cacheURL.path))
    }

    @Test func everythingFailingThrows() async {
        let (loader, _) = makeLoader(bundleData: nil)
        StubURLProtocol.handler = { _ in throw URLError(.timedOut) }
        await #expect(throws: (any Error).self) { try await loader.load() }
    }

    @Test func requestsBypassURLCache() async throws {
        let (loader, _) = makeLoader()
        let json = validJSON
        StubURLProtocol.requests = []
        StubURLProtocol.handler = { _ in (200, json) }
        _ = try await loader.load()
        #expect(StubURLProtocol.requests.last?.cachePolicy == .reloadIgnoringLocalCacheData)
    }
}

@MainActor
struct BundleLoaderOriginTests {
    @Test func bundleLoaderReportsBundleOrigin() async throws {
        let loaded = try await StubLoader(data: Data("{}".utf8)).load()
        #expect(loaded.origin == .bundle)
    }
}
