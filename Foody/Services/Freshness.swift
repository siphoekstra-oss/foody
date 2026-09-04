import Foundation

enum Freshness {
    /// Data ouder dan dit toont de app als "mogelijk verouderd".
    static let staleAfter: TimeInterval = 60 * 60

    static func isStale(_ checkedAt: Date, now: Date = Date()) -> Bool {
        now.timeIntervalSince(checkedAt) > staleAfter
    }
}
