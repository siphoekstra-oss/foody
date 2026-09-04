import SwiftUI

/// Eén restaurant in de lijst. De kop navigeert naar het detail; de chips openen de reserveerlink.
struct RestaurantCard: View {
    let result: RestaurantResult

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            NavigationLink(value: RestaurantRoute(id: result.id)) {
                CardHeader(result: result)
            }
            .buttonStyle(.plain)
            AvailabilityRow(result: result)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct CardHeader: View {
    let result: RestaurantResult

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(result.restaurant.name)
                    .font(.title3.weight(.semibold))
                RestaurantMetaLine(restaurant: result.restaurant)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 4) {
                if let km = result.distanceKm {
                    Text(DutchFormat.distance(kilometers: km))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .contentShape(Rectangle())
    }
}

/// Gidsvermelding, keuken en prijsindicatie op één regel; lege velden worden overgeslagen.
struct RestaurantMetaLine: View {
    let restaurant: Restaurant

    private var parts: [String] {
        [restaurant.guides.summary, restaurant.cuisine, restaurant.priceIndicationEUR.map(DutchFormat.price(euro:))]
            .compactMap { $0 }
    }

    var body: some View {
        Text(parts.joined(separator: " · "))
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }
}

/// De drie statussen zien er verschillend uit; `link_only` is nooit "vol".
struct AvailabilityRow: View {
    @Environment(AvailabilityStore.self) private var store
    let result: RestaurantResult

    var body: some View {
        switch result.restaurant.status {
        case .live where !result.slots.isEmpty:
            SlotStrip(restaurant: result.restaurant, slots: result.slots)
        case .live where result.hasDayLevelAvailability:
            DayLevelNotice(restaurant: result.restaurant, services: [store.query.service])
        case .live:
            EmptyDayNotice(nextDay: result.nextAvailableDay)
        case .linkOnly:
            StatusNotice(systemImage: "link",
                         title: "Beschikbaarheid alleen op de site zichtbaar",
                         detail: "Wij kennen alleen de reserveringspagina van dit restaurant.",
                         link: BookingLink.url(for: result.restaurant, day: store.query.day, slot: nil, covers: store.query.covers),
                         linkTitle: "Naar reserveringspagina")
        case .unknown:
            StatusNotice(systemImage: "questionmark.circle",
                         title: "Beschikbaarheid onbekend",
                         detail: result.restaurant.lastChecked.map { "Ophalen mislukt, laatste controle \(DutchFormat.time($0))" }
                             ?? "Ophalen mislukt.",
                         link: BookingLink.url(for: result.restaurant, day: store.query.day, slot: nil, covers: store.query.covers),
                         linkTitle: "Zelf kijken op de reserveringspagina")
        }
    }
}

/// Horizontaal scrollende rij tijdslot-chips.
struct SlotStrip: View {
    @Environment(AvailabilityStore.self) private var store
    let restaurant: Restaurant
    let slots: [Slot]

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(slots, id: \.self) { slot in
                    SlotChip(slot: slot, url: BookingLink.url(for: restaurant, day: store.query.day, slot: slot, covers: store.query.covers))
                }
            }
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
    }
}

struct EmptyDayNotice: View {
    @Environment(AvailabilityStore.self) private var store
    let nextDay: Date?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "calendar.badge.exclamationmark")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text("Niets vrij op deze datum")
                    .font(.subheadline.weight(.medium))
                if let nextDay {
                    Button("Eerstvolgende: \(DutchFormat.day(nextDay))") {
                        store.query.day = nextDay
                    }
                    .font(.subheadline)
                } else {
                    Text("Ook niets in de komende weken")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

/// Het systeem meldt "vrij" voor een dagdeel maar geeft geen tijden (Guestplan op dag-niveau).
struct DayLevelNotice: View {
    @Environment(AvailabilityStore.self) private var store
    @Environment(\.openURL) private var openURL
    let restaurant: Restaurant
    let services: [Service]

    private var title: String {
        switch services {
        case [.lunch]: return "Vrij in de middag"
        case [.dinner]: return "Vrij in de avond"
        default: return "Vrij in de middag en de avond"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.circle")
                .foregroundStyle(.green)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.weight(.medium))
                Text("Dit reserveersysteem geeft geen tijden door; kies je tijd op de reserveringspagina.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let url = BookingLink.url(for: restaurant, day: store.query.day, slot: nil, covers: store.query.covers) {
                    Button("Naar reserveringspagina") { openURL(url) }
                        .font(.subheadline)
                }
            }
        }
    }
}

struct StatusNotice: View {
    @Environment(\.openURL) private var openURL
    let systemImage: String
    let title: String
    let detail: String
    let link: URL?
    let linkTitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.weight(.medium))
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
                if let link {
                    Button(linkTitle) { openURL(link) }
                        .font(.subheadline)
                }
            }
        }
    }
}
