import Foundation
import SwiftUI

@MainActor
public final class CommuteViewModel: ObservableObject {
    @Published public var commute: SavedCommute
    @Published public var selectedDirection: CommuteDirection
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String? = nil
    @Published public var freshnessAt: Date? = nil
    @Published public var lastRefreshedAt: Date? = nil

    private let departuresService: DeparturesServiceProtocol

    public init(
        commute: SavedCommute,
        initialDirection: CommuteDirection = .outbound,
        departuresService: DeparturesServiceProtocol = DeparturesAPIService()
    ) {
        self.commute = commute
        self.selectedDirection = initialDirection
        self.departuresService = departuresService
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

    public func refresh() async {
        await fetchDeparturesForCurrentLeg()
    }

    public func fetchDeparturesForCurrentLeg() async {
        let leg = commute.leg(for: selectedDirection)
        guard !leg.stopId.isEmpty else {
            // If stopId is empty (e.g. pure offline fixture mode), do not attempt API call
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
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }
}

