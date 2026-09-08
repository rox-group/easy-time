import Foundation
import WidgetKit

public struct CommuteEntry: TimelineEntry, Sendable {
    public let date: Date
    public let direction: CommuteDirection
    public let origin: String
    public let destination: String
    public let walkingBufferMinutes: Int
    public let departures: [Departure]
    public let freshnessAt: Date?
    public let isPlaceholder: Bool

    public init(
        date: Date = Date(),
        direction: CommuteDirection = .outbound,
        origin: String,
        destination: String,
        walkingBufferMinutes: Int = 5,
        departures: [Departure] = [],
        freshnessAt: Date? = nil,
        isPlaceholder: Bool = false
    ) {
        self.date = date
        self.direction = direction
        self.origin = origin
        self.destination = destination
        self.walkingBufferMinutes = walkingBufferMinutes
        self.departures = departures
        self.freshnessAt = freshnessAt
        self.isPlaceholder = isPlaceholder
    }

    public var validDepartures: [Departure] {
        departures.filter { $0.effectiveTime >= date.addingTimeInterval(-60) }
    }

    public var nextDeparture: Departure? {
        validDepartures.first
    }

    public static var placeholder: CommuteEntry {
        let sampleCommute = SavedCommute.officeFixture
        let leg = sampleCommute.leg(for: .outbound)
        return CommuteEntry(
            date: Date(),
            direction: .outbound,
            origin: leg.boardingStop,
            destination: leg.destination,
            walkingBufferMinutes: leg.walkingBufferMinutes,
            departures: leg.departures,
            freshnessAt: Date(),
            isPlaceholder: true
        )
    }
}

