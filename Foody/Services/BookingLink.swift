import Foundation

enum BookingLink {
    /// De reserveerlink voor dit restaurant. Met `deeplink_template` worden `{date}`, `{time}` en
    /// `{covers}` ingevuld; zonder template is het de kale `booking_url`; zonder beide is er geen link.
    static func url(for restaurant: Restaurant, day: Date, slot: Slot?, covers: Int) -> URL? {
        if let template = restaurant.deeplinkTemplate {
            let filled = template
                .replacingOccurrences(of: "{date}", with: AmsterdamTime.isoDate(from: day))
                .replacingOccurrences(of: "{time}", with: slot?.time ?? "")
                .replacingOccurrences(of: "{covers}", with: String(covers))
            return URL(string: filled)
        }
        return restaurant.bookingURL.flatMap(URL.init(string:))
    }
}
