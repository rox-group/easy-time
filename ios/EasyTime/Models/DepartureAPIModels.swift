import Foundation

public struct APIDeparturesResponse: Decodable, Sendable {
    public let generatedAt: Date
    public let freshnessAt: Date?
    public let stopId: String
    public let departures: [APIDepartureItem]

    enum CodingKeys: String, CodingKey {
        case generatedAt = "generated_at"
        case freshnessAt = "freshness_at"
        case stopId = "stop_id"
        case departures
    }
}

public struct APIDepartureItem: Decodable, Identifiable, Sendable {
    public var id: String { tripId }
    public let route: String
    public let destination: String
    public let scheduledAt: Date
    public let predictedAt: Date?
    public let platform: String?
    public let status: DepartureStatus
    public let tripId: String
    public let stopId: String
    public let stopName: String
    public let delayMinutes: Int?
    public let isRealtime: Bool

    enum CodingKeys: String, CodingKey {
        case route
        case destination
        case scheduledAt = "scheduled_at"
        case predictedAt = "predicted_at"
        case platform
        case status
        case tripId = "trip_id"
        case stopId = "stop_id"
        case stopName = "stop_name"
        case delayMinutes = "delay_minutes"
        case isRealtime = "is_realtime"
    }

    public func toDeparture() -> Departure {
        Departure(
            id: UUID(),
            tripId: tripId,
            route: route,
            destination: destination,
            scheduledAt: scheduledAt,
            predictedAt: predictedAt,
            platform: platform ?? "—",
            status: status,
            stopId: stopId,
            stopName: stopName,
            delayMinutes: delayMinutes,
            isRealtime: isRealtime
        )
    }
}

