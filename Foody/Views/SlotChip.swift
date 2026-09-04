import SwiftUI

/// Een tijdslot. Tikken opent de reserveringspagina met datum, tijd en aantal voorgevuld.
struct SlotChip: View {
    @Environment(\.openURL) private var openURL
    let slot: Slot
    let url: URL?

    var body: some View {
        Button {
            if let url { openURL(url) }
        } label: {
            Text(slot.time)
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.accentColor.opacity(0.14), in: Capsule())
                .overlay(Capsule().strokeBorder(Color.accentColor.opacity(0.45), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(url == nil)
        .accessibilityLabel("Tijdslot \(slot.time), tot \(slot.maxCovers) personen")
        .accessibilityHint(url == nil ? "Geen reserveerlink bekend" : "Opent de reserveringspagina")
    }
}
