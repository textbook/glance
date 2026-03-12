import XCTest
@testable import Glance

final class ComponentStatusTests: XCTestCase {

    func testInitFromAPIValue() {
        XCTAssertEqual(ComponentStatus(apiValue: "operational"), .operational)
        XCTAssertEqual(ComponentStatus(apiValue: "degraded_performance"), .degradedPerformance)
        XCTAssertEqual(ComponentStatus(apiValue: "partial_outage"), .partialOutage)
        XCTAssertEqual(ComponentStatus(apiValue: "major_outage"), .majorOutage)
        XCTAssertEqual(ComponentStatus(apiValue: "garbage"), .unknown)
        XCTAssertEqual(ComponentStatus(apiValue: ""), .unknown)
    }

    func testColour() {
        XCTAssertEqual(ComponentStatus.operational.colour, .green)
        XCTAssertEqual(ComponentStatus.degradedPerformance.colour, .yellow)
        XCTAssertEqual(ComponentStatus.partialOutage.colour, .orange)
        XCTAssertEqual(ComponentStatus.majorOutage.colour, .red)
        XCTAssertEqual(ComponentStatus.unknown.colour, .gray)
    }

    func testSummaryText() {
        XCTAssertEqual(ComponentStatus.operational.summaryText, "All Operational")
        XCTAssertEqual(ComponentStatus.degradedPerformance.summaryText, "Degraded")
        XCTAssertEqual(ComponentStatus.partialOutage.summaryText, "Partial Outage")
        XCTAssertEqual(ComponentStatus.majorOutage.summaryText, "Major Outage")
        XCTAssertEqual(ComponentStatus.unknown.summaryText, "Unable to reach")
    }

    func testComparable() {
        XCTAssertTrue(ComponentStatus.operational < .degradedPerformance)
        XCTAssertTrue(ComponentStatus.degradedPerformance < .partialOutage)
        XCTAssertTrue(ComponentStatus.partialOutage < .majorOutage)
    }

    func testWorstExcludingUnknown() {
        let statuses: [ComponentStatus] = [.operational, .degradedPerformance, .operational]
        XCTAssertEqual(ComponentStatus.worst(of: statuses), .degradedPerformance)
    }

    func testWorstAllUnknownReturnsOperational() {
        let statuses: [ComponentStatus] = [.unknown, .unknown]
        XCTAssertEqual(ComponentStatus.worst(of: statuses), .operational)
    }

    func testWorstEmptyReturnsOperational() {
        XCTAssertEqual(ComponentStatus.worst(of: []), .operational)
    }

    func testServiceDefinitionCodableRoundTrip() {
        let definition = ServiceDefinition(
            name: "Test",
            baseURL: URL(string: "https://test.statuspage.io")!
        )
        let data = try! JSONEncoder().encode(definition)
        let decoded = try! JSONDecoder().decode(ServiceDefinition.self, from: data)
        XCTAssertEqual(decoded, definition)
    }
}
