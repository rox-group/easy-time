import Foundation

public enum CommuteDirection: String, CaseIterable, Identifiable, Sendable {
    case outbound = "To work"
    case returnTrip = "Home"

    public var id: Self { self }

    public var accessibilityLabel: String {
        switch self {
        case .outbound:
            "Outbound journey"
        case .returnTrip:
            "Return journey"
        }
    }
}

public enum DepartureStatus: String, Codable, Sendable, CaseIterable {
    case scheduled = "scheduled"
    case onTime = "on_time"
    case delayed = "delayed"
    case early = "early"
    case cancelled = "cancelled"

    public var displayName: String {
        switch self {
        case .scheduled:
            return "Scheduled"
        case .onTime:
            return "On time"
        case .delayed:
            return "Delayed"
        case .early:
            return "Early"
        case .cancelled:
            return "Cancelled"
        }
    }
}

public struct SavedCommute: Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let origin: String
    public let destination: String
    public var directions: [CommuteDirection: CommuteLeg]

    public init(
        id: UUID = UUID(),
        name: String,
        origin: String,
        destination: String,
        directions: [CommuteDirection: CommuteLeg]
    ) {
        self.id = id
        self.name = name
        self.origin = origin
        self.destination = destination
        self.directions = directions
    }

    public func leg(for direction: CommuteDirection) -> CommuteLeg {
        guard let leg = directions[direction] else {
            preconditionFailure("Every saved commute must contain both directions.")
        }
        return leg
    }
}

public struct CommuteLeg: Sendable, Equatable {
    public let stopId: String
    public let boardingStop: String
    public let destination: String
    public let walkingBufferMinutes: Int
    public let routeFilter: String?
    public let directionId: String?
    public let platform: String?
    public var departures: [Departure]

    public init(
        stopId: String = "",
        boardingStop: String,
        destination: String,
        walkingBufferMinutes: Int,
        routeFilter: String? = nil,
        directionId: String? = nil,
        platform: String? = nil,
        departures: [Departure] = []
    ) {
        self.stopId = stopId
        self.boardingStop = boardingStop
        self.destination = destination
        self.walkingBufferMinutes = walkingBufferMinutes
        self.routeFilter = routeFilter
        self.directionId = directionId
        self.platform = platform
        self.departures = departures
    }
}

public struct Departure: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let tripId: String
    public let route: String
    public let destination: String
    public let scheduledAt: Date
    public let predictedAt: Date?
    public let platform: String
    public let status: DepartureStatus
    public let stopId: String
    public let stopName: String
    public let delayMinutes: Int?
    public let isRealtime: Bool

    public init(
        id: UUID = UUID(),
        tripId: String = "",
        route: String,
        destination: String,
        scheduledAt: Date,
        predictedAt: Date? = nil,
        platform: String,
        status: DepartureStatus = .scheduled,
        stopId: String = "",
        stopName: String = "",
        delayMinutes: Int? = nil,
        isRealtime: Bool = false
    ) {
        self.id = id
        self.tripId = tripId
        self.route = route
        self.destination = destination
        self.scheduledAt = scheduledAt
        self.predictedAt = predictedAt
        self.platform = platform
        self.status = status
        self.stopId = stopId
        self.stopName = stopName
        self.delayMinutes = delayMinutes
        self.isRealtime = isRealtime
    }

    public var effectiveTime: Date {
        predictedAt ?? scheduledAt
    }

    public var isDelayed: Bool {
        status == .delayed || (delayMinutes ?? 0) > 0 || (predictedAt.map { $0 > scheduledAt } ?? false)
    }
}
