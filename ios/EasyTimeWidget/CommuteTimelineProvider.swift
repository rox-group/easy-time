import Foundation
import WidgetKit

public struct CommuteTimelineProvider: TimelineProvider, Sendable {
    public let storage: CommuteStorageProtocol
    public let departuresService: DeparturesServiceProtocol

    public init(
        storage: CommuteStorageProtocol = CommuteStorage.shared,
        departuresService: DeparturesServiceProtocol = DeparturesAPIService()
    ) {
        self.storage = storage
        self.departuresService = departuresService
    }

    public func placeholder(in context: Context) -> CommuteEntry {
        .placeholder
    }

    public func placeholder() -> CommuteEntry {
        .placeholder
    }

    public func getSnapshot(in context: Context, completion: @escaping @Sendable (CommuteEntry) -> Void) {
        let now = Date()
        let commute = storage.loadCommute()
        let direction = storage.activeDirection(at: now)
        let leg = commute.leg(for: direction)
        let departures = storage.loadDepartures(for: direction) ?? leg.departures

        let entry = CommuteEntry(
            date: now,
            direction: direction,
            origin: leg.boardingStop,
            destination: leg.destination,
            walkingBufferMinutes: leg.walkingBufferMinutes,
            departures: departures,
            freshnessAt: now,
            isPlaceholder: false
        )
        completion(entry)
    }

    public func getSnapshot(completion: @escaping @Sendable (CommuteEntry) -> Void) {
        let now = Date()
        let commute = storage.loadCommute()
        let direction = storage.activeDirection(at: now)
        let leg = commute.leg(for: direction)
        let departures = storage.loadDepartures(for: direction) ?? leg.departures

        let entry = CommuteEntry(
            date: now,
            direction: direction,
            origin: leg.boardingStop,
            destination: leg.destination,
            walkingBufferMinutes: leg.walkingBufferMinutes,
            departures: departures,
            freshnessAt: now,
            isPlaceholder: false
        )
        completion(entry)
    }

    public func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<CommuteEntry>) -> Void) {
        getTimeline(completion: completion)
    }

    public func getTimeline(completion: @escaping @Sendable (Timeline<CommuteEntry>) -> Void) {
        Task {
            let timeline = await fetchTimeline()
            completion(timeline)
        }
    }

    public func fetchTimeline() async -> Timeline<CommuteEntry> {
        let now = Date()
        let commute = storage.loadCommute()
        let direction = storage.activeDirection(at: now)
        let leg = commute.leg(for: direction)

        var fetchedDepartures: [Departure] = []
        var freshnessDate: Date? = nil

        if !leg.stopId.isEmpty {
            do {
                let response = try await departuresService.fetchDepartures(
                    stopId: leg.stopId,
                    routeId: leg.routeFilter,
                    direction: leg.directionId,
                    platform: leg.platform,
                    destination: leg.destination,
                    limit: 6,
                    timeWindowMinutes: 60
                )
                fetchedDepartures = response.departures.map { $0.toDeparture() }
                freshnessDate = response.freshnessAt
                storage.saveDepartures(fetchedDepartures, for: direction)
            } catch {
                fetchedDepartures = storage.loadDepartures(for: direction) ?? leg.departures
                freshnessDate = nil
            }
        } else {
            fetchedDepartures = storage.loadDepartures(for: direction) ?? leg.departures
        }

        var entries: [CommuteEntry] = []
        let initialEntry = CommuteEntry(
            date: now,
            direction: direction,
            origin: leg.boardingStop,
            destination: leg.destination,
            walkingBufferMinutes: leg.walkingBufferMinutes,
            departures: fetchedDepartures,
            freshnessAt: freshnessDate ?? now,
            isPlaceholder: false
        )
        entries.append(initialEntry)

        let nextReload = Calendar.current.date(byAdding: .minute, value: 5, to: now) ?? now.addingTimeInterval(300)
        return Timeline(entries: entries, policy: .after(nextReload))
    }
}
