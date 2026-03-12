import XCTest
@testable import Glance

@MainActor
final class StatusManagerTests: XCTestCase {

    func testWorstStatusAcrossServices() async {
        let provider = MockStatusProvider(results: [
            "Anthropic": .success(makeServiceStatus(name: "Anthropic", overall: .operational)),
            "GitHub": .success(makeServiceStatus(name: "GitHub", overall: .degradedPerformance)),
        ])
        let manager = StatusManager(
            serviceDefinitions: [
                ServiceDefinition(name: "Anthropic", baseURL: URL(string: "https://a.io")!),
                ServiceDefinition(name: "GitHub", baseURL: URL(string: "https://g.io")!),
            ],
            provider: provider,
            pollingInterval: 300
        )

        await manager.refreshAll()

        XCTAssertEqual(manager.worstStatus, .degradedPerformance)
        XCTAssertEqual(manager.services.count, 2)
    }

    func testUnreachableServiceDoesNotEscalateWorstStatus() async {
        let provider = MockStatusProvider(results: [
            "Anthropic": .success(makeServiceStatus(name: "Anthropic", overall: .operational)),
            "GitHub": .failure(URLError(.timedOut)),
        ])
        let manager = StatusManager(
            serviceDefinitions: [
                ServiceDefinition(name: "Anthropic", baseURL: URL(string: "https://a.io")!),
                ServiceDefinition(name: "GitHub", baseURL: URL(string: "https://g.io")!),
            ],
            provider: provider,
            pollingInterval: 300
        )

        await manager.refreshAll()

        XCTAssertEqual(manager.worstStatus, .operational)
        let github = manager.services.first { $0.id == "GitHub" }
        XCTAssertEqual(github?.overallStatus, .unknown)
    }

    func testUnreachableCount() async {
        let provider = MockStatusProvider(results: [
            "Anthropic": .failure(URLError(.timedOut)),
            "GitHub": .failure(URLError(.notConnectedToInternet)),
        ])
        let manager = StatusManager(
            serviceDefinitions: [
                ServiceDefinition(name: "Anthropic", baseURL: URL(string: "https://a.io")!),
                ServiceDefinition(name: "GitHub", baseURL: URL(string: "https://g.io")!),
            ],
            provider: provider,
            pollingInterval: 300
        )

        await manager.refreshAll()

        XCTAssertEqual(manager.unreachableCount, 2)
        XCTAssertEqual(manager.worstStatus, .operational)
    }

    // MARK: - Helpers

    private func makeServiceStatus(name: String, overall: ComponentStatus) -> ServiceStatus {
        ServiceStatus(
            id: name,
            service: ServiceDefinition(name: name, baseURL: URL(string: "https://example.com")!),
            overallStatus: overall,
            components: [],
            lastUpdated: Date()
        )
    }
}

final class MockStatusProvider: StatusProvider {
    let results: [String: Result<ServiceStatus, Error>]

    init(results: [String: Result<ServiceStatus, Error>]) {
        self.results = results
    }

    func fetchStatus(for service: ServiceDefinition) async throws -> ServiceStatus {
        switch results[service.name]! {
        case .success(let status): return status
        case .failure(let error): throw error
        }
    }
}
