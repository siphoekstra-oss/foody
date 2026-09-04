import Foundation

struct DayAvailability: Codable, Equatable, Sendable {
    /// Begin van de dag in Europe/Amsterdam.
    var date: Date
    var slots: [Slot]

    init(date: Date, slots: [Slot]) {
        self.date = date
        self.slots = slots
    }

    enum CodingKeys: String, CodingKey { case date, slots }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let raw = try c.decode(String.self, forKey: .date)
        guard let day = AmsterdamTime.day(fromISODate: raw) else {
            throw DecodingError.dataCorruptedError(forKey: .date, in: c, debugDescription: "Ongeldige datum '\(raw)', verwacht YYYY-MM-DD")
        }
        date = day
        slots = try c.decode([Slot].self, forKey: .slots)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(AmsterdamTime.isoDate(from: date), forKey: .date)
        try c.encode(slots, forKey: .slots)
    }
}

struct Slot: Codable, Hashable, Sendable {
    /// `HH:mm`, lokale tijd Europe/Amsterdam. Bewaard als tekst voor de deeplink.
    var time: String
    var service: Service
    var maxCovers: Int

    init(time: String, service: Service, maxCovers: Int) {
        self.time = time
        self.service = service
        self.maxCovers = maxCovers
    }

    enum CodingKeys: String, CodingKey {
        case time, service
        case maxCovers = "max_covers"
    }

    /// Het tijdslot als volledig tijdstip op de gegeven (Amsterdamse) dag.
    func dateTime(on day: Date) -> Date {
        let hm = AmsterdamTime.hourMinute(fromHHmm: time) ?? (hour: 0, minute: 0)
        let start = AmsterdamTime.calendar.startOfDay(for: day)
        return AmsterdamTime.calendar.date(bySettingHour: hm.hour, minute: hm.minute, second: 0, of: start) ?? start
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let raw = try c.decode(String.self, forKey: .time)
        guard AmsterdamTime.hourMinute(fromHHmm: raw) != nil else {
            throw DecodingError.dataCorruptedError(forKey: .time, in: c, debugDescription: "Ongeldige tijd '\(raw)', verwacht HH:mm")
        }
        time = raw
        service = try c.decode(Service.self, forKey: .service)
        maxCovers = try c.decode(Int.self, forKey: .maxCovers)
    }
}

/// Vóór 16:00 is lunch, daarna diner. Staat expliciet in de JSON; de app leidt niets af.
enum Service: String, Codable, Sendable, CaseIterable {
    case lunch
    case dinner
}
