import Foundation
import Testing
@testable import EasyTime

final class MockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

struct DeparturesAPIServiceTests {
    private func createMockSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    @Test func fetchDeparturesSuccessfullyParsesResponse() async throws {
        let json = """
        {
            "generated_at": "2026-08-28T08:10:00.123Z",
            "freshness_at": "2026-08-28T08:09:45Z",
            "stop_id": "9021014001234000",
            "departures": [
                {
                    "route": "43",
                    "destination": "Hökarängen",
                    "scheduled_at": "2026-08-28T08:18:00Z",
                    "predicted_at": "2026-08-28T08:21:00Z",
                    "platform": "2",
                    "status": "delayed",
                    "trip_id": "14010000637189101",
                    "stop_id": "9021014001234000",
                    "stop_name": "Skanstull",
                    "delay_minutes": 3,
                    "is_realtime": true
                }
            ]
        }
        """.data(using: .utf8)!

        MockURLProtocol.requestHandler = { request in
            #expect(request.url?.query?.contains("stop_id=9021014001234000") == true)
            #expect(request.url?.query?.contains("route_id=43") == true)
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, json)
        }

        let session = createMockSession()
        let service = DeparturesAPIService(session: session)

        let result = try await service.fetchDepartures(
            stopId: "9021014001234000",
            routeId: "43"
        )

        #expect(result.stopId == "9021014001234000")
        #expect(result.departures.count == 1)

        let item = result.departures[0]
        #expect(item.route == "43")
        #expect(item.destination == "Hökarängen")
        #expect(item.platform == "2")
        #expect(item.status == .delayed)
        #expect(item.delayMinutes == 3)
        #expect(item.isRealtime == true)

        let departure = item.toDeparture()
        #expect(departure.route == "43")
        #expect(departure.isDelayed == true)
    }

    @Test func fetchDeparturesWithEmptyStopIdThrowsError() async {
        let service = DeparturesAPIService()
        await #expect(throws: DeparturesServiceError.emptyStopId) {
            try await service.fetchDepartures(stopId: "   ")
        }
    }

    @Test func fetchDeparturesHandlesHTTPError() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 503,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, "Service Unavailable".data(using: .utf8)!)
        }

        let session = createMockSession()
        let service = DeparturesAPIService(session: session)

        do {
            _ = try await service.fetchDepartures(stopId: "9021014001234000")
            Issue.record("Expected server error to be thrown")
        } catch let DeparturesServiceError.serverError(statusCode, message) {
            #expect(statusCode == 503)
            #expect(message == "Service Unavailable")
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }
}

