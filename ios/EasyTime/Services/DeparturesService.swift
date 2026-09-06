import Foundation

public enum DeparturesServiceError: Error, LocalizedError, Equatable {
    case invalidURL
    case networkError(String)
    case serverError(statusCode: Int, message: String)
    case decodingError(String)
    case emptyStopId

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The request URL is invalid."
        case .networkError(let message):
            return "Network connection failed: \(message)"
        case .serverError(let statusCode, let message):
            return "Server returned an error (\(statusCode)): \(message)"
        case .decodingError(let message):
            return "Failed to parse departures data: \(message)"
        case .emptyStopId:
            return "A valid stop ID is required to fetch departures."
        }
    }
}

public protocol DeparturesServiceProtocol: Sendable {
    func fetchDepartures(
        stopId: String,
        routeId: String?,
        direction: String?,
        platform: String?,
        destination: String?,
        limit: Int?,
        timeWindowMinutes: Int?
    ) async throws -> APIDeparturesResponse

    func searchStops(query: String) async throws -> [TransitStop]
}

public extension DeparturesServiceProtocol {
    func fetchDepartures(
        stopId: String,
        routeId: String? = nil,
        direction: String? = nil,
        platform: String? = nil,
        destination: String? = nil,
        limit: Int? = 10,
        timeWindowMinutes: Int? = 60
    ) async throws -> APIDeparturesResponse {
        try await fetchDepartures(
            stopId: stopId,
            routeId: routeId,
            direction: direction,
            platform: platform,
            destination: destination,
            limit: limit,
            timeWindowMinutes: timeWindowMinutes
        )
    }

    func searchStops(query: String = "") async throws -> [TransitStop] {
        try await searchStops(query: query)
    }
}

public final class DeparturesAPIService: DeparturesServiceProtocol {
    public let baseURL: URL
    private let session: URLSession

    public init(
        baseURL: URL = URL(string: "http://localhost:8000/v1")!,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.session = session
    }

    public func fetchDepartures(
        stopId: String,
        routeId: String? = nil,
        direction: String? = nil,
        platform: String? = nil,
        destination: String? = nil,
        limit: Int? = 10,
        timeWindowMinutes: Int? = 60
    ) async throws -> APIDeparturesResponse {
        let trimmedStopId = stopId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedStopId.isEmpty else {
            throw DeparturesServiceError.emptyStopId
        }

        var urlComponents = URLComponents(
            url: baseURL.appendingPathComponent("departures"),
            resolvingAgainstBaseURL: true
        )
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "stop_id", value: trimmedStopId)
        ]

        if let routeId = routeId, !routeId.isEmpty {
            queryItems.append(URLQueryItem(name: "route_id", value: routeId))
        }
        if let direction = direction, !direction.isEmpty {
            queryItems.append(URLQueryItem(name: "direction", value: direction))
        }
        if let platform = platform, !platform.isEmpty {
            queryItems.append(URLQueryItem(name: "platform", value: platform))
        }
        if let destination = destination, !destination.isEmpty {
            queryItems.append(URLQueryItem(name: "destination", value: destination))
        }
        if let limit = limit {
            queryItems.append(URLQueryItem(name: "limit", value: String(limit)))
        }
        if let timeWindowMinutes = timeWindowMinutes {
            queryItems.append(URLQueryItem(name: "time_window_minutes", value: String(timeWindowMinutes)))
        }

        urlComponents?.queryItems = queryItems

        guard let url = urlComponents?.url else {
            throw DeparturesServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15.0

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw DeparturesServiceError.networkError(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DeparturesServiceError.networkError("Invalid response type from server.")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw DeparturesServiceError.serverError(
                statusCode: httpResponse.statusCode,
                message: errorBody
            )
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateStr = try container.decode(String.self)

            let isoFormatterWithFractional = ISO8601DateFormatter()
            isoFormatterWithFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = isoFormatterWithFractional.date(from: dateStr) {
                return date
            }

            let standardIsoFormatter = ISO8601DateFormatter()
            standardIsoFormatter.formatOptions = [.withInternetDateTime]
            if let date = standardIsoFormatter.date(from: dateStr) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date string '\(dateStr)' using ISO8601 format."
            )
        }

        do {
            return try decoder.decode(APIDeparturesResponse.self, from: data)
        } catch {
            throw DeparturesServiceError.decodingError(error.localizedDescription)
        }
    }

    public func searchStops(query: String = "") async throws -> [TransitStop] {
        var urlComponents = URLComponents(
            url: baseURL.appendingPathComponent("stops"),
            resolvingAgainstBaseURL: true
        )
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            urlComponents?.queryItems = [URLQueryItem(name: "query", value: trimmed)]
        }

        guard let url = urlComponents?.url else {
            throw DeparturesServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10.0

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            // Fallback to offline presets on network failure
            return filterPresets(query: trimmed)
        }

        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            return filterPresets(query: trimmed)
        }

        do {
            let decoded = try JSONDecoder().decode(APIStopsResponse.self, from: data)
            let results = decoded.stops.map { $0.toTransitStop() }
            return results.isEmpty ? filterPresets(query: trimmed) : results
        } catch {
            return filterPresets(query: trimmed)
        }
    }

    private func filterPresets(query: String) -> [TransitStop] {
        if query.isEmpty {
            return TransitStop.presetStops
        }
        return TransitStop.presetStops.filter {
            $0.name.localizedCaseInsensitiveContains(query) || $0.id == query
        }
    }
}
