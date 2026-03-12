import XCTest
@testable import Glance

final class StatuspageProviderTests: XCTestCase {

    let service = ServiceDefinition(
        name: "TestService",
        baseURL: URL(string: "https://test.statuspage.io")!
    )

    func testParsesOperationalResponse() async throws {
        let json = """
        {
            "components": [
                {"name": "API", "status": "operational", "group": false, "showcase": true, "id": "1"},
                {"name": "Web", "status": "operational", "group": false, "showcase": true, "id": "2"}
            ]
        }
        """.data(using: .utf8)!

        let mock = MockURLSession(data: json, response: HTTPURLResponse(
            url: service.baseURL, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        let provider = StatuspageProvider(session: mock)

        let status = try await provider.fetchStatus(for: service)

        XCTAssertEqual(status.overallStatus, .operational)
        XCTAssertEqual(status.components.count, 2)
        XCTAssertEqual(status.components[0].name, "API")
        XCTAssertEqual(status.components[0].status, .operational)
    }

    func testParsesDegradedResponse() async throws {
        let json = """
        {
            "components": [
                {"name": "API", "status": "operational", "group": false, "showcase": true, "id": "1"},
                {"name": "Web", "status": "degraded_performance", "group": false, "showcase": true, "id": "2"}
            ]
        }
        """.data(using: .utf8)!

        let mock = MockURLSession(data: json, response: HTTPURLResponse(
            url: service.baseURL, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        let provider = StatuspageProvider(session: mock)

        let status = try await provider.fetchStatus(for: service)

        XCTAssertEqual(status.overallStatus, .degradedPerformance)
        XCTAssertEqual(status.components[1].status, .degradedPerformance)
    }

    func testSkipsGroupComponents() async throws {
        let json = """
        {
            "components": [
                {"name": "Group Header", "status": "operational", "group": true, "showcase": false, "id": "g1"},
                {"name": "API", "status": "operational", "group": false, "showcase": true, "id": "1"}
            ]
        }
        """.data(using: .utf8)!

        let mock = MockURLSession(data: json, response: HTTPURLResponse(
            url: service.baseURL, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        let provider = StatuspageProvider(session: mock)

        let status = try await provider.fetchStatus(for: service)

        XCTAssertEqual(status.components.count, 1)
        XCTAssertEqual(status.components[0].name, "API")
    }

    func testSkipsNonShowcaseComponents() async throws {
        let json = """
        {
            "components": [
                {"name": "API", "status": "operational", "group": false, "showcase": true, "id": "1"},
                {"name": "Visit example.com", "status": "operational", "group": false, "showcase": false, "id": "2"}
            ]
        }
        """.data(using: .utf8)!

        let mock = MockURLSession(data: json, response: HTTPURLResponse(
            url: service.baseURL, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        let provider = StatuspageProvider(session: mock)

        let status = try await provider.fetchStatus(for: service)

        XCTAssertEqual(status.components.count, 1)
        XCTAssertEqual(status.components[0].name, "API")
    }

    func testThrowsOnNon200Response() async {
        let mock = MockURLSession(data: Data(), response: HTTPURLResponse(
            url: service.baseURL, statusCode: 500, httpVersion: nil, headerFields: nil)!)
        let provider = StatuspageProvider(session: mock)

        do {
            _ = try await provider.fetchStatus(for: service)
            XCTFail("Expected error")
        } catch {
            // Expected
        }
    }

    func testThrowsOnMalformedJSON() async {
        let mock = MockURLSession(data: "not json".data(using: .utf8)!, response: HTTPURLResponse(
            url: service.baseURL, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        let provider = StatuspageProvider(session: mock)

        do {
            _ = try await provider.fetchStatus(for: service)
            XCTFail("Expected error")
        } catch {
            // Expected
        }
    }
}
