import Foundation
import Testing
@testable import EasyTime

struct MockDeparturesService: DeparturesServiceProtocol {
    var responseResult: Result<APIDeparturesResponse, Error>

    func fetchDepartures(
        stopId: String,
        routeId: String?,
        direction: String?,
        platform: String?,
        destination: String?,
        limit: Int?,
        timeWindowMinutes: Int?
    ) async throws -> APIDeparturesResponse {
        try responseResult.get()
    }
}

@MainActor
struct CommuteViewModelTests {
    @Test func fetchDeparturesSuccessfullyUpdatesCommuteLeg() async {
        let fixture = SavedCommute.officeFixture
        let departureItem = APIDepartureItem(
            route: "17",
            destination: "Åkeshov",
            scheduledAt: Date(),
            predictedAt: Date().addingTimeInterval(180),
            platform: "2",
            status: .delayed,
            tripId: "t-17",
            stopId: "9021014001234000",
            stopName: "Skanstull",
            delayMinutes: 3,
            isRealtime: true
        )
        let mockResponse = APIDeparturesResponse(
            generatedAt: Date(),
            freshnessAt: Date(),
            stopId: "9021014001234000",
            departures: [departureItem]
        )

        let mockService = MockDeparturesService(responseResult: .success(mockResponse))
        let viewModel = CommuteViewModel(commute: fixture, departuresService: mockService)

        await viewModel.fetchDeparturesForCurrentLeg()

        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.currentLeg.departures.count == 1)
        #expect(viewModel.currentLeg.departures.first?.route == "17")
        #expect(viewModel.currentLeg.departures.first?.status == .delayed)
        #expect(viewModel.currentLeg.departures.first?.isDelayed == true)
        #expect(viewModel.freshnessAt != nil)
    }

    @Test func fetchDeparturesHandlesErrorGracefully() async {
        let fixture = SavedCommute.officeFixture
        let mockService = MockDeparturesService(
            responseResult: .failure(DeparturesServiceError.networkError("Offline"))
        )
        let viewModel = CommuteViewModel(commute: fixture, departuresService: mockService)

        await viewModel.fetchDeparturesForCurrentLeg()

        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage?.contains("Offline") == true)
    }

    @Test func selectingDirectionChangesLeg() {
        let fixture = SavedCommute.officeFixture
        let mockService = MockDeparturesService(
            responseResult: .failure(DeparturesServiceError.emptyStopId)
        )
        let viewModel = CommuteViewModel(
            commute: fixture,
            initialDirection: .outbound,
            departuresService: mockService
        )

        #expect(viewModel.selectedDirection == .outbound)
        #expect(viewModel.currentLeg.boardingStop == "Skanstull")

        viewModel.selectDirection(.returnTrip)

        #expect(viewModel.selectedDirection == .returnTrip)
        #expect(viewModel.currentLeg.boardingStop == "T-Centralen")
    }
}

