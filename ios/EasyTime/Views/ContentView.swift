import SwiftUI

public struct ContentView: View {
    @StateObject private var viewModel: CommuteViewModel

    public init(commute: SavedCommute, departuresService: DeparturesServiceProtocol = DeparturesAPIService()) {
        _viewModel = StateObject(
            wrappedValue: CommuteViewModel(
                commute: commute,
                departuresService: departuresService
            )
        )
    }

    public init(viewModel: CommuteViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    private var leg: CommuteLeg {
        viewModel.currentLeg
    }

    public var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Journey direction", selection: Binding(
                        get: { viewModel.selectedDirection },
                        set: { viewModel.selectDirection($0) }
                    )) {
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
                        Label(
                            "Leave \(leg.walkingBufferMinutes) minutes before departure",
                            systemImage: "figure.walk"
                        )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                if let errorMessage = viewModel.errorMessage {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Retry") {
                                Task {
                                    await viewModel.refresh()
                                }
                            }
                            .font(.footnote.weight(.semibold))
                        }
                    }
                }

                Section("Next departures") {
                    if viewModel.isLoading && leg.departures.isEmpty {
                        HStack {
                            Spacer()
                            ProgressView("Loading departures...")
                                .padding(.vertical, 12)
                            Spacer()
                        }
                    } else if leg.departures.isEmpty {
                        Text("No upcoming departures found.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 8)
                    } else {
                        ForEach(leg.departures) { departure in
                            DepartureRow(departure: departure)
                        }
                    }
                }

                if let freshness = viewModel.freshnessAt ?? viewModel.lastRefreshedAt {
                    Section {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("Updated \(freshness, style: .time)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if viewModel.freshnessAt != nil {
                                Spacer()
                                Text("Live GTFS-RT")
                                    .font(.caption2.weight(.medium))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.green.opacity(0.15), in: Capsule())
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                }
            }
            .navigationTitle(viewModel.commute.name)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Edit", systemImage: "slider.horizontal.3") {}
                        .accessibilityHint("Editing saved commutes will be added next.")
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
            .task {
                await viewModel.fetchDeparturesForCurrentLeg()
            }
        }
    }
}

public struct DepartureRow: View {
    public let departure: Departure

    public init(departure: Departure) {
        self.departure = departure
    }

    public var body: some View {
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
                statusBadge
            }
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch departure.status {
        case .cancelled:
            Text("Cancelled")
                .font(.caption.weight(.medium))
                .foregroundStyle(.red)
        case .delayed:
            if let delay = departure.delayMinutes, delay > 0 {
                Text("+\(delay) min")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.orange)
            } else {
                Text("Delayed")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.orange)
            }
        case .early:
            if let delay = departure.delayMinutes, delay < 0 {
                Text("\(delay) min")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.blue)
            } else {
                Text("Early")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.blue)
            }
        case .onTime:
            Text("On time")
                .font(.caption)
                .foregroundStyle(.green)
        case .scheduled:
            Text("Scheduled")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    ContentView(commute: .officeFixture)
}
