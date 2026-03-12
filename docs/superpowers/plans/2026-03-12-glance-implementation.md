# Glance Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a macOS menu bar app that polls Statuspage-powered service status pages and displays aggregate health as a coloured dot with an expandable dropdown.

**Architecture:** SwiftUI app using `MenuBarExtra` for the menu bar presence. Business logic lives in testable types: `StatusProvider` protocol with `StatuspageProvider` implementation for API calls, `StatusManager` for polling and aggregation. Models are plain value types.

**Tech Stack:** Swift 5.9+, SwiftUI, XCTest, URLSession, macOS 13+

**Spec:** `docs/superpowers/specs/2026-03-12-glance-menu-bar-widget-design.md`

---

## File Structure

| File | Target | Responsibility |
|------|--------|---------------|
| `Glance/Models.swift` | Glance | `ServiceDefinition`, `ComponentStatus`, `ServiceStatus` |
| `Glance/StatusProvider.swift` | Glance | `StatusProvider` protocol + `StatuspageProvider` |
| `Glance/StatusManager.swift` | Glance | Polling timer, aggregation, publishes state |
| `Glance/StatusMenuView.swift` | Glance | Dropdown content: collapsible services, footer |
| `Glance/GlanceApp.swift` | Glance | App entry point, `MenuBarExtra` |
| `GlanceTests/ModelsTests.swift` | GlanceTests | Tests for `ComponentStatus` and model behaviour |
| `GlanceTests/StatuspageProviderTests.swift` | GlanceTests | Tests for JSON parsing and error handling |
| `GlanceTests/StatusManagerTests.swift` | GlanceTests | Tests for aggregation logic |

---

## Chunk 1: Project Setup and Models

### Task 1: Create Xcode Project

- [ ] **Step 1: Create the Xcode project**

Use Xcode to create a new macOS App project:
- Product Name: `Glance`
- Team: (your team)
- Organization Identifier: (your identifier)
- Interface: SwiftUI
- Language: Swift
- Include Tests: Yes (Unit Tests)
- Location: `/Users/jonrsharpe/workspace/glance/`

This creates `Glance.xcodeproj`, `Glance/` source directory, and `GlanceTests/` test directory.

- [ ] **Step 2: Configure as menu-bar-only agent app**

In `Glance/Info.plist` (or the target's Info tab in Xcode), add:

```xml
<key>LSUIElement</key>
<true/>
```

This hides the app from the Dock.

- [ ] **Step 3: Set deployment target**

In the Xcode project, set the minimum deployment target to macOS 13.0.

- [ ] **Step 4: Verify the project builds**

Run: `xcodebuild -project Glance.xcodeproj -scheme Glance build`
Expected: BUILD SUCCEEDED

- [ ] **Step 5: Create .gitignore**

Create `.gitignore` in the project root:

```
# Xcode
xcuserdata/
build/
DerivedData/
*.xcworkspace

# macOS
.DS_Store

# Superpowers
.superpowers/
```

- [ ] **Step 6: Commit**

```bash
git add Glance.xcodeproj Glance/ GlanceTests/ .gitignore
git commit -m "chore: scaffold Xcode project for Glance menu bar app"
```

---

### Task 2: Models — ComponentStatus

- [ ] **Step 1: Write failing tests for ComponentStatus**

Create `GlanceTests/ModelsTests.swift`:

```swift
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
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project Glance.xcodeproj -scheme Glance -destination 'platform=macOS'`
Expected: FAIL — `ComponentStatus` does not exist

- [ ] **Step 3: Implement ComponentStatus**

Create `Glance/Models.swift`:

```swift
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project Glance.xcodeproj -scheme Glance -destination 'platform=macOS'`
Expected: All `ComponentStatusTests` PASS

- [ ] **Step 5: Commit**

```bash
git add Glance/Models.swift GlanceTests/ModelsTests.swift
git commit -m "feat: add ComponentStatus enum with API mapping, colours, and aggregation"
```

---

### Task 3: Models — ServiceDefinition and ServiceStatus

- [ ] **Step 1: Add ServiceDefinition and ServiceStatus to Models.swift**

Append to `Glance/Models.swift`:

```swift
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
```

- [ ] **Step 2: Verify the project still builds and tests pass**

Run: `xcodebuild test -project Glance.xcodeproj -scheme Glance -destination 'platform=macOS'`
Expected: All tests PASS

- [ ] **Step 3: Commit**

```bash
git add Glance/Models.swift
git commit -m "feat: add ServiceDefinition and ServiceStatus model types"
```

---

## Chunk 2: StatusProvider — Protocol and Statuspage Implementation

### Task 4: StatuspageProvider JSON Parsing

- [ ] **Step 1: Write failing tests for StatuspageProvider**

Create `GlanceTests/StatuspageProviderTests.swift`:

```swift
import XCTest
@testable import Glance

final class StatuspageProviderTests: XCTestCase {

    let service = ServiceDefinition(
        name: "TestService",
        baseURL: URL(string: "https://test.statuspage.io")!,
        logoName: "test-logo"
    )

    func testParsesOperationalResponse() async throws {
        let json = """
        {
            "components": [
                {"name": "API", "status": "operational", "group": false, "id": "1"},
                {"name": "Web", "status": "operational", "group": false, "id": "2"}
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
                {"name": "API", "status": "operational", "group": false, "id": "1"},
                {"name": "Web", "status": "degraded_performance", "group": false, "id": "2"}
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
                {"name": "Group Header", "status": "operational", "group": true, "id": "g1"},
                {"name": "API", "status": "operational", "group": false, "id": "1"}
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
```

- [ ] **Step 2: Create MockURLSession test helper**

Create `GlanceTests/MockURLSession.swift`:

```swift
import Foundation
@testable import Glance

final class MockURLSession: URLSessionProtocol {
    let data: Data
    let response: URLResponse
    var error: Error?

    init(data: Data, response: URLResponse) {
        self.data = data
        self.response = response
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        if let error { throw error }
        return (data, response)
    }
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `xcodebuild test -project Glance.xcodeproj -scheme Glance -destination 'platform=macOS'`
Expected: FAIL — `StatuspageProvider`, `URLSessionProtocol` do not exist

- [ ] **Step 4: Implement StatusProvider protocol and StatuspageProvider**

Create `Glance/StatusProvider.swift`:

```swift
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
            .filter { !$0.group }
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
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `xcodebuild test -project Glance.xcodeproj -scheme Glance -destination 'platform=macOS'`
Expected: All `StatuspageProviderTests` PASS

- [ ] **Step 6: Commit**

```bash
git add Glance/StatusProvider.swift GlanceTests/StatuspageProviderTests.swift GlanceTests/MockURLSession.swift
git commit -m "feat: add StatusProvider protocol and StatuspageProvider with JSON parsing"
```

---

## Chunk 3: StatusManager

### Task 5: StatusManager Aggregation Logic

- [ ] **Step 1: Write failing tests for StatusManager**

Create `GlanceTests/StatusManagerTests.swift`:

```swift
import XCTest
@testable import Glance

final class StatusManagerTests: XCTestCase {

    func testWorstStatusAcrossServices() async {
        let provider = MockStatusProvider(results: [
            "Anthropic": .success(makeServiceStatus(name: "Anthropic", overall: .operational)),
            "GitHub": .success(makeServiceStatus(name: "GitHub", overall: .degradedPerformance)),
        ])
        let manager = StatusManager(
            serviceDefinitions: [
                ServiceDefinition(name: "Anthropic", baseURL: URL(string: "https://a.io")!, logoName: "a"),
                ServiceDefinition(name: "GitHub", baseURL: URL(string: "https://g.io")!, logoName: "g"),
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
                ServiceDefinition(name: "Anthropic", baseURL: URL(string: "https://a.io")!, logoName: "a"),
                ServiceDefinition(name: "GitHub", baseURL: URL(string: "https://g.io")!, logoName: "g"),
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
                ServiceDefinition(name: "Anthropic", baseURL: URL(string: "https://a.io")!, logoName: "a"),
                ServiceDefinition(name: "GitHub", baseURL: URL(string: "https://g.io")!, logoName: "g"),
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
            service: ServiceDefinition(name: name, baseURL: URL(string: "https://example.com")!, logoName: ""),
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project Glance.xcodeproj -scheme Glance -destination 'platform=macOS'`
Expected: FAIL — `StatusManager` does not exist

- [ ] **Step 3: Implement StatusManager**

Create `Glance/StatusManager.swift`:

```swift
import Foundation

@MainActor
final class StatusManager: ObservableObject {
    @Published private(set) var services: [ServiceStatus] = []
    @Published private(set) var worstStatus: ComponentStatus = .operational
    @Published private(set) var lastRefresh: Date?

    let pollingInterval: TimeInterval
    private let serviceDefinitions: [ServiceDefinition]
    private let provider: StatusProvider
    private var pollingTask: Task<Void, Never>?

    var unreachableCount: Int {
        services.filter { $0.overallStatus == .unknown }.count
    }

    init(
        serviceDefinitions: [ServiceDefinition],
        provider: StatusProvider,
        pollingInterval: TimeInterval = 300
    ) {
        self.serviceDefinitions = serviceDefinitions
        self.provider = provider
        self.pollingInterval = pollingInterval
    }

    func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task {
            await refreshAll()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(pollingInterval))
                guard !Task.isCancelled else { break }
                await refreshAll()
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    func refreshAll() async {
        let provider = self.provider
        let definitions = self.serviceDefinitions

        let results = await withTaskGroup(
            of: ServiceStatus.self,
            returning: [ServiceStatus].self
        ) { group in
            for definition in definitions {
                group.addTask {
                    do {
                        return try await provider.fetchStatus(for: definition)
                    } catch {
                        return ServiceStatus(
                            id: definition.name,
                            service: definition,
                            overallStatus: .unknown,
                            components: [],
                            lastUpdated: Date()
                        )
                    }
                }
            }
            var collected: [ServiceStatus] = []
            for await result in group {
                collected.append(result)
            }
            return collected
        }

        services = results.sorted { $0.id < $1.id }
        worstStatus = ComponentStatus.worst(of: services.map(\.overallStatus))
        lastRefresh = Date()
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project Glance.xcodeproj -scheme Glance -destination 'platform=macOS'`
Expected: All `StatusManagerTests` PASS

- [ ] **Step 5: Commit**

```bash
git add Glance/StatusManager.swift GlanceTests/StatusManagerTests.swift
git commit -m "feat: add StatusManager with concurrent polling and status aggregation"
```

---

## Chunk 4: UI — Views and App Entry Point

### Task 6: StatusMenuView

- [ ] **Step 1: Implement StatusMenuView**

Create `Glance/StatusMenuView.swift`:

```swift
import SwiftUI

struct StatusMenuView: View {
    @ObservedObject var manager: StatusManager

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(manager.services) { service in
                ServiceSectionView(service: service)
                Divider()
            }

            footerView
        }
        .frame(width: 280)
    }

    @ViewBuilder
    private var footerView: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let lastRefresh = manager.lastRefresh {
                Text("Last checked: \(lastRefresh, style: .relative) ago")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if manager.unreachableCount > 0 {
                Text("\(manager.unreachableCount) service\(manager.unreachableCount == 1 ? "" : "s") unreachable")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            Button("Quit Glance") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

struct ServiceSectionView: View {
    let service: ServiceStatus
    @State private var isExpanded: Bool

    init(service: ServiceStatus) {
        self.service = service
        self._isExpanded = State(initialValue: service.overallStatus != .operational)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation { isExpanded.toggle() }
            } label: {
                HStack {
                    Image(service.service.logoName)
                        .resizable()
                        .frame(width: 16, height: 16)
                    Text(service.service.name)
                        .fontWeight(.medium)
                    Spacer()
                    Text(service.overallStatus.summaryText)
                        .font(.caption)
                        .foregroundStyle(service.overallStatus.colour)
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(service.components) { component in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(component.status.colour)
                                .frame(width: 6, height: 6)
                            Text(component.name)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.leading, 40)
                .padding(.trailing, 12)
                .padding(.bottom, 8)
            }
        }
    }
}
```

- [ ] **Step 2: Verify the project builds**

Run: `xcodebuild -project Glance.xcodeproj -scheme Glance build`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Glance/StatusMenuView.swift
git commit -m "feat: add StatusMenuView with collapsible service sections"
```

---

### Task 7: GlanceApp Entry Point

- [ ] **Step 1: Implement GlanceApp with MenuBarExtra**

Replace the contents of `Glance/GlanceApp.swift` (the template-generated file):

```swift
import SwiftUI

@main
struct GlanceApp: App {
    @StateObject private var manager = StatusManager(
        serviceDefinitions: [
            ServiceDefinition(
                name: "Anthropic",
                baseURL: URL(string: "https://anthropic.statuspage.io")!,
                logoName: "anthropic-logo"
            ),
            ServiceDefinition(
                name: "GitHub",
                baseURL: URL(string: "https://www.githubstatus.com")!,
                logoName: "github-logo"
            ),
        ],
        provider: StatuspageProvider()
    )

    var body: some Scene {
        MenuBarExtra {
            StatusMenuView(manager: manager)
        } label: {
            Image(systemName: "circle.fill")
                .renderingMode(.original)
                .foregroundStyle(manager.worstStatus.colour)
        }
        .menuBarExtraStyle(.window)
        .task {
            manager.startPolling()
        }
    }
}
```

- [ ] **Step 2: Add placeholder logo assets**

Create image set directories and Contents.json files:

```bash
mkdir -p Glance/Assets.xcassets/anthropic-logo.imageset
mkdir -p Glance/Assets.xcassets/github-logo.imageset
```

Create `Glance/Assets.xcassets/anthropic-logo.imageset/Contents.json`:
```json
{
  "images": [
    { "idiom": "universal", "scale": "1x" },
    { "idiom": "universal", "scale": "2x" },
    { "idiom": "universal", "scale": "3x" }
  ],
  "info": { "version": 1, "author": "xcode" }
}
```

Create `Glance/Assets.xcassets/github-logo.imageset/Contents.json` with the same structure.

Add actual 16x16 PNG logo files to each imageset later. The app will build without them (the `Image` view will just be empty).

- [ ] **Step 3: Delete template files**

Remove any template-generated `ContentView.swift` that Xcode created, since we don't use it.

- [ ] **Step 4: Build and run the app**

Run: `xcodebuild -project Glance.xcodeproj -scheme Glance build`
Expected: BUILD SUCCEEDED

Run the app manually from Xcode or the build output. Verify:
- A coloured dot appears in the menu bar
- Clicking it shows the dropdown with Anthropic and GitHub sections
- Components are listed under each service
- "Last checked" timestamp updates

- [ ] **Step 5: Test menu bar icon tinting**

If the coloured dot renders as a monochrome template image, switch to pre-rendered `NSImage` assets. Create four circle images (green, yellow, orange, red) in the asset catalog and select the appropriate one based on `worstStatus` instead of using SF Symbol tinting.

- [ ] **Step 6: Commit**

```bash
git add Glance/GlanceApp.swift Glance/Assets.xcassets
git rm Glance/ContentView.swift 2>/dev/null; true
git commit -m "feat: add GlanceApp entry point with MenuBarExtra and hardcoded services"
```

---

## Chunk 5: Final Integration and Polish

### Task 8: End-to-End Verification

- [ ] **Step 1: Run the full test suite**

Run: `xcodebuild test -project Glance.xcodeproj -scheme Glance -destination 'platform=macOS'`
Expected: All tests PASS

- [ ] **Step 2: Manual smoke test**

Run the app and verify:
1. Coloured dot appears in menu bar (should be green if all services are operational)
2. Clicking dot opens dropdown window
3. Each service shows with its logo, name, and status summary
4. Clicking a service row expands/collapses its components
5. Services with issues auto-expand
6. Footer shows "Last checked: X ago"
7. "Quit Glance" button terminates the app
8. App does NOT appear in the Dock

- [ ] **Step 3: Test error handling**

Temporarily change a service's `baseURL` to an invalid URL (e.g. `https://invalid.example.com`). Build and run. Verify:
- That service shows grey dot with "Unable to reach"
- Other services still show correctly
- Menu bar dot colour is not affected by the unreachable service
- Footer shows "1 service unreachable"

Revert the URL change after testing.

- [ ] **Step 4: Commit any final adjustments (if needed)**

Only commit if there were changes from the verification steps:

```bash
git status
# If there are changes:
git add Glance/ GlanceTests/
git commit -m "chore: final polish from integration verification"
```
