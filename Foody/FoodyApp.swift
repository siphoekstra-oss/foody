import SwiftUI

@main
struct FoodyApp: App {
    @State private var store = AvailabilityStore(loader: BundleAvailabilityLoader(), query: .default())
    @State private var location = LocationService()

    var body: some Scene {
        WindowGroup {
            SearchView()
                .environment(store)
                .environment(location)
                .environment(\.locale, DutchFormat.locale)
        }
    }
}
