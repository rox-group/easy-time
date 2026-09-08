import Testing
import Foundation
@testable import EasyTime

@Suite("CommuteStorage Tests")
struct CommuteStorageTests {
    private func createIsolatedStorage() -> (CommuteStorage, UserDefaults) {
        let suiteName = "test.easytime.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let storage = CommuteStorage(userDefaults: defaults)
        return (storage, defaults)
    }

    @Test("Default load returns office fixture when storage is empty")
    func loadEmptyReturnsFixture() {
        let (storage, defaults) = createIsolatedStorage()
        defer { defaults.removePersistentDomain(forName: defaults.description) }

        let commute = storage.loadCommute()
        #expect(commute.name == "Office")
        #expect(commute.directions[.outbound] != nil)
        #expect(commute.directions[.returnTrip] != nil)
    }

    @Test("Save and load commute persists across storage instances")
    func saveAndLoadCommute() {
        let suiteName = "test.easytime.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let storage1 = CommuteStorage(userDefaults: defaults)

        let customCommute = SavedCommute(
            name: "My Custom Route",
            origin: "Skärholmen",
            destination: "Östermalmstorg",
            directions: [
                .outbound: CommuteLeg(
                    stopId: "9021014001239000",
                    boardingStop: "Skärholmen",
                    destination: "Östermalmstorg",
                    walkingBufferMinutes: 7,
                    departures: []
                ),
                .returnTrip: CommuteLeg(
                    stopId: "9021014001238000",
                    boardingStop: "Östermalmstorg",
                    destination: "Skärholmen",
                    walkingBufferMinutes: 5,
                    departures: []
                )
            ]
        )

        storage1.saveCommute(customCommute)

        let storage2 = CommuteStorage(userDefaults: defaults)
        let loaded = storage2.loadCommute()

        #expect(loaded.name == "My Custom Route")
        #expect(loaded.origin == "Skärholmen")
        #expect(loaded.destination == "Östermalmstorg")
        #expect(loaded.leg(for: .outbound).walkingBufferMinutes == 7)
        #expect(loaded.leg(for: .returnTrip).walkingBufferMinutes == 5)
    }

    @Test("Save and load cached departures")
    func saveAndLoadDepartures() {
        let (storage, _) = createIsolatedStorage()
        let now = Date()

        let deps = [
            Departure(
                route: "13",
                destination: "Ropsten",
                scheduledAt: now.addingTimeInterval(300),
                platform: "1"
            ),
            Departure(
                route: "13",
                destination: "Ropsten",
                scheduledAt: now.addingTimeInterval(900),
                platform: "1"
            )
        ]

        storage.saveDepartures(deps, for: .outbound)
        let loaded = storage.loadDepartures(for: .outbound)

        #expect(loaded != nil)
        #expect(loaded?.count == 2)
        #expect(loaded?.first?.route == "13")
        #expect(loaded?.first?.destination == "Ropsten")
    }

    @Test("Active direction switches between morning and afternoon")
    func activeDirectionTimeOfDay() {
        let (storage, _) = createIsolatedStorage()
        let calendar = Calendar.current

        // 08:30 AM -> Outbound / To work
        var morningComponents = DateComponents()
        morningComponents.year = 2026
        morningComponents.month = 9
        morningComponents.day = 8
        morningComponents.hour = 8
        morningComponents.minute = 30
        let morningDate = calendar.date(from: morningComponents)!

        #expect(storage.activeDirection(at: morningDate) == .outbound)

        // 17:30 PM -> Return / Home
        var eveningComponents = DateComponents()
        eveningComponents.year = 2026
        eveningComponents.month = 9
        eveningComponents.day = 8
        eveningComponents.hour = 17
        eveningComponents.minute = 30
        let eveningDate = calendar.date(from: eveningComponents)!

        #expect(storage.activeDirection(at: eveningDate) == .returnTrip)
    }
}

