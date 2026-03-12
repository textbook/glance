import SwiftUI

enum ComponentStatus: Int, Comparable, CaseIterable {
    case operational = 0
    case degradedPerformance = 1
    case partialOutage = 2
    case majorOutage = 3
    case unknown = -1

    init(apiValue: String) {
        switch apiValue {
        case "operational": self = .operational
        case "degraded_performance": self = .degradedPerformance
        case "partial_outage": self = .partialOutage
        case "major_outage": self = .majorOutage
        default: self = .unknown
        }
    }

    var colour: Color {
        switch self {
        case .operational: .green
        case .degradedPerformance: .yellow
        case .partialOutage: .orange
        case .majorOutage: .red
        case .unknown: .gray
        }
    }

    var summaryText: String {
        switch self {
        case .operational: "All Operational"
        case .degradedPerformance: "Degraded"
        case .partialOutage: "Partial Outage"
        case .majorOutage: "Major Outage"
        case .unknown: "Unable to reach"
        }
    }

    static func < (lhs: ComponentStatus, rhs: ComponentStatus) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Returns the worst status, excluding `.unknown`. Returns `.operational` if empty or all unknown.
    static func worst(of statuses: [ComponentStatus]) -> ComponentStatus {
        statuses.filter { $0 != .unknown }.max() ?? .operational
    }
}

struct ServiceDefinition {
    let name: String
    let baseURL: URL
    let logoName: String
}

struct ServiceStatus: Identifiable {
    let id: String  // service name
    let service: ServiceDefinition
    let overallStatus: ComponentStatus
    let components: [Component]
    let lastUpdated: Date

    struct Component: Identifiable {
        let id: String  // component name
        let name: String
        let status: ComponentStatus
    }
}
