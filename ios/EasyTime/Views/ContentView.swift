import SwiftUI

struct ContentView: View {
    let commute: SavedCommute
    @State private var selectedDirection: CommuteDirection = .outbound

    private var leg: CommuteLeg {
        commute.leg(for: selectedDirection)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Journey direction", selection: $selectedDirection) {
                        ForEach(CommuteDirection.allCases) { direction in
                            Text(direction.rawValue).tag(direction)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel("Journey direction")
                }

                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("From \(leg.boardingStop)")
                            .font(.title2.weight(.bold))
                        Text("Towards \(leg.destination)")
                            .foregroundStyle(.secondary)
                        Label("Leave \(leg.walkingBufferMinutes) minutes before departure", systemImage: "figure.walk")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section("Next departures") {
                    ForEach(leg.departures) { departure in
                        DepartureRow(departure: departure)
                    }
                }
            }
            .navigationTitle(commute.name)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Edit", systemImage: "slider.horizontal.3") {}
                        .accessibilityHint("Editing saved commutes will be added next.")
                }
            }
        }
    }
}

private struct DepartureRow: View {
    let departure: Departure

    var body: some View {
        HStack(spacing: 14) {
            Text(departure.route)
                .font(.title3.weight(.bold))
                .frame(minWidth: 38, minHeight: 38)
                .background(.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))

            VStack(alignment: .leading, spacing: 3) {
                Text(departure.destination)
                    .fontWeight(.semibold)
                Text("Platform \(departure.platform)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(departure.effectiveTime, style: .time)
                    .fontWeight(.semibold)
                if departure.isDelayed {
                    Text("Delayed")
                        .font(.caption)
                        .foregroundStyle(.orange)
                } else {
                    Text("On time")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ContentView(commute: .officeFixture)
}
