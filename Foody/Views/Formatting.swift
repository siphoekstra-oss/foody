import Foundation

/// Nederlandse weergave in Europe/Amsterdam. Alleen presentatie; rekenen gebeurt in Services/.
enum DutchFormat {
    static let locale = Locale(identifier: "nl_NL")

    private static var base: Date.FormatStyle {
        Date.FormatStyle(locale: locale, calendar: AmsterdamTime.calendar, timeZone: AmsterdamTime.timeZone)
    }

    /// "vr 19 sep"
    static func day(_ date: Date) -> String {
        date.formatted(base.weekday(.abbreviated).day().month(.abbreviated))
    }

    /// "vrijdag 19 september"
    static func longDay(_ date: Date) -> String {
        date.formatted(base.weekday(.wide).day().month(.wide))
    }

    /// "12:48"
    static func time(_ date: Date) -> String {
        date.formatted(base.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
    }

    /// "850 m" onder de kilometer, daarboven "4,2 km".
    static func distance(kilometers km: Double) -> String {
        if km < 1 {
            let meters = Int((km * 100).rounded()) * 10
            return "\(meters) m"
        }
        return km.formatted(.number.precision(.fractionLength(1)).locale(locale)) + " km"
    }

    /// "€ 85 p.p."
    static func price(euro: Int) -> String { "€ \(euro) p.p." }
}

extension Guides {
    /// "★★ · Bib Gourmand · G&M 15,5", of `nil` zonder gidsvermelding.
    var summary: String? {
        var parts: [String] = []
        if let stars = michelinStars, stars > 0 { parts.append(String(repeating: "★", count: stars)) }
        if bib == true { parts.append("Bib Gourmand") }
        if let score = gaultmillau {
            parts.append("G&M " + score.formatted(.number.precision(.fractionLength(0...1)).locale(DutchFormat.locale)))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

enum MapsLink {
    /// Opent Apple Kaarten op de coördinaten met de restaurantnaam als label.
    static func url(for restaurant: Restaurant) -> URL? {
        var components = URLComponents(string: "https://maps.apple.com/")
        components?.queryItems = [
            URLQueryItem(name: "ll", value: "\(restaurant.lat),\(restaurant.lon)"),
            URLQueryItem(name: "q", value: restaurant.name),
        ]
        return components?.url
    }
}

enum PhoneLink {
    static func url(_ phone: String) -> URL? {
        URL(string: "tel:" + phone.filter { !$0.isWhitespace })
    }
}
