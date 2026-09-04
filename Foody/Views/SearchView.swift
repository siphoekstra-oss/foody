import SwiftUI

struct RestaurantRoute: Hashable {
    let id: String
}

/// Het startscherm: sticky zoekbediening bovenaan, daaronder de resultaten.
struct SearchView: View {
    @Environment(AvailabilityStore.self) private var store
    @Environment(LocationService.self) private var location

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                SearchControls()
                Divider()
                ResultsList()
            }
            .navigationTitle("Foody")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { SortMenu() }
            }
            .navigationDestination(for: RestaurantRoute.self) { route in
                RestaurantDetailView(restaurantID: route.id)
            }
        }
        .task {
            await store.load()
            location.requestIfNeeded()
        }
        .onChange(of: location.coordinate, initial: true) {
            store.userLocation = location.effectiveCoordinate
        }
    }
}

/// Datum, middag/avond en gezelschapsgrootte. Elke wijziging ververst de lijst via de store.
struct SearchControls: View {
    @Environment(AvailabilityStore.self) private var store

    private var selectableDays: ClosedRange<Date> {
        let today = AmsterdamTime.calendar.startOfDay(for: .now)
        let last = AmsterdamTime.calendar.date(byAdding: .day, value: 60, to: today) ?? today
        return today...last
    }

    var body: some View {
        @Bindable var store = store
        VStack(spacing: 12) {
            HStack {
                DatePicker("Datum", selection: $store.query.day, in: selectableDays, displayedComponents: .date)
                    .labelsHidden()
                    .environment(\.timeZone, AmsterdamTime.timeZone)
                Spacer()
                Stepper(value: $store.query.covers, in: 1...8) {
                    Label("\(store.query.covers)", systemImage: "person.2")
                        .monospacedDigit()
                        .accessibilityLabel("\(store.query.covers) personen")
                }
                .fixedSize()
            }
            Picker("Dagdeel", selection: $store.query.service) {
                Text("Middag").tag(Service.lunch)
                Text("Avond").tag(Service.dinner)
            }
            .pickerStyle(.segmented)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(.bar)
    }
}

struct SortMenu: View {
    @Environment(AvailabilityStore.self) private var store

    var body: some View {
        @Bindable var store = store
        Menu {
            Picker("Sorteren", selection: $store.sort) {
                Label("Afstand", systemImage: "location").tag(ResultSort.distance)
                Label("Meeste beschikbaarheid", systemImage: "calendar").tag(ResultSort.availability)
            }
        } label: {
            Label("Sorteren", systemImage: "arrow.up.arrow.down")
        }
    }
}
