import Foundation
import UserNotifications

public enum DepartureReminderError: LocalizedError, Equatable, Sendable {
    case permissionDenied
    case departureInPast
    case notificationSchedulingFailed(String)

    public var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Notification permission was denied. Please enable notifications in Settings."
        case .departureInPast:
            return "This departure's leave time has already passed."
        case .notificationSchedulingFailed(let reason):
            return "Failed to schedule reminder: \(reason)"
        }
    }
}

public protocol UserNotificationCenterProtocol: Sendable {
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func authorizationStatus() async -> UNAuthorizationStatus
    func add(_ request: UNNotificationRequest) async throws
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
    func removeAllPendingNotificationRequests()
    func pendingNotificationRequests() async -> [UNNotificationRequest]
}

public final class SystemUserNotificationCenter: UserNotificationCenterProtocol, @unchecked Sendable {
    private let center: UNUserNotificationCenter

    public init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    public func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        try await center.requestAuthorization(options: options)
    }

    public func authorizationStatus() async -> UNAuthorizationStatus {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus
    }

    public func add(_ request: UNNotificationRequest) async throws {
        try await center.add(request)
    }

    public func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    public func removeAllPendingNotificationRequests() {
        center.removeAllPendingNotificationRequests()
    }

    public func pendingNotificationRequests() async -> [UNNotificationRequest] {
        await center.pendingNotificationRequests()
    }
}

public protocol DepartureReminderServiceProtocol: Sendable {
    func requestAuthorization() async throws -> Bool
    func isAuthorized() async -> Bool
    func scheduleReminder(for departure: Departure, walkingBufferMinutes: Int, referenceDate: Date) async throws -> String
    func cancelReminder(for departureId: UUID) async
    func cancelAllReminders() async
    func pendingReminderDepartureIds() async -> Set<UUID>
    func leaveTime(for departure: Departure, walkingBufferMinutes: Int) -> Date
}

extension DepartureReminderServiceProtocol {
    public func scheduleReminder(for departure: Departure, walkingBufferMinutes: Int) async throws -> String {
        try await scheduleReminder(for: departure, walkingBufferMinutes: walkingBufferMinutes, referenceDate: Date())
    }
}

public final class DepartureReminderService: DepartureReminderServiceProtocol, @unchecked Sendable {
    public static let shared = DepartureReminderService()
    public static let reminderPrefix = "departure-reminder-"

    private let notificationCenter: UserNotificationCenterProtocol

    public init(notificationCenter: UserNotificationCenterProtocol = SystemUserNotificationCenter()) {
        self.notificationCenter = notificationCenter
    }

    public func requestAuthorization() async throws -> Bool {
        try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
    }

    public func isAuthorized() async -> Bool {
        let status = await notificationCenter.authorizationStatus()
        return status == .authorized || status == .provisional || status == .ephemeral
    }

    public func leaveTime(for departure: Departure, walkingBufferMinutes: Int) -> Date {
        departure.effectiveTime.addingTimeInterval(-Double(walkingBufferMinutes * 60))
    }

    public func scheduleReminder(
        for departure: Departure,
        walkingBufferMinutes: Int,
        referenceDate: Date = Date()
    ) async throws -> String {
        let status = await notificationCenter.authorizationStatus()
        if status == .notDetermined {
            let granted = try await requestAuthorization()
            guard granted else {
                throw DepartureReminderError.permissionDenied
            }
        } else if status == .denied {
            throw DepartureReminderError.permissionDenied
        }

        let triggerDate = leaveTime(for: departure, walkingBufferMinutes: walkingBufferMinutes)
        let timeInterval = triggerDate.timeIntervalSince(referenceDate)

        guard timeInterval > 0 else {
            throw DepartureReminderError.departureInPast
        }

        let content = UNMutableNotificationContent()
        content.title = "Time to leave for line \(departure.route)"

        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        let departureTimeString = timeFormatter.string(from: departure.effectiveTime)

        let bufferText = walkingBufferMinutes > 0 ? " (\(walkingBufferMinutes) min walk)" : ""
        let platformText = departure.platform.isEmpty ? "" : " from platform \(departure.platform)"
        content.body = "Line \(departure.route) towards \(departure.destination) departs at \(departureTimeString)\(platformText)\(bufferText)."
        content.sound = .default
        content.userInfo = [
            "departureId": departure.id.uuidString,
            "tripId": departure.tripId,
            "route": departure.route,
            "destination": departure.destination,
            "platform": departure.platform
        ]

        let identifier = "\(Self.reminderPrefix)\(departure.id.uuidString)"
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        do {
            try await notificationCenter.add(request)
            return identifier
        } catch {
            throw DepartureReminderError.notificationSchedulingFailed(error.localizedDescription)
        }
    }

    public func cancelReminder(for departureId: UUID) async {
        let identifier = "\(Self.reminderPrefix)\(departureId.uuidString)"
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    public func cancelAllReminders() async {
        notificationCenter.removeAllPendingNotificationRequests()
    }

    public func pendingReminderDepartureIds() async -> Set<UUID> {
        let requests = await notificationCenter.pendingNotificationRequests()
        var departureIds = Set<UUID>()
        for request in requests {
            if request.identifier.hasPrefix(Self.reminderPrefix) {
                let uuidString = String(request.identifier.dropFirst(Self.reminderPrefix.count))
                if let uuid = UUID(uuidString: uuidString) {
                    departureIds.insert(uuid)
                }
            }
        }
        return departureIds
    }
}

