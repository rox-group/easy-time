import Foundation
import Testing
@testable import EasyTime

struct StopSearchTests {
    @Test func transitStopDisplayNameIncludesPlatform() {
        let stopWithPlatform = TransitStop(id: "1", name: "Skanstull", platform: "2")
        #expect(stopWithPlatform.displayName == "Skanstull (Platform 2)")

        let stopWithoutPlatform = TransitStop(id: "2", name: "Odenplan")
        #expect(stopWithoutPlatform.displayName == "Odenplan")
    }

    @Test func presetStopsIncludeMajorHubs() {
        let names = TransitStop.presetStops.map { $0.name }
        #expect(names.contains("T-Centralen"))
        #expect(names.contains("Skanstull"))
        #expect(names.contains("Odenplan"))
        #expect(names.contains("Slussen"))
    }

    @Test func searchStopsParsesAPIResponse() async throws {
        let json = """
        {
            "query": "Oden",
            "count": 1,
            "stops": [
                {
                    "stop_id": "9021014001002000",
                    "stop_name": "Odenplan",
                    "platform_code": "1",
                    "parent_station": null
                }
            ]
        }
        """.data(using: .utf8)!

        MockURLProtocol.requestHandler = { request in
            #expect(request.url?.path.contains("stops") == true)
            #expect(request.url?.query?.contains("query=Oden") == true)
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, json)
        }

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        let service = DeparturesAPIService(session: session)

        let stops = try await service.searchStops(query: "Oden")
        #expect(stops.count == 1)
        #expect(stops.first?.name == "Odenplan")
        #expect(stops.first?.id == "9021014001002000")
    }
}

