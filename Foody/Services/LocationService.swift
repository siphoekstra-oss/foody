import CoreLocation
import Observation

/// Vraagt de locatie pas op het zoekscherm. Zonder toestemming of fix: het centrum van Den Bosch.
@MainActor
@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    /// Markt, 's-Hertogenbosch (OpenStreetMap). De regio van M0.
    static let fallback = Coordinate(lat: 51.6886843, lon: 5.3036562)
    static let fallbackLabel = "centrum Den Bosch"

    private(set) var coordinate: Coordinate?
    private(set) var isDenied = false
    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    /// Waar de app vanaf rekent: de echte locatie, anders de fallback.
    var effectiveCoordinate: Coordinate { coordinate ?? Self.fallback }
    var isUsingFallback: Bool { coordinate == nil }

    func requestIfNeeded() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            isDenied = true
        @unknown default:
            isDenied = true
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in self.handleAuthorization(status) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last else { return }
        let fix = Coordinate(lat: last.coordinate.latitude, lon: last.coordinate.longitude)
        Task { @MainActor in self.coordinate = fix }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Geen fix: de fallback blijft staan en de lijst meldt dat de afstand vanaf het centrum is.
    }

    private func handleAuthorization(_ status: CLAuthorizationStatus) {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            isDenied = false
            manager.requestLocation()
        case .denied, .restricted:
            isDenied = true
        default:
            break
        }
    }
}
