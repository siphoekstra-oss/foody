import SwiftUI

struct RestaurantDetailView: View {
    @Environment(AvailabilityStore.self) private var store
    let restaurantID: String

    var body: some View {
        if let restaurant = store.restaurant(id: restaurantID) {
            RestaurantDetailContent(restaurant: restaurant)
        } else {
            ContentUnavailableView("Restaurant niet gevonden", systemImage: "questionmark.circle")
        }
    }
}

private struct RestaurantDetailContent: View {
    @Environment(AvailabilityStore.self) private var store
    @Environment(LocationService.self) private var location
    @Environment(\.openURL) private var openURL
    let restaurant: Restaurant

    private func slots(_ service: Service) -> [Slot] {
        AvailabilityQuery.slots(for: restaurant, matching: SearchQuery(day: store.query.day, service: service, covers: store.query.covers))
    }

    private var dayLevelServices: [Service] {
        restaurant.availability.first { AmsterdamTime.isSameDay($0.date, store.query.day) }?.servicesAvailable ?? []
    }

    private var distanceText: String? {
        guard let from = store.userLocation else { return nil }
        let km = Distance.kilometers(fromLat: from.lat, lon: from.lon, toLat: restaurant.lat, lon: restaurant.lon)
        return DutchFormat.distance(kilometers: km) + (location.isUsingFallback ? " vanaf \(LocationService.fallbackLabel)" : "")
    }

    var body: some View {
        List {
            Section {
                RestaurantMetaLine(restaurant: restaurant)
                Label(restaurant.address, systemImage: "mappin.and.ellipse")
                if let distanceText {
                    Label(distanceText, systemImage: "location")
                }
            }

            Section {
                timesContent
            } header: {
                Text("\(DutchFormat.longDay(store.query.day)), \(store.query.covers) personen")
            } footer: {
                freshnessFooter
            }

            Section {
                if let url = MapsLink.url(for: restaurant) {
                    Button { openURL(url) } label: { Label("Openen op kaart", systemImage: "map") }
                }
                if let url = BookingLink.url(for: restaurant, day: store.query.day, slot: nil, covers: store.query.covers) {
                    Button { openURL(url) } label: { Label("Naar reserveringspagina", systemImage: "calendar.badge.plus") }
                }
                if let phone = restaurant.phone, let url = PhoneLink.url(phone) {
                    Button { openURL(url) } label: { Label("Bellen \(phone)", systemImage: "phone") }
                }
                if let site = restaurant.websiteURL, let url = URL(string: site) {
                    Button { openURL(url) } label: { Label("Website", systemImage: "safari") }
                }
            }
        }
        .navigationTitle(restaurant.name)
        .navigationBarTitleDisplayMode(.large)
    }

    @ViewBuilder
    private var timesContent: some View {
        switch restaurant.status {
        case .live:
            let lunch = slots(.lunch)
            let dinner = slots(.dinner)
            if lunch.isEmpty && dinner.isEmpty && !dayLevelServices.isEmpty {
                DayLevelNotice(restaurant: restaurant, services: dayLevelServices)
            } else if lunch.isEmpty && dinner.isEmpty {
                EmptyDayNotice(nextDay: AvailabilityQuery.nextAvailableDay(for: restaurant, after: store.query))
            } else {
                if !lunch.isEmpty { SlotGrid(title: "Middag", restaurant: restaurant, slots: lunch) }
                if !dinner.isEmpty { SlotGrid(title: "Avond", restaurant: restaurant, slots: dinner) }
            }
        case .linkOnly:
            StatusNotice(systemImage: "link", title: "Beschikbaarheid alleen op de site zichtbaar",
                         detail: "Wij kennen alleen de reserveringspagina van dit restaurant.", link: nil, linkTitle: "")
        case .unknown:
            StatusNotice(systemImage: "questionmark.circle", title: "Beschikbaarheid onbekend",
                         detail: "Het ophalen is mislukt. Kijk zelf op de reserveringspagina.", link: nil, linkTitle: "")
        }
    }

    @ViewBuilder
    private var freshnessFooter: some View {
        if let checked = restaurant.lastChecked {
            let stale = Freshness.isStale(checked)
            Label(stale ? "Mogelijk verouderd, gecontroleerd om \(DutchFormat.time(checked))"
                        : "Gecontroleerd om \(DutchFormat.time(checked))",
                  systemImage: stale ? "clock.badge.exclamationmark" : "clock")
        }
    }
}

private struct SlotGrid: View {
    @Environment(AvailabilityStore.self) private var store
    let title: String
    let restaurant: Restaurant
    let slots: [Slot]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(slots, id: \.self) { slot in
                    SlotChip(slot: slot, url: BookingLink.url(for: restaurant, day: store.query.day, slot: slot, covers: store.query.covers))
                }
            }
        }
        .padding(.vertical, 4)
    }
}
