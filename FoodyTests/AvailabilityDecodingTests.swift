import Foundation
import Testing
@testable import Foody

struct AvailabilityDecodingTests {
    static let fullDocument = """
    {
      "generated_at": "2026-09-04T18:00:00Z",
      "schema_version": 1,
      "city": "den-bosch",
      "source": "fixture",
      "restaurants": [
        {
          "id": "tante-pietje",
          "name": "Bistro Tante Pietje",
          "cuisine": "Bistro",
          "guides": { "michelin_stars": null, "gaultmillau": null, "bib": false },
          "price_indication_eur": null,
          "lat": 51.6873245,
          "lon": 5.3059731,
          "address": "Korte Putstraat 14, 5211 KP 's-Hertogenbosch",
          "website_url": "https://bistrotantepietje.nl/",
          "image_url": null,
          "phone": "+31736127027",
          "booking_provider": "guestplan",
          "booking_url": "https://widget.guestplan.com/?ak=abc",
          "deeplink_template": "https://widget.guestplan.com/?ak=abc&partySize={covers}",
          "status": "live",
          "last_checked": "2026-09-04T17:45:00Z",
          "availability": [
            {
              "date": "2026-09-12",
              "slots": [
                { "time": "12:15", "service": "lunch",  "max_covers": 4 },
                { "time": "19:30", "service": "dinner", "max_covers": 2 }
              ]
            }
          ]
        }
      ]
    }
    """

    @Test func decodesFullDocument() throws {
        let doc = try AvailabilityDecoder.decode(Data(Self.fullDocument.utf8))

        #expect(doc.schemaVersion == 1)
        #expect(doc.city == "den-bosch")
        #expect(doc.source == "fixture")
        #expect(doc.restaurants.count == 1)

        let r = try #require(doc.restaurants.first)
        #expect(r.id == "tante-pietje")
        #expect(r.name == "Bistro Tante Pietje")
        #expect(r.guides.michelinStars == nil)
        #expect(r.guides.bib == false)
        #expect(r.priceIndicationEUR == nil)
        #expect(r.phone == "+31736127027")
        #expect(r.status == .live)
        #expect(r.availability.count == 1)
        #expect(r.availability[0].slots.count == 2)
        #expect(r.availability[0].slots[0].service == .lunch)
        #expect(r.availability[0].slots[1].service == .dinner)
        #expect(r.availability[0].slots[1].maxCovers == 2)
    }
}
