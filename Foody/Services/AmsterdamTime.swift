import Foundation

/// Alle datum- en tijdlogica in de app rekent in Europe/Amsterdam.
enum AmsterdamTime {
    static let timeZone = TimeZone(identifier: "Europe/Amsterdam")!

    static var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        cal.locale = Locale(identifier: "nl_NL")
        return cal
    }

    /// `"2026-09-12"` → begin van die dag in Amsterdam. `nil` bij een ongeldige tekst.
    static func day(fromISODate text: String) -> Date? {
        let parts = text.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3,
              let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]),
              parts[1].count == 2, parts[2].count == 2 else { return nil }
        var comps = DateComponents()
        comps.year = y
        comps.month = m
        comps.day = d
        guard let date = calendar.date(from: comps),
              calendar.component(.day, from: date) == d,
              calendar.component(.month, from: date) == m else { return nil }
        return calendar.startOfDay(for: date)
    }

    /// `"19:30"` → `(19, 30)`. `nil` bij een ongeldige tekst.
    static func hourMinute(fromHHmm text: String) -> (hour: Int, minute: Int)? {
        let parts = text.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2, parts[0].count == 2, parts[1].count == 2,
              let h = Int(parts[0]), let m = Int(parts[1]),
              (0...23).contains(h), (0...59).contains(m) else { return nil }
        return (h, m)
    }

    /// Zelfde kalenderdag in Amsterdam, ongeacht het tijdstip.
    static func isSameDay(_ a: Date, _ b: Date) -> Bool {
        calendar.isDate(a, inSameDayAs: b)
    }

    /// Begin van de Amsterdamse dag → `"2026-09-12"`.
    static func isoDate(from date: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }
}
