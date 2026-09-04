import Testing
@testable import Foody

struct DistanceTests {
    // Markt 's-Hertogenbosch en Brasserie 155 (Loonsebaan 155, Vught), coördinaten uit OpenStreetMap.
    let markt = (lat: 51.6886843, lon: 5.3036562)
    let brasserie155 = (lat: 51.6561549, lon: 5.2724359)
    let tantePietje = (lat: 51.6873245, lon: 5.3059731)

    @Test func marktToVughtIsAboutFourKilometers() {
        let km = Distance.kilometers(fromLat: markt.lat, lon: markt.lon, toLat: brasserie155.lat, lon: brasserie155.lon)
        #expect(km > 4.1 && km < 4.3)
    }

    @Test func marktToKortePutstraatIsAFewHundredMeters() {
        let km = Distance.kilometers(fromLat: markt.lat, lon: markt.lon, toLat: tantePietje.lat, lon: tantePietje.lon)
        #expect(km > 0.15 && km < 0.30)
    }

    @Test func distanceIsSymmetricAndZeroForSamePoint() {
        let ab = Distance.kilometers(fromLat: markt.lat, lon: markt.lon, toLat: brasserie155.lat, lon: brasserie155.lon)
        let ba = Distance.kilometers(fromLat: brasserie155.lat, lon: brasserie155.lon, toLat: markt.lat, lon: markt.lon)
        #expect(abs(ab - ba) < 0.000001)
        #expect(Distance.kilometers(fromLat: markt.lat, lon: markt.lon, toLat: markt.lat, lon: markt.lon) == 0)
    }
}
