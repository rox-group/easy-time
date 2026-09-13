import Foundation
import SwiftUI
#if canImport(WidgetKit)
import WidgetKit
#endif

@MainActor
public final class CommuteViewModel: ObservableObject {
    @Published public var commute: SavedCommute
    @Published public var selectedDirection: CommuteDirection
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String? = nil
    @Published public var freshnessAt: Date? = nil
    @Published public var lastRefreshedAt: Date? = nil
    @Published public var scheduledReminderDepartureIds: Set<UUID> = []

    public let departuresService: DeparturesServiceProtocol
    public let storage: CommuteStorageProtocol
    public let reminderService: DepartureReminderServiceProtocol

    public init(
        commute: SavedCommute,
        initialDirection: CommuteDirection = .outbound,
        departuresService: DeparturesServiceProtocol = DeparturesAPIService(),
        storage: CommuteStorageProtocol = CommuteStorage.shared
        storage: CommuteStorageProtocol = CommuteStorage.shared,
        reminderService: DepartureReminderServiceProtocol = DepartureReminderService.shared
    ) {
        self.commute = commute
        self.selectedDirection = initialDirection
        self.departuresService = departuresService
        self.storage = storage
        self.reminderService = reminderService
    }

    public var currentLeg: CommuteLeg {
        commute.leg(for: selectedDirection)
    }

    public func selectDirection(_ direction: CommuteDirection) {
        guard direction != selectedDirection else { return }
        selectedDirection = direction
        Task {
            await fetchDeparturesForCurrentLeg()
        }
    }

    public func updateCommute(_ updatedCommute: SavedCommute) {
        self.commute = updatedCommute
        storage.saveCommute(updatedCommute)
        reloadWidgets()
        Task {
            await fetchDeparturesForCurrentLeg()
        }
    }

    public func refresh() async {
        await fetchDeparturesForCurrentLeg()
    }

    public func searchStops(query: String) async -> [TransitStop] {
        do {
            return try await departuresService.searchStops(query: query)
        } catch {
            return TransitStop.presetStops
        }
    }

    public func fetchDeparturesForCurrentLeg() async {
        let leg = commute.leg(for: selectedDirection)
        guard !leg.stopId.isEmpty else {
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let response = try await departuresService.fetchDepartures(
                stopId: leg.stopId,
                routeId: leg.routeFilter,
                direction: leg.directionId,
                platform: leg.platform,
                destination: leg.destination,
                limit: 10,
                timeWindowMinutes: 60
            )

            let mappedDepartures = response.departures.map { $0.toDeparture() }

            var updatedLeg = leg
            updatedLeg.departures = mappedDepartures

            var updatedDirections = commute.directions
            updatedDirections[selectedDirection] = updatedLeg

            commute.directions = updatedDirections
            freshnessAt = response.freshnessAt
            lastRefreshedAt = Date()
            isLoading = false

            storage.saveDepartures(mappedDepartures, for: selectedDirection)
            storage.saveCommute(commute)
            reloadWidgets()
            await syncScheduledReminders()
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }

    public func syncScheduledReminders() async {
        scheduledReminderDepartureIds = await reminderService.pendingReminderDepartureIds()
    }

    public func isReminderScheduled(for departure: Departure) -> Bool {
        scheduledReminderDepartureIds.contains(departure.id)
    }

    public func toggleReminder(for departure: Departure) async {
        if scheduledReminderDepartureIds.contains(departure.id) {
            await reminderService.cancelReminder(for: departure.id)
            scheduledReminderDepartureIds.remove(departure.id)
        } else {
            do {
                _ = try await reminderService.scheduleReminder(
                    for: departure,
                    walkingBufferMinutes: currentLeg.walkingBufferMinutes
                )
                scheduledReminderDepartureIds.insert(departure.id)
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func reloadWidgets() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
