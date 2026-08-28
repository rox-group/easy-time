import Foundation

extension SavedCommute {
    static var officeFixture: SavedCommute {
        let now = Date()
        let calendar = Calendar.current

        func departure(
            route: String,
            destination: String,
            minutesFromNow: Int,
            delayMinutes: Int? = nil,
            platform: String
        ) -> Departure {
            let scheduledAt = calendar.date(byAdding: .minute, value: minutesFromNow, to: now) ?? now
            let predictedAt = delayMinutes.map {
                calendar.date(byAdding: .minute, value: $0, to: scheduledAt) ?? scheduledAt
            }

            return Departure(
                id: UUID(),
                route: route,
                destination: destination,
                scheduledAt: scheduledAt,
                predictedAt: predictedAt,
                platform: platform
            )
        }

        let outbound = CommuteLeg(
            boardingStop: "Skanstull",
            destination: "T-Centralen",
            walkingBufferMinutes: 6,
            departures: [
                departure(route: "17", destination: "Åkeshov", minutesFromNow: 8, platform: "2"),
                departure(route: "18", destination: "Alvik", minutesFromNow: 14, delayMinutes: 3, platform: "2"),
                departure(route: "19", destination: "Hässelby strand", minutesFromNow: 20, platform: "2")
            ]
        )

        let returnTrip = CommuteLeg(
            boardingStop: "T-Centralen",
            destination: "Skanstull",
            walkingBufferMinutes: 5,
            departures: [
                departure(route: "17", destination: "Skarpnäck", minutesFromNow: 6, platform: "3"),
                departure(route: "18", destination: "Farsta strand", minutesFromNow: 12, platform: "3"),
                departure(route: "19", destination: "Hagsätra", minutesFromNow: 18, delayMinutes: 2, platform: "3")
            ]
        )

        return SavedCommute(
            id: UUID(),
            name: "Office",
            origin: "Home",
            destination: "Work",
            directions: [.outbound: outbound, .returnTrip: returnTrip]
        )
    }
}
