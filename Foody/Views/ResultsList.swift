import SwiftUI

struct ResultsList: View {
    @Environment(AvailabilityStore.self) private var store

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                DataStatusBar()
                if let message = store.loadError {
                    ErrorCard(message: message)
                } else if store.isLoading && store.document == nil {
                    ProgressView("Beschikbaarheid laden…")
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                } else if store.document != nil && store.results.isEmpty {
                    ContentUnavailableView("Nog geen restaurants", systemImage: "fork.knife",
                                           description: Text("De lijst is leeg. Vul crawler/restaurants.json aan."))
                }
                ForEach(store.results) { result in
                    RestaurantCard(result: result)
                }
            }
            .padding()
        }
        .refreshable { await store.load() }
        .background(Color(.systemGroupedBackground))
    }
}

/// Altijd zichtbaar boven de lijst: laatste verversing, herkomst bij een verversfout, locatie-fallback.
struct DataStatusBar: View {
    @Environment(AvailabilityStore.self) private var store
    @Environment(LocationService.self) private var location

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let document = store.document {
                freshnessLine(generatedAt: document.generatedAt)
            }
            if let refreshError = store.refreshError {
                Label("\(refreshError). Je ziet \(store.origin == .cache ? "de laatst opgehaalde" : "de meegeleverde") gegevens.",
                      systemImage: "wifi.exclamationmark")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            if location.isUsingFallback {
                Label(location.isDenied ? "Locatie geweigerd, afstand vanaf \(LocationService.fallbackLabel)"
                                        : "Afstand vanaf \(LocationService.fallbackLabel)",
                      systemImage: "location.slash")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func freshnessLine(generatedAt: Date) -> some View {
        if store.isStale() {
            Label("Mogelijk verouderd, bijgewerkt \(DutchFormat.time(generatedAt))", systemImage: "clock.badge.exclamationmark")
                .font(.caption)
                .foregroundStyle(.orange)
        } else {
            Label("Bijgewerkt \(DutchFormat.time(generatedAt))", systemImage: "clock")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct ErrorCard: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "exclamationmark.triangle")
            .font(.subheadline)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
