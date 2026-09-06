import Foundation

public struct TransitStop: Identifiable, Codable, Sendable, Hashable, Equatable {
    public let id: String
    public let name: String
    public let platform: String?
    public let parentStation: String?

    public init(
        id: String,
        name: String,
        platform: String? = nil,
        parentStation: String? = nil
    ) {
        self.id = id
        self.name = name
        self.platform = platform
        self.parentStation = parentStation
    }

    public var displayName: String {
        if let platform = platform, !platform.isEmpty {
            return "\(name) (Platform \(platform))"
        }
        return name
    }
}

public extension TransitStop {
    static let presetStops: [TransitStop] = [
        TransitStop(id: "9021014001234000", name: "Skanstull", platform: "2"),
        TransitStop(id: "9021014001001000", name: "T-Centralen", platform: "1"),
        TransitStop(id: "9021014001002000", name: "Odenplan", platform: "1"),
        TransitStop(id: "9021014001235000", name: "Slussen", platform: "1"),
        TransitStop(id: "9021014001003000", name: "Fridhemsplan", platform: "1"),
        TransitStop(id: "9021014001236000", name: "Gullmarsplan", platform: "1"),
        TransitStop(id: "9021014001237000", name: "Gamla Stan", platform: "1"),
        TransitStop(id: "9021014001004000", name: "Solna station", platform: "1"),
        TransitStop(id: "9021014001005000", name: "Kista", platform: "1"),
        TransitStop(id: "9021014001006000", name: "Alvik", platform: "1"),
        TransitStop(id: "9021014001234003", name: "Åkeshov", platform: "1"),
        TransitStop(id: "9021014001007000", name: "Farsta strand", platform: "1"),
        TransitStop(id: "9021014001234001", name: "Skarpnäck", platform: "1")
    ]
}

public struct APIStopItem: Decodable, Sendable {
    public let stopId: String
    public let stopName: String
    public let platformCode: String?
    public let parentStation: String?

    enum CodingKeys: String, CodingKey {
        case stopId = "stop_id"
        case stopName = "stop_name"
        case platformCode = "platform_code"
        case parentStation = "parent_station"
    }

    public func toTransitStop() -> TransitStop {
        TransitStop(
            id: stopId,
            name: stopName,
            platform: platformCode,
            parentStation: parentStation
        )
    }
}

public struct APIStopsResponse: Decodable, Sendable {
    public let query: String?
    public let count: Int?
    public let stops: [APIStopItem]

    enum CodingKeys: String, CodingKey {
        case query
        case count
        case stops
    }
}
