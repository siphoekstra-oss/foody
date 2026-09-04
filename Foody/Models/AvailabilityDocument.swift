import Foundation

/// Het datacontract van Foody (`schema_version` 1). De app kent alleen dit formaat;
/// waar het bestand vandaan komt (bundel, URL, crawler) maakt voor de app niet uit.
struct AvailabilityDocument: Codable, Equatable, Sendable {
    var generatedAt: Date
    var schemaVersion: Int
    var city: String
    /// `"fixture"` betekent verzonnen tijdsloten (M0). Ontbreekt of anders: echte data.
    var source: String?
    var restaurants: [Restaurant]

    init(generatedAt: Date, schemaVersion: Int, city: String, source: String? = nil, restaurants: [Restaurant]) {
        self.generatedAt = generatedAt
        self.schemaVersion = schemaVersion
        self.city = city
        self.source = source
        self.restaurants = restaurants
    }

    enum CodingKeys: String, CodingKey {
        case generatedAt = "generated_at"
        case schemaVersion = "schema_version"
        case city
        case source
        case restaurants
    }
}
