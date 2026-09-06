import Foundation

extension SavedCommute {
    public static var officeFixture: SavedCommute {
        let now = Date()
        let calendar = Calendar.current

        func departure(
            tripId: String,
            route: String,
            destination: String,
            minutesFromNow: Int,
            delayMinutes: Int? = nil,
            platform: String,
            status: DepartureStatus = .scheduled,
            stopId: String,
            stopName: String
        ) -> Departure {
            let scheduledAt = calendar.date(byAdding: .minute, value: minutesFromNow, to: now) ?? now
            let predictedAt = delayMinutes.map {
                calendar.date(byAdding: .minute, value: $0, to: scheduledAt) ?? scheduledAt
            }

            return Departure(
                id: UUID(),
                tripId: tripId,
                route: route,
                destination: destination,
                scheduledAt: scheduledAt,
                predictedAt: predictedAt,
                platform: platform,
                status: status,
                stopId: stopId,
                stopName: stopName,
                delayMinutes: delayMinutes,
                isRealtime: delayMinutes != nil
            )
        }

        let outbound = CommuteLeg(
            stopId: "9021014001234000",
            boardingStop: "Skanstull",
            destination: "T-Centralen",
            walkingBufferMinutes: 6,
            departures: [
                departure(
                    tripId: "t17-01",
                    route: "17",
                    destination: "Åkeshov",
                    minutesFromNow: 8,
                    platform: "2",
                    status: .onTime,
                    stopId: "9021014001234000",
                    stopName: "Skanstull"
                ),
                departure(
                    tripId: "t18-01",
                    route: "18",
                    destination: "Alvik",
                    minutesFromNow: 14,
                    delayMinutes: 3,
                    platform: "2",
                    status: .delayed,
                    stopId: "9021014001234000",
                    stopName: "Skanstull"
                ),
                departure(
                    tripId: "t19-01",
                    route: "19",
                    destination: "Hässelby strand",
                    minutesFromNow: 20,
                    platform: "2",
                    status: .scheduled,
                    stopId: "9021014001234000",
                    stopName: "Skanstull"
                )
            ]
        )

        let returnTrip = CommuteLeg(
            stopId: "9021014001001000",
            boardingStop: "T-Centralen",
            destination: "Skanstull",
            walkingBufferMinutes: 5,
            departures: [
                departure(
                    tripId: "t17-02",
                    route: "17",
                    destination: "Skarpnäck",
                    minutesFromNow: 6,
                    platform: "3",
                    status: .onTime,
                    stopId: "9021014001001000",
                    stopName: "T-Centralen"
                ),
                departure(
                    tripId: "t18-02",
                    route: "18",
                    destination: "Farsta strand",
                    minutesFromNow: 12,
                    platform: "3",
                    status: .onTime,
                    stopId: "9021014001001000",
                    stopName: "T-Centralen"
                ),
                departure(
                    tripId: "t19-02",
                    route: "19",
                    destination: "Hagsätra",
                    minutesFromNow: 18,
                    delayMinutes: 2,
                    platform: "3",
                    status: .delayed,
                    stopId: "9021014001001000",
                    stopName: "T-Centralen"
                )
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
