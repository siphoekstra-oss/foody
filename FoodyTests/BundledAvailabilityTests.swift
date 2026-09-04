import Foundation
import Testing
@testable import Foody

/// Contracttest op het bestand dat écht in de app zit: als de crawler of het schema verandert
/// zonder dat de app meekomt, faalt dit hier en niet pas op de telefoon.
@MainActor
struct BundledAvailabilityTests {
    private func loadBundled() async throws -> AvailabilityDocument {
        let data = try await BundleAvailabilityLoader(bundle: .main).load()
        return try AvailabilityDecoder.decode(data)
    }

    @Test func bundledAvailabilityDecodesAgainstSchemaVersion1() async throws {
        let doc = try await loadBundled()
        #expect(doc.schemaVersion == AvailabilityDecoder.supportedSchemaVersion)
        #expect(doc.source == "crawler", "de bundel bevat een echte crawler-snapshot, geen nepdata")
        #expect(!doc.restaurants.isEmpty)
    }

    @Test func everyBundledRestaurantHasUsableCoordinatesAndLinks() async throws {
        let doc = try await loadBundled()
        for r in doc.restaurants {
            #expect((50.5...53.7).contains(r.lat) && (3.2...7.3).contains(r.lon), "\(r.id) ligt buiten Nederland")
            #expect(!r.address.isEmpty, "\(r.id) heeft geen adres")
            if let booking = r.bookingURL {
                #expect(URL(string: booking)?.scheme == "https", "\(r.id): boekings-URL is geen https")
            } else {
                #expect(r.status != .live, "\(r.id) is live zonder boekings-URL")
            }
        }
    }

    @Test func bundledSlotsAreExplicitAboutService() async throws {
        let doc = try await loadBundled()
        for r in doc.restaurants {
            for day in r.availability {
                for slot in day.slots {
                    let hour = AmsterdamTime.hourMinute(fromHHmm: slot.time)?.hour ?? -1
                    #expect((hour < 16) == (slot.service == .lunch), "\(r.id) \(slot.time) heeft service \(slot.service)")
                    #expect(slot.maxCovers >= 1)
                }
            }
        }
    }

    @Test func idsAreUnique() async throws {
        let doc = try await loadBundled()
        let ids = doc.restaurants.map(\.id)
        #expect(Set(ids).count == ids.count)
    }
}
