import Foundation

enum Distance {
    private static let earthRadiusKm = 6371.0088

    /// Grootcirkelafstand (haversine) in kilometers.
    static func kilometers(fromLat lat1: Double, lon lon1: Double, toLat lat2: Double, lon lon2: Double) -> Double {
        let dLat = (lat2 - lat1).degreesToRadians
        let dLon = (lon2 - lon1).degreesToRadians
        let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1.degreesToRadians) * cos(lat2.degreesToRadians) * sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(max(0, 1 - a)))
        return earthRadiusKm * c
    }
}

private extension Double {
    var degreesToRadians: Double { self * .pi / 180 }
}
