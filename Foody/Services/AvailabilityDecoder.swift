import Foundation

enum AvailabilityDecodingError: Error, Equatable, LocalizedError {
    /// Het bestand heeft een nieuwer schema dan deze app kent. De app weigert het netjes.
    case unsupportedSchemaVersion(Int)

    var errorDescription: String? {
        switch self {
        case .unsupportedSchemaVersion(let v):
            return "Deze versie van Foody kent dataformaat \(v) nog niet. Werk de app bij."
        }
    }
}

enum AvailabilityDecoder {
    static let supportedSchemaVersion = 1

    static func decode(_ data: Data) throws -> AvailabilityDocument {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom(decodeISO8601)

        // Eerst alleen de versie lezen, zodat een nieuwer schema een duidelijke fout geeft
        // in plaats van een willekeurige ontbrekende sleutel.
        let probe = try decoder.decode(SchemaProbe.self, from: data)
        guard probe.schemaVersion <= supportedSchemaVersion else {
            throw AvailabilityDecodingError.unsupportedSchemaVersion(probe.schemaVersion)
        }
        return try decoder.decode(AvailabilityDocument.self, from: data)
    }

    private struct SchemaProbe: Decodable {
        let schemaVersion: Int
        enum CodingKeys: String, CodingKey { case schemaVersion = "schema_version" }
    }

    private static func decodeISO8601(_ decoder: Decoder) throws -> Date {
        let container = try decoder.singleValueContainer()
        let text = try container.decode(String.self)
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        if let date = withFraction.date(from: text) ?? plain.date(from: text) {
            return date
        }
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Ongeldig tijdstip '\(text)', verwacht ISO 8601 zoals 2026-09-04T18:00:00Z")
    }
}
