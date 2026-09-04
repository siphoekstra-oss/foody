import Foundation
import Testing
@testable import Foody

struct AvailabilityDecoderErrorTests {
    /// Bouwt een geldig document waarin één tekstfragment is vervangen.
    private func document(replacing target: String, with replacement: String) -> Data {
        let json = AvailabilityDecodingTests.fullDocument.replacingOccurrences(of: target, with: replacement)
        precondition(json != AvailabilityDecodingTests.fullDocument, "vervanging '\(target)' niet gevonden")
        return Data(json.utf8)
    }

    @Test func rejectsBrokenJSON() {
        #expect(throws: (any Error).self) {
            try AvailabilityDecoder.decode(Data("{ \"generated_at\": ".utf8))
        }
    }

    @Test func rejectsDocumentWithoutRestaurants() {
        let json = """
        { "generated_at": "2026-09-04T18:00:00Z", "schema_version": 1, "city": "den-bosch" }
        """
        #expect(throws: (any Error).self) {
            try AvailabilityDecoder.decode(Data(json.utf8))
        }
    }

    @Test func rejectsNewerSchemaVersionWithSpecificError() {
        let data = document(replacing: "\"schema_version\": 1", with: "\"schema_version\": 2")
        #expect(throws: AvailabilityDecodingError.unsupportedSchemaVersion(2)) {
            try AvailabilityDecoder.decode(data)
        }
    }

    @Test func unknownStatusDecodesAsUnknown() throws {
        let data = document(replacing: "\"status\": \"live\"", with: "\"status\": \"paused\"")
        let doc = try AvailabilityDecoder.decode(data)
        #expect(doc.restaurants[0].status == .unknown)
    }

    @Test func rejectsInvalidDate() {
        let data = document(replacing: "\"date\": \"2026-09-12\"", with: "\"date\": \"2026-13-40\"")
        #expect(throws: (any Error).self) {
            try AvailabilityDecoder.decode(data)
        }
    }

    @Test func rejectsInvalidTime() {
        let data = document(replacing: "\"time\": \"19:30\"", with: "\"time\": \"25:99\"")
        #expect(throws: (any Error).self) {
            try AvailabilityDecoder.decode(data)
        }
    }

    @Test func acceptsFractionalSecondsInTimestamps() throws {
        let data = document(replacing: "2026-09-04T18:00:00Z", with: "2026-09-04T18:00:00.250Z")
        let doc = try AvailabilityDecoder.decode(data)
        let expected = try #require(ISO8601DateFormatter().date(from: "2026-09-04T18:00:00Z"))
        #expect(abs(doc.generatedAt.timeIntervalSince(expected) - 0.25) < 0.001)
    }
}
