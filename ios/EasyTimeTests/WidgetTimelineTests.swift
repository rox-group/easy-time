import Testing
import Foundation
import WidgetKit
@testable import EasyTime

private final class WidgetMockDeparturesService: DeparturesServiceProtocol, @unchecked Sendable {
    var departuresToReturn: APIDeparturesResponse?
    var errorToThrow: Error?

    func fetchDepartures(
        stopId: String,
        routeId: String?,
        direction: String?,
        platform: String?,
        destination: String?,
        limit: Int?,
        timeWindowMinutes: Int?
    ) async throws -> APIDeparturesResponse {
        if let error = errorToThrow {
            throw error
        }
        if let resp = departuresToReturn {
            return resp
        }
        return APIDeparturesResponse(
            generatedAt: Date(),
            freshnessAt: Date(),
            stopId: stopId,
            departures: []
        )
    }

    func searchStops(query: String) async throws -> [TransitStop] {
        return []
    }
}

@Suite("Widget Timeline Tests")
struct WidgetTimelineTests {
    @Test("CommuteEntry correctly computes validDepartures and nextDeparture")
    func commuteEntryCalculations() {
        let now = Date()
        let departures = [
            Departure(
                route: "13",
                destination: "Ropsten",
                scheduledAt: now.addingTimeInterval(300), // in 5 min
                platform: "1"
            ),
            Departure(
                route: "13",
                destination: "Ropsten",
                scheduledAt: now.addingTimeInterval(900), // in 15 min
                platform: "1"
            )
        ]

        let entry = CommuteEntry(
            date: now,
            direction: .outbound,
            origin: "Skärholmen",
            destination: "Östermalmstorg",
            walkingBufferMinutes: 6,
            departures: departures,
            freshnessAt: now
        )

        #expect(entry.validDepartures.count == 2)
        #expect(entry.nextDeparture?.route == "13")
        #expect(entry.nextDeparture?.minutesUntilDeparture(from: now) == 5)
    }

    @Test("TimelineProvider placeholder returns valid entry")
    func timelineProviderPlaceholder() {
        let provider = CommuteTimelineProvider()
        let placeholder = provider.placeholder()
        #expect(placeholder.isPlaceholder == true)
        #expect(!placeholder.origin.isEmpty)
        #expect(!placeholder.destination.isEmpty)
    }

    @Test("TimelineProvider getSnapshot loads from storage")
    func timelineProviderSnapshot() async {
        let suiteName = "test.snapshot.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let storage = CommuteStorage(userDefaults: defaults)
        let mockService = WidgetMockDeparturesService()
        let provider = CommuteTimelineProvider(storage: storage, departuresService: mockService)

        await withCheckedContinuation { continuation in
            provider.getSnapshot { entry in
                #expect(entry.isPlaceholder == false)
                #expect(entry.origin == "Skanstull" || entry.origin == "T-Centralen")
                continuation.resume()
            }
        }
    }

    @Test("TimelineProvider getTimeline fetches from service")
    func timelineProviderTimelineFetch() async {
        let suiteName = "test.timeline.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let storage = CommuteStorage(userDefaults: defaults)
        let mockService = WidgetMockDeparturesService()

        let now = Date()
        mockService.departuresToReturn = APIDeparturesResponse(
            generatedAt: now,
            freshnessAt: now,
            stopId: "9021014001234000",
            departures: [
                APIDepartureItem(
                    route: "17",
                    destination: "Åkeshov",
                    scheduledAt: now.addingTimeInterval(420),
                    predictedAt: nil,
                    platform: "2",
                    status: .scheduled,
                    tripId: "t1",
                    stopId: "9021014001234000",
                    stopName: "Skanstull"
                )
            ]
        )

        let provider = CommuteTimelineProvider(storage: storage, departuresService: mockService)

        await withCheckedContinuation { continuation in
            provider.getTimeline { timeline in
                #expect(timeline.entries.count >= 1)
                let first = timeline.entries.first
                #expect(first?.departures.first?.route == "17")
                continuation.resume()
            }
        }
    }
}
