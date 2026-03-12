import Foundation

protocol URLSessionProtocol {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: URLSessionProtocol {}

protocol StatusProvider {
    func fetchStatus(for service: ServiceDefinition) async throws -> ServiceStatus
}

enum StatusProviderError: Error {
    case httpError(statusCode: Int)
}

struct StatuspageProvider: StatusProvider {
    let session: URLSessionProtocol
    private static let timeout: TimeInterval = 15

    init(session: URLSessionProtocol = URLSession.shared) {
        self.session = session
    }

    func fetchStatus(for service: ServiceDefinition) async throws -> ServiceStatus {
        let url = service.baseURL.appendingPathComponent("api/v2/summary.json")
        var request = URLRequest(url: url)
        request.timeoutInterval = Self.timeout

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw StatusProviderError.httpError(statusCode: code)
        }

        let summary = try JSONDecoder().decode(StatuspageResponse.self, from: data)

        let components = summary.components
            .filter { !$0.group && $0.showcase }
            .map { component in
                ServiceStatus.Component(
                    id: component.id,
                    name: component.name,
                    status: ComponentStatus(apiValue: component.status)
                )
            }

        let overallStatus = ComponentStatus.worst(of: components.map(\.status))

        return ServiceStatus(
            id: service.name,
            service: service,
            overallStatus: overallStatus,
            components: components,
            lastUpdated: Date()
        )
    }
}

// MARK: - Statuspage API Response Types

private struct StatuspageResponse: Decodable {
    let components: [StatuspageComponent]
}

private struct StatuspageComponent: Decodable {
    let id: String
    let name: String
    let status: String
    let group: Bool
    let showcase: Bool
}
