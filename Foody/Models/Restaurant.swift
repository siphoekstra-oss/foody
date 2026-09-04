import Foundation

struct Restaurant: Codable, Equatable, Sendable, Identifiable {
    var id: String
    var name: String
    var cuisine: String
    var guides: Guides
    var priceIndicationEUR: Int?
    var lat: Double
    var lon: Double
    var address: String
    var websiteURL: String?
    var imageURL: String?
    /// E.164, bijv. `+31736127027`. Voor zaken die alleen telefonisch reserveren.
    var phone: String?
    var bookingProvider: String
    var bookingURL: String?
    /// Gebruikt `{date}` (YYYY-MM-DD), `{time}` (HH:mm) en `{covers}`.
    var deeplinkTemplate: String?
    var status: AvailabilityStatus
    var lastChecked: Date?
    var availability: [DayAvailability]

    enum CodingKeys: String, CodingKey {
        case id, name, cuisine, guides, lat, lon, address, phone, status, availability
        case priceIndicationEUR = "price_indication_eur"
        case websiteURL = "website_url"
        case imageURL = "image_url"
        case bookingProvider = "booking_provider"
        case bookingURL = "booking_url"
        case deeplinkTemplate = "deeplink_template"
        case lastChecked = "last_checked"
    }
}

struct Guides: Codable, Equatable, Sendable {
    var michelinStars: Int?
    var gaultmillau: Double?
    var bib: Bool?

    init(michelinStars: Int? = nil, gaultmillau: Double? = nil, bib: Bool? = nil) {
        self.michelinStars = michelinStars
        self.gaultmillau = gaultmillau
        self.bib = bib
    }

    enum CodingKeys: String, CodingKey {
        case michelinStars = "michelin_stars"
        case gaultmillau, bib
    }
}

/// `live`: beschikbaarheid echt opgehaald. `linkOnly`: alleen de boekingspagina bekend.
/// `unknown`: ophalen mislukt. Nooit `linkOnly` tonen als "vol".
enum AvailabilityStatus: String, Codable, Sendable {
    case live
    case linkOnly = "link_only"
    case unknown

    /// Een status die deze app niet kent, wordt `unknown`: liever "onbekend" dan een verkeerde belofte.
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = AvailabilityStatus(rawValue: raw) ?? .unknown
    }
}
