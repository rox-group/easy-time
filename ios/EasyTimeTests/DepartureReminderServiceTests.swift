import Foundation
import Testing
import UserNotifications
@testable import EasyTime

final class MockUserNotificationCenter: UserNotificationCenterProtocol, @unchecked Sendable {
    var authStatus: UNAuthorizationStatus = .authorized
    var requestAuthResult: Bool = true
    var authRequested: Bool = false
    var addedRequests: [UNNotificationRequest] = []
    var removedIdentifiers: [String] = []
    var allRemoved: Bool = false

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        authRequested = true
        return requestAuthResult
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        return authStatus
    }

    func add(_ request: UNNotificationRequest) async throws {
        addedRequests.append(request)
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        removedIdentifiers.append(contentsOf: identifiers)
        addedRequests.removeAll { identifiers.contains($0.identifier) }
    }

    func removeAllPendingNotificationRequests() {
        allRemoved = true
        addedRequests.removeAll()
    }

    func pendingNotificationRequests() async -> [UNNotificationRequest] {
        return addedRequests
    }
}

struct DepartureReminderServiceTests {
    @Test func testLeaveTimeCalculation() {
        let service = DepartureReminderService()
        let departureTime = Date(timeIntervalSince1970: 1_700_000_000)
        let departure = Departure(
            route: "17",
            destination: "Åkeshov",
            scheduledAt: departureTime,
            platform: "2"
        )

        let leaveTime = service.leaveTime(for: departure, walkingBufferMinutes: 7)
        let expectedLeaveTime = departureTime.addingTimeInterval(-7 * 60)

        #expect(leaveTime == expectedLeaveTime)
    }

    @Test func testScheduleReminderSuccess() async throws {
        let mockCenter = MockUserNotificationCenter()
        let service = DepartureReminderService(notificationCenter: mockCenter)

        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let departureTime = now.addingTimeInterval(15 * 60) // in 15 minutes
        let departure = Departure(
            tripId: "trip-123",
            route: "17",
            destination: "Åkeshov",
            scheduledAt: departureTime,
            platform: "2"
        )

        let identifier = try await service.scheduleReminder(
            for: departure,
            walkingBufferMinutes: 5,
            referenceDate: now
        )

        #expect(identifier == "departure-reminder-\(departure.id.uuidString)")
        #expect(mockCenter.addedRequests.count == 1)

        let request = mockCenter.addedRequests.first
        #expect(request?.identifier == identifier)
        #expect(request?.content.title.contains("17") == true)
        #expect(request?.content.body.contains("Åkeshov") == true)
        #expect(request?.content.body.contains("5 min walk") == true)
        #expect(request?.content.userInfo["tripId"] as? String == "trip-123")
    }

    @Test func testScheduleReminderThrowsIfInPast() async {
        let mockCenter = MockUserNotificationCenter()
        let service = DepartureReminderService(notificationCenter: mockCenter)

        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let departureTime = now.addingTimeInterval(3 * 60) // in 3 mins, but walking buffer is 5 mins (leave time was 2 mins ago)
        let departure = Departure(
            route: "17",
            destination: "Åkeshov",
            scheduledAt: departureTime,
            platform: "2"
        )

        await #expect(throws: DepartureReminderError.departureInPast) {
            try await service.scheduleReminder(
                for: departure,
                walkingBufferMinutes: 5,
                referenceDate: now
            )
        }
        #expect(mockCenter.addedRequests.isEmpty)
    }

    @Test func testScheduleReminderRequestsAuthWhenNotDetermined() async throws {
        let mockCenter = MockUserNotificationCenter()
        mockCenter.authStatus = .notDetermined
        mockCenter.requestAuthResult = true
        let service = DepartureReminderService(notificationCenter: mockCenter)

        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let departureTime = now.addingTimeInterval(20 * 60)
        let departure = Departure(
            route: "17",
            destination: "Åkeshov",
            scheduledAt: departureTime,
            platform: "2"
        )

        _ = try await service.scheduleReminder(
            for: departure,
            walkingBufferMinutes: 5,
            referenceDate: now
        )

        #expect(mockCenter.authRequested == true)
        #expect(mockCenter.addedRequests.count == 1)
    }

    @Test func testScheduleReminderDeniedPermissionThrows() async {
        let mockCenter = MockUserNotificationCenter()
        mockCenter.authStatus = .denied
        let service = DepartureReminderService(notificationCenter: mockCenter)

        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let departureTime = now.addingTimeInterval(20 * 60)
        let departure = Departure(
            route: "17",
            destination: "Åkeshov",
            scheduledAt: departureTime,
            platform: "2"
        )

        await #expect(throws: DepartureReminderError.permissionDenied) {
            try await service.scheduleReminder(
                for: departure,
                walkingBufferMinutes: 5,
                referenceDate: now
            )
        }
    }

    @Test func testCancelReminder() async {
        let mockCenter = MockUserNotificationCenter()
        let service = DepartureReminderService(notificationCenter: mockCenter)
        let departureId = UUID()

        await service.cancelReminder(for: departureId)

        #expect(mockCenter.removedIdentifiers == ["departure-reminder-\(departureId.uuidString)"])
    }

    @Test func testCancelAllReminders() async {
        let mockCenter = MockUserNotificationCenter()
        let service = DepartureReminderService(notificationCenter: mockCenter)

        await service.cancelAllReminders()

        #expect(mockCenter.allRemoved == true)
    }

    @Test func testPendingReminderDepartureIds() async throws {
        let mockCenter = MockUserNotificationCenter()
        let service = DepartureReminderService(notificationCenter: mockCenter)

        let id1 = UUID()
        let id2 = UUID()

        let content = UNMutableNotificationContent()
        let req1 = UNNotificationRequest(
            identifier: "departure-reminder-\(id1.uuidString)",
            content: content,
            trigger: nil
        )
        let req2 = UNNotificationRequest(
            identifier: "departure-reminder-\(id2.uuidString)",
            content: content,
            trigger: nil
        )
        let reqOther = UNNotificationRequest(
            identifier: "other-notification-123",
            content: content,
            trigger: nil
        )

        try await mockCenter.add(req1)
        try await mockCenter.add(req2)
        try await mockCenter.add(reqOther)

        let pendingIds = await service.pendingReminderDepartureIds()

        #expect(pendingIds.count == 2)
        #expect(pendingIds.contains(id1))
        #expect(pendingIds.contains(id2))
    }
}

