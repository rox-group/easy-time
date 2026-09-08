import SwiftUI
import WidgetKit

public struct EasyTimeWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    public var entry: CommuteEntry

    public init(entry: CommuteEntry) {
        self.entry = entry
    }

    public var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .accessoryRectangular:
            LockScreenRectangularView(entry: entry)
        case .accessoryInline:
            LockScreenInlineView(entry: entry)
        case .accessoryCircular:
            LockScreenCircularView(entry: entry)
        @unknown default:
            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - System Small Widget View

public struct SmallWidgetView: View {
    public let entry: CommuteEntry

    public init(entry: CommuteEntry) {
        self.entry = entry
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(entry.direction.rawValue)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Image(systemName: entry.direction == .outbound ? "briefcase.fill" : "house.fill")
                    .font(.caption2)
                    .foregroundStyle(.tint)
            }

            if let next = entry.nextDeparture {
                let mins = next.minutesUntilDeparture(from: entry.date)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(mins)")
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundStyle(mins <= entry.walkingBufferMinutes ? .orange : .primary)
                    Text("min")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 6) {
                    Text(next.route)
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red.opacity(0.85))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())

                    Text(next.destination)
                        .font(.caption.weight(.medium))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                HStack(spacing: 4) {
                    Image(systemName: "figure.walk")
                        .font(.caption2)
                    Text("\(entry.walkingBufferMinutes)m buffer")
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)
            } else {
                Spacer()
                Text("No departures")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - System Medium Widget View

public struct MediumWidgetView: View {
    public let entry: CommuteEntry

    public init(entry: CommuteEntry) {
        self.entry = entry
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: entry.direction == .outbound ? "briefcase.fill" : "house.fill")
                    .foregroundStyle(.tint)
                Text("\(entry.origin) → \(entry.destination)")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                Spacer()

                HStack(spacing: 3) {
                    Image(systemName: "figure.walk")
                    Text("\(entry.walkingBufferMinutes) min")
                }
                .font(.caption2.weight(.medium))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color(.secondarySystemBackground))
                .clipShape(Capsule())
            }

            Divider()

            if entry.validDepartures.isEmpty {
                Spacer()
                Text("No upcoming departures")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            } else {
                HStack(spacing: 12) {
                    ForEach(entry.validDepartures.prefix(3)) { dep in
                        DepartureColumnView(departure: dep, referenceDate: entry.date, walkingBuffer: entry.walkingBufferMinutes)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct DepartureColumnView: View {
    let departure: Departure
    let referenceDate: Date
    let walkingBuffer: Int

    var body: some View {
        let mins = departure.minutesUntilDeparture(from: referenceDate)
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text(departure.route)
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Color.red.opacity(0.85))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())

                if !departure.platform.isEmpty {
                    Text("Pl. \(departure.platform)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(mins)")
                    .font(.title3.weight(.bold).monospacedDigit())
                    .foregroundStyle(mins <= walkingBuffer ? .orange : .primary)
                Text("m")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Text(departure.destination)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Lock Screen Accessories

public struct LockScreenRectangularView: View {
    public let entry: CommuteEntry

    public init(entry: CommuteEntry) {
        self.entry = entry
    }

    public var body: some View {
        if let next = entry.nextDeparture {
            let mins = next.minutesUntilDeparture(from: entry.date)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "tram.fill")
                    Text("Line \(next.route) → \(next.destination)")
                        .font(.headline)
                        .lineLimit(1)
                }
                Text("Departs in \(mins) min (Walk: \(entry.walkingBufferMinutes)m)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else {
            Text("No departures")
                .font(.caption)
        }
    }
}

public struct LockScreenInlineView: View {
    public let entry: CommuteEntry

    public init(entry: CommuteEntry) {
        self.entry = entry
    }

    public var body: some View {
        if let next = entry.nextDeparture {
            let mins = next.minutesUntilDeparture(from: entry.date)
            Text("🚇 \(next.route) to \(next.destination) in \(mins)m")
        } else {
            Text("🚇 Easy Time")
        }
    }
}

public struct LockScreenCircularView: View {
    public let entry: CommuteEntry

    public init(entry: CommuteEntry) {
        self.entry = entry
    }

    public var body: some View {
        if let next = entry.nextDeparture {
            let mins = next.minutesUntilDeparture(from: entry.date)
            VStack(spacing: 0) {
                Text(next.route)
                    .font(.caption2.weight(.bold))
                Text("\(mins)m")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
            }
        } else {
            Image(systemName: "tram.fill")
        }
    }
}

