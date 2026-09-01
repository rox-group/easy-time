import Foundation
import Testing
@testable import EasyTime

struct CommuteTests {
    @Test func officeFixtureHasOutboundAndReturnLegs() {
        let commute = SavedCommute.officeFixture

        #expect(commute.leg(for: .outbound).boardingStop == "Skanstull")
        #expect(commute.leg(for: .returnTrip).boardingStop == "T-Centralen")
    }

    @Test func delayedDepartureUsesPredictedTime() {
        let scheduled = Date(timeIntervalSinceReferenceDate: 100)
        let predicted = Date(timeIntervalSinceReferenceDate: 220)
        let departure = Departure(
            id: UUID(),
            route: "18",
            destination: "Farsta strand",
            scheduledAt: scheduled,
            predictedAt: predicted,
            platform: "3"
        )

        #expect(departure.effectiveTime == predicted)
        #expect(departure.isDelayed)
    }
}
