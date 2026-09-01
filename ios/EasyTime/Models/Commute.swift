import Foundation

enum CommuteDirection: String, CaseIterable, Identifiable {
    case outbound = "To work"
    case returnTrip = "Home"

    var id: Self { self }

    var accessibilityLabel: String {
        switch self {
        case .outbound:
            "Outbound journey"
        case .returnTrip:
            "Return journey"
        }
    }
}

struct SavedCommute: Identifiable {
    let id: UUID
    let name: String
    let origin: String
    let destination: String
    let directions: [CommuteDirection: CommuteLeg]

    func leg(for direction: CommuteDirection) -> CommuteLeg {
        guard let leg = directions[direction] else {
            preconditionFailure("Every saved commute must contain both directions.")
        }
        return leg
    }
}

struct CommuteLeg {
    let boardingStop: String
    let destination: String
    let walkingBufferMinutes: Int
    let departures: [Departure]
}

struct Departure: Identifiable {
    let id: UUID
    let route: String
    let destination: String
    let scheduledAt: Date
    let predictedAt: Date?
    let platform: String

    var effectiveTime: Date {
        predictedAt ?? scheduledAt
    }

    var isDelayed: Bool {
        guard let predictedAt else { return false }
        return predictedAt > scheduledAt
    }
}
