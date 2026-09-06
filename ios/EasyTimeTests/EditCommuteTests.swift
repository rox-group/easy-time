import Foundation
import Testing
@testable import EasyTime

@MainActor
struct EditCommuteTests {
    @Test func updateCommuteChangesOriginAndDestination() {
        let original = SavedCommute.officeFixture
        let mockService = MockDeparturesService(
            responseResult: .failure(DeparturesServiceError.emptyStopId)
        )
        let viewModel = CommuteViewModel(commute: original, departuresService: mockService)

        let newOutbound = CommuteLeg(
            stopId: "9021014001002000",
            boardingStop: "Odenplan",
            destination: "Solna",
            walkingBufferMinutes: 7
        )
        let newReturn = CommuteLeg(
            stopId: "9021014001004000",
            boardingStop: "Solna",
            destination: "Odenplan",
            walkingBufferMinutes: 5
        )
        let updated = SavedCommute(
            id: original.id,
            name: "University",
            origin: "Odenplan",
            destination: "Solna",
            directions: [
                .outbound: newOutbound,
                .returnTrip: newReturn
            ]
        )

        viewModel.updateCommute(updated)

        #expect(viewModel.commute.name == "University")
        #expect(viewModel.commute.origin == "Odenplan")
        #expect(viewModel.commute.destination == "Solna")
        #expect(viewModel.currentLeg.boardingStop == "Odenplan")
        #expect(viewModel.currentLeg.destination == "Solna")
        #expect(viewModel.currentLeg.walkingBufferMinutes == 7)
    }
}

