import Foundation

public protocol CommuteStorageProtocol: Sendable {
    func saveCommute(_ commute: SavedCommute)
    func loadCommute() -> SavedCommute
    func saveDepartures(_ departures: [Departure], for direction: CommuteDirection)
    func loadDepartures(for direction: CommuteDirection) -> [Departure]?
    func activeDirection(at date: Date) -> CommuteDirection
}

public final class CommuteStorage: CommuteStorageProtocol, @unchecked Sendable {
    public static let shared = CommuteStorage()
    public static let appGroupIdentifier = "group.com.rox.easytime"

    private let userDefaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private enum Keys {
        static let savedCommute = "easytime_saved_commute"
        static func departures(for direction: CommuteDirection) -> String {
            "easytime_cached_departures_\(direction.rawValue)"
        }
    }

    public init(userDefaults: UserDefaults = UserDefaults(suiteName: CommuteStorage.appGroupIdentifier) ?? .standard) {
        self.userDefaults = userDefaults
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder.dateDecodingStrategy = .iso8601
    }

    public func saveCommute(_ commute: SavedCommute) {
        if let data = try? encoder.encode(commute) {
            userDefaults.set(data, forKey: Keys.savedCommute)
        }
    }

    public func loadCommute() -> SavedCommute {
        guard let data = userDefaults.data(forKey: Keys.savedCommute),
              let commute = try? decoder.decode(SavedCommute.self, from: data) else {
            return .officeFixture
        }
        return commute
    }

    public func saveDepartures(_ departures: [Departure], for direction: CommuteDirection) {
        if let data = try? encoder.encode(departures) {
            userDefaults.set(data, forKey: Keys.departures(for: direction))
        }
    }

    public func loadDepartures(for direction: CommuteDirection) -> [Departure]? {
        guard let data = userDefaults.data(forKey: Keys.departures(for: direction)),
              let departures = try? decoder.decode([Departure].self, from: data) else {
            return nil
        }
        return departures
    }

    public func activeDirection(at date: Date = Date()) -> CommuteDirection {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        // Morning to midday (04:00 to 12:59): Outbound / To work
        // Afternoon and night (13:00 to 03:59): Return / Home
        if hour >= 4 && hour < 13 {
            return .outbound
        } else {
            return .returnTrip
        }
    }
}

