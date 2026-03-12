# Glance Configuration Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a settings view accessible from the menu bar dropdown that lets users add, remove, and reorder Statuspage services and set the polling interval. Configuration persists to disk via JSON.

**Architecture:** A `ConfigStore` class manages loading/saving a JSON config file from `~/Library/Application Support/Glance/config.json`. `StatusManager` becomes driven by `ConfigStore` — when config changes, it restarts polling with updated definitions and interval. A `SettingsView` provides the editing UI, opened from a button in the footer of the existing dropdown.

**Tech Stack:** Swift, SwiftUI, Foundation (JSONEncoder/Decoder, FileManager)

---

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `Glance/ConfigStore.swift` | Create | Load/save JSON config, provide defaults, publish changes |
| `Glance/SettingsView.swift` | Create | Settings window UI — service list with add/remove/reorder, polling interval picker |
| `Glance/Models.swift` | Modify | Make `ServiceDefinition` `Codable`, `Identifiable`, `Equatable` |
| `Glance/StatusManager.swift` | Modify | Accept `ConfigStore`, react to config changes, restart polling |
| `Glance/GlanceApp.swift` | Modify | Create `ConfigStore`, pass to `StatusManager`, remove hardcoded definitions |
| `Glance/StatusMenuView.swift` | Modify | Add "Settings..." button to footer |
| `GlanceTests/ConfigStoreTests.swift` | Create | Tests for load/save/defaults |
| `GlanceTests/StatusManagerTests.swift` | Modify | Update tests for new `ConfigStore`-driven init |
| `Glance.xcodeproj/project.pbxproj` | Modify | Add new file references |

---

## Chunk 1: Configuration Model and Persistence

### Task 1: Make ServiceDefinition Codable and Identifiable

**Files:**
- Modify: `Glance/Models.swift:50-53`
- Modify: `GlanceTests/ModelsTests.swift`

- [ ] **Step 1: Write failing test for ServiceDefinition Codable round-trip**

Add to `GlanceTests/ModelsTests.swift`:

```swift
func testServiceDefinitionCodableRoundTrip() {
    let definition = ServiceDefinition(
        name: "Test",
        baseURL: URL(string: "https://test.statuspage.io")!
    )
    let data = try! JSONEncoder().encode(definition)
    let decoded = try! JSONDecoder().decode(ServiceDefinition.self, from: data)
    XCTAssertEqual(decoded, definition)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project Glance.xcodeproj -scheme Glance -destination 'platform=macOS'`
Expected: FAIL — `ServiceDefinition` does not conform to `Codable`/`Equatable`

- [ ] **Step 3: Make ServiceDefinition Codable, Identifiable, and Equatable**

In `Glance/Models.swift`, change `ServiceDefinition` to:

```swift
struct ServiceDefinition: Codable, Identifiable, Equatable {
    var id: String { name }
    let name: String
    let baseURL: URL
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project Glance.xcodeproj -scheme Glance -destination 'platform=macOS'`
Expected: All tests PASS

- [ ] **Step 5: Commit**

```bash
git add Glance/Models.swift GlanceTests/ModelsTests.swift
git commit -m "feat: make ServiceDefinition Codable, Identifiable, and Equatable"
```

---

### Task 2: Create ConfigStore with load/save and defaults

**Files:**
- Create: `Glance/ConfigStore.swift`
- Create: `GlanceTests/ConfigStoreTests.swift`
- Modify: `Glance.xcodeproj/project.pbxproj`

The `ConfigStore` is an `ObservableObject` that:
- Publishes `services: [ServiceDefinition]` and `pollingInterval: TimeInterval`
- Loads from `~/Library/Application Support/Glance/config.json` on init
- Falls back to hardcoded defaults (Anthropic + GitHub, 300s) if file missing or corrupt
- Saves to disk on every mutation
- Provides `addService`, `removeService`, `moveService`, `updatePollingInterval` methods
- Accepts a `fileURL` parameter for testability (tests use a temp file)

The JSON structure on disk:

```json
{
  "services": [
    {"name": "Anthropic", "baseURL": "https://anthropic.statuspage.io"},
    {"name": "GitHub", "baseURL": "https://www.githubstatus.com"}
  ],
  "pollingInterval": 300
}
```

- [ ] **Step 1: Add ConfigStore.swift and ConfigStoreTests.swift to project.pbxproj**

Add the following entries to `project.pbxproj`:

In PBXBuildFile section:
```
A100000012 /* ConfigStore.swift in Sources */ = {isa = PBXBuildFile; fileRef = A200000015 /* ConfigStore.swift */; };
A100000013 /* ConfigStoreTests.swift in Sources */ = {isa = PBXBuildFile; fileRef = A200000016 /* ConfigStoreTests.swift */; };
```

In PBXFileReference section:
```
A200000015 /* ConfigStore.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ConfigStore.swift; sourceTree = "<group>"; };
A200000016 /* ConfigStoreTests.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ConfigStoreTests.swift; sourceTree = "<group>"; };
```

In PBXGroup `A700000002` (Glance), add `A200000015 /* ConfigStore.swift */` to children.
In PBXGroup `A700000003` (GlanceTests), add `A200000016 /* ConfigStoreTests.swift */` to children.

In PBXSourcesBuildPhase `A800000001` (app Sources), add `A100000012 /* ConfigStore.swift in Sources */` to files.
In PBXSourcesBuildPhase `A800000002` (test Sources), add `A100000013 /* ConfigStoreTests.swift in Sources */` to files.

- [ ] **Step 2: Write failing tests for ConfigStore**

Create `GlanceTests/ConfigStoreTests.swift`:

```swift
import XCTest
@testable import Glance

final class ConfigStoreTests: XCTestCase {

    private var tempURL: URL!

    override func setUp() {
        super.setUp()
        tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("json")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempURL)
        super.tearDown()
    }

    func testDefaultsWhenNoFile() {
        let store = ConfigStore(fileURL: tempURL)
        XCTAssertEqual(store.services.count, 2)
        XCTAssertEqual(store.services[0].name, "Anthropic")
        XCTAssertEqual(store.services[1].name, "GitHub")
        XCTAssertEqual(store.pollingInterval, 300)
    }

    func testLoadsFromFile() throws {
        let json = """
        {
            "services": [
                {"name": "Custom", "baseURL": "https://custom.statuspage.io"}
            ],
            "pollingInterval": 60
        }
        """.data(using: .utf8)!
        try json.write(to: tempURL)

        let store = ConfigStore(fileURL: tempURL)
        XCTAssertEqual(store.services.count, 1)
        XCTAssertEqual(store.services[0].name, "Custom")
        XCTAssertEqual(store.pollingInterval, 60)
    }

    func testFallsBackToDefaultsOnCorruptFile() throws {
        try "not json".data(using: .utf8)!.write(to: tempURL)
        let store = ConfigStore(fileURL: tempURL)
        XCTAssertEqual(store.services.count, 2)
        XCTAssertEqual(store.pollingInterval, 300)
    }

    func testAddServicePersists() {
        let store = ConfigStore(fileURL: tempURL)
        store.addService(name: "New", baseURL: URL(string: "https://new.statuspage.io")!)
        XCTAssertEqual(store.services.count, 3)
        XCTAssertEqual(store.services[2].name, "New")

        let reloaded = ConfigStore(fileURL: tempURL)
        XCTAssertEqual(reloaded.services.count, 3)
        XCTAssertEqual(reloaded.services[2].name, "New")
    }

    func testRemoveServicePersists() {
        let store = ConfigStore(fileURL: tempURL)
        let toRemove = store.services[0]
        store.removeServices(at: IndexSet(integer: 0))
        XCTAssertEqual(store.services.count, 1)
        XCTAssertFalse(store.services.contains(where: { $0.name == toRemove.name }))

        let reloaded = ConfigStore(fileURL: tempURL)
        XCTAssertEqual(reloaded.services.count, 1)
    }

    func testMoveServicePersists() {
        let store = ConfigStore(fileURL: tempURL)
        store.moveServices(from: IndexSet(integer: 0), to: 2)
        XCTAssertEqual(store.services[0].name, "GitHub")
        XCTAssertEqual(store.services[1].name, "Anthropic")

        let reloaded = ConfigStore(fileURL: tempURL)
        XCTAssertEqual(reloaded.services[0].name, "GitHub")
        XCTAssertEqual(reloaded.services[1].name, "Anthropic")
    }

    func testUpdatePollingIntervalPersists() {
        let store = ConfigStore(fileURL: tempURL)
        store.updatePollingInterval(120)
        XCTAssertEqual(store.pollingInterval, 120)

        let reloaded = ConfigStore(fileURL: tempURL)
        XCTAssertEqual(reloaded.pollingInterval, 120)
    }

    func testUpdatePollingIntervalClampsMinimum() {
        let store = ConfigStore(fileURL: tempURL)
        store.updatePollingInterval(5)
        XCTAssertEqual(store.pollingInterval, 30)
    }
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `xcodebuild test -project Glance.xcodeproj -scheme Glance -destination 'platform=macOS'`
Expected: FAIL — `ConfigStore` not defined

- [ ] **Step 4: Implement ConfigStore**

Create `Glance/ConfigStore.swift`:

```swift
import Foundation

final class ConfigStore: ObservableObject {
    @Published private(set) var services: [ServiceDefinition]
    @Published private(set) var pollingInterval: TimeInterval

    private let fileURL: URL

    static let defaultServices = [
        ServiceDefinition(name: "Anthropic", baseURL: URL(string: "https://anthropic.statuspage.io")!),
        ServiceDefinition(name: "GitHub", baseURL: URL(string: "https://www.githubstatus.com")!),
    ]
    static let defaultPollingInterval: TimeInterval = 300
    static let minimumPollingInterval: TimeInterval = 30

    init(fileURL: URL? = nil) {
        let url = fileURL ?? Self.defaultFileURL()
        self.fileURL = url

        if let data = try? Data(contentsOf: url),
           let config = try? JSONDecoder().decode(PersistedConfig.self, from: data) {
            self.services = config.services
            self.pollingInterval = max(config.pollingInterval, Self.minimumPollingInterval)
        } else {
            self.services = Self.defaultServices
            self.pollingInterval = Self.defaultPollingInterval
        }
    }

    func addService(name: String, baseURL: URL) {
        services.append(ServiceDefinition(name: name, baseURL: baseURL))
        save()
    }

    func removeServices(at offsets: IndexSet) {
        services.remove(atOffsets: offsets)
        save()
    }

    func moveServices(from source: IndexSet, to destination: Int) {
        services.move(fromOffsets: source, toOffset: destination)
        save()
    }

    func updatePollingInterval(_ interval: TimeInterval) {
        pollingInterval = max(interval, Self.minimumPollingInterval)
        save()
    }

    private func save() {
        let config = PersistedConfig(services: services, pollingInterval: pollingInterval)
        guard let data = try? JSONEncoder().encode(config) else { return }
        let directory = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(to: fileURL, options: .atomic)
    }

    private static func defaultFileURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport
            .appendingPathComponent("Glance")
            .appendingPathComponent("config.json")
    }
}

private struct PersistedConfig: Codable {
    let services: [ServiceDefinition]
    let pollingInterval: TimeInterval
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `xcodebuild test -project Glance.xcodeproj -scheme Glance -destination 'platform=macOS'`
Expected: All tests PASS

- [ ] **Step 6: Commit**

```bash
git add Glance/ConfigStore.swift GlanceTests/ConfigStoreTests.swift Glance.xcodeproj/project.pbxproj
git commit -m "feat: add ConfigStore for persisted service configuration"
```

---

## Chunk 2: Wire ConfigStore into StatusManager and App

### Task 3: Make StatusManager config-driven

**Files:**
- Modify: `Glance/StatusManager.swift`
- Modify: `GlanceTests/StatusManagerTests.swift`

`StatusManager` currently takes `serviceDefinitions` and `pollingInterval` as init parameters. Change it to accept a `ConfigStore` and observe it. When config changes, restart polling with new definitions/interval.

Key changes:
- Init takes `ConfigStore` instead of `serviceDefinitions`/`pollingInterval`
- Store a Combine `AnyCancellable` sink on `configStore.objectWillChange` that calls `restartPolling()`
- `refreshAll()` reads `configStore.services` and `configStore.pollingInterval` at call time
- Keep the existing `provider`/`pollingInterval` init for tests (add a convenience init or keep both)

For testability, keep the existing init but make `ConfigStore` the primary path. Tests can continue using the direct init.

- [ ] **Step 1: Update StatusManager to support ConfigStore**

Modify `Glance/StatusManager.swift`:

```swift
import Foundation
import Combine

@MainActor
final class StatusManager: ObservableObject {
    @Published private(set) var services: [ServiceStatus] = []
    @Published private(set) var worstStatus: ComponentStatus = .operational
    @Published private(set) var lastRefresh: Date?

    private let provider: any StatusProvider
    private let configStore: ConfigStore?
    private var serviceDefinitions: [ServiceDefinition]
    private var pollingInterval: TimeInterval
    private var pollingTask: Task<Void, Never>?
    private var configCancellable: AnyCancellable?

    var unreachableCount: Int {
        services.filter { $0.overallStatus == .unknown }.count
    }

    init(
        configStore: ConfigStore,
        provider: any StatusProvider,
        autoStart: Bool = false
    ) {
        self.configStore = configStore
        self.serviceDefinitions = configStore.services
        self.pollingInterval = configStore.pollingInterval
        self.provider = provider

        configCancellable = configStore.objectWillChange.sink { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.serviceDefinitions = configStore.services
                self.pollingInterval = configStore.pollingInterval
                self.startPolling()
            }
        }

        if autoStart {
            startPolling()
        }
    }

    init(
        serviceDefinitions: [ServiceDefinition],
        provider: any StatusProvider,
        pollingInterval: TimeInterval = 300,
        autoStart: Bool = false
    ) {
        self.configStore = nil
        self.serviceDefinitions = serviceDefinitions
        self.pollingInterval = pollingInterval
        self.provider = provider
        if autoStart {
            startPolling()
        }
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

        services = definitions.map { def in
            results.first { $0.id == def.name } ?? ServiceStatus(
                id: def.name, service: def, overallStatus: .unknown,
                components: [], lastUpdated: Date()
            )
        }
        worstStatus = ComponentStatus.worst(of: services.map(\.overallStatus))
        lastRefresh = Date()
    }
}
```

Note: `refreshAll()` now preserves the order from `serviceDefinitions` instead of sorting alphabetically. This respects the user's configured order.

- [ ] **Step 2: Verify existing tests still pass**

Run: `xcodebuild test -project Glance.xcodeproj -scheme Glance -destination 'platform=macOS'`
Expected: All existing tests PASS (the old init signature is preserved)

- [ ] **Step 3: Add test for ConfigStore-driven init**

Add to `GlanceTests/StatusManagerTests.swift`:

```swift
func testConfigStoreDrivenInit() async {
    let tempURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("json")
    defer { try? FileManager.default.removeItem(at: tempURL) }

    let json = """
    {
        "services": [
            {"name": "TestSvc", "baseURL": "https://test.statuspage.io"}
        ],
        "pollingInterval": 60
    }
    """.data(using: .utf8)!
    try! json.write(to: tempURL)

    let config = ConfigStore(fileURL: tempURL)
    let provider = MockStatusProvider(results: [
        "TestSvc": .success(makeServiceStatus(name: "TestSvc", overall: .operational)),
    ])
    let manager = StatusManager(configStore: config, provider: provider)

    await manager.refreshAll()

    XCTAssertEqual(manager.services.count, 1)
    XCTAssertEqual(manager.services[0].id, "TestSvc")
}
```

- [ ] **Step 4: Run tests**

Run: `xcodebuild test -project Glance.xcodeproj -scheme Glance -destination 'platform=macOS'`
Expected: All tests PASS

- [ ] **Step 5: Commit**

```bash
git add Glance/StatusManager.swift GlanceTests/StatusManagerTests.swift
git commit -m "feat: make StatusManager config-driven via ConfigStore"
```

---

### Task 4: Wire ConfigStore into GlanceApp

**Files:**
- Modify: `Glance/GlanceApp.swift`

- [ ] **Step 1: Update GlanceApp to use ConfigStore**

Replace the hardcoded `serviceDefinitions` with a `ConfigStore`:

```swift
import SwiftUI
import AppKit

@main
struct GlanceApp: App {
    @StateObject private var configStore = ConfigStore()
    @StateObject private var manager: StatusManager

    init() {
        let config = ConfigStore()
        _configStore = StateObject(wrappedValue: config)
        _manager = StateObject(wrappedValue: StatusManager(
            configStore: config,
            provider: StatuspageProvider(),
            autoStart: true
        ))
    }

    var body: some Scene {
        MenuBarExtra {
            StatusMenuView(manager: manager, configStore: configStore)
        } label: {
            Image(nsImage: statusDot(for: manager.worstStatus))
        }
        .menuBarExtraStyle(.window)
    }

    private func statusDot(for status: ComponentStatus) -> NSImage {
        let size: CGFloat = 14
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            let circle = NSBezierPath(ovalIn: rect.insetBy(dx: 2, dy: 2))
            NSColor(status.colour).setFill()
            circle.fill()
            return true
        }
        image.isTemplate = false
        return image
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `xcodebuild build -project Glance.xcodeproj -scheme Glance -destination 'platform=macOS'`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Glance/GlanceApp.swift
git commit -m "feat: wire ConfigStore into GlanceApp, remove hardcoded services"
```

---

## Chunk 3: Settings UI

### Task 5: Create SettingsView

**Files:**
- Create: `Glance/SettingsView.swift`
- Modify: `Glance.xcodeproj/project.pbxproj`

The settings view is a SwiftUI view shown in a new window (opened via `NSWindow`/`NSPanel` from a button in the footer). It contains:
- A `List` of services with drag-to-reorder and swipe-to-delete
- An "Add Service" section with name + URL text fields
- A polling interval picker (dropdown with preset values: 30s, 1m, 2m, 5m, 10m)
- A "Done" button to dismiss

Since we're targeting macOS 13 and `MenuBarExtra` with `.window` style, opening a settings window is done via `NSApp.sendAction` or by creating an `NSWindow` programmatically. The simplest approach: use `NSHostingController` + `NSWindow`.

- [ ] **Step 1: Add SettingsView.swift to project.pbxproj**

In PBXBuildFile section:
```
A100000014 /* SettingsView.swift in Sources */ = {isa = PBXBuildFile; fileRef = A200000017 /* SettingsView.swift */; };
```

In PBXFileReference section:
```
A200000017 /* SettingsView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = SettingsView.swift; sourceTree = "<group>"; };
```

In PBXGroup `A700000002` (Glance), add `A200000017 /* SettingsView.swift */` to children.
In PBXSourcesBuildPhase `A800000001` (app Sources), add `A100000014 /* SettingsView.swift in Sources */` to files.

- [ ] **Step 2: Create SettingsView**

Create `Glance/SettingsView.swift`:

```swift
import SwiftUI

struct SettingsView: View {
    @ObservedObject var configStore: ConfigStore
    var dismiss: () -> Void

    @State private var newName = ""
    @State private var newURL = ""

    private static let intervalOptions: [(String, TimeInterval)] = [
        ("30 seconds", 30),
        ("1 minute", 60),
        ("2 minutes", 120),
        ("5 minutes", 300),
        ("10 minutes", 600),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Services") {
                    List {
                        ForEach(configStore.services) { service in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(service.name)
                                        .fontWeight(.medium)
                                    Text(service.baseURL.absoluteString)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                        }
                        .onDelete { offsets in
                            configStore.removeServices(at: offsets)
                        }
                        .onMove { source, destination in
                            configStore.moveServices(from: source, to: destination)
                        }
                    }
                    .frame(minHeight: 80)
                }

                Section("Add Service") {
                    TextField("Name", text: $newName)
                    TextField("Status Page URL", text: $newURL)
                        .textFieldStyle(.roundedBorder)
                    Button("Add") {
                        guard !newName.isEmpty,
                              let url = URL(string: newURL),
                              url.scheme != nil else { return }
                        configStore.addService(name: newName, baseURL: url)
                        newName = ""
                        newURL = ""
                    }
                    .disabled(newName.isEmpty || URL(string: newURL)?.scheme == nil)
                }

                Section("Polling Interval") {
                    Picker("Check every", selection: Binding(
                        get: { configStore.pollingInterval },
                        set: { configStore.updatePollingInterval($0) }
                    )) {
                        ForEach(Self.intervalOptions, id: \.1) { label, value in
                            Text(label).tag(value)
                        }
                    }
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 400, height: 420)
    }
}

enum SettingsWindowController {
    private static var window: NSWindow?

    static func show(configStore: ConfigStore) {
        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView(configStore: configStore) {
            window?.close()
            window = nil
        }

        let hostingController = NSHostingController(rootView: settingsView)
        let newWindow = NSWindow(contentViewController: hostingController)
        newWindow.title = "Glance Settings"
        newWindow.styleMask = [.titled, .closable]
        newWindow.center()
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window = newWindow
    }
}
```

- [ ] **Step 3: Build to verify it compiles**

Run: `xcodebuild build -project Glance.xcodeproj -scheme Glance -destination 'platform=macOS'`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add Glance/SettingsView.swift Glance.xcodeproj/project.pbxproj
git commit -m "feat: add SettingsView with service management and polling interval"
```

---

### Task 6: Add Settings button to StatusMenuView footer

**Files:**
- Modify: `Glance/StatusMenuView.swift`

- [ ] **Step 1: Add configStore parameter and Settings button**

Update `StatusMenuView` to accept `configStore` and add a "Settings..." button between the status text and the Quit button:

In `StatusMenuView`:
- Add `@ObservedObject var configStore: ConfigStore`
- Add a "Settings..." `Button` in `footerView` just before the Quit button

The footer should look like:

```swift
@ViewBuilder
private var footerView: some View {
    VStack(alignment: .leading, spacing: 4) {
        if let lastRefresh = manager.lastRefresh {
            Text("Last checked: \(Self.humanizedTime(since: lastRefresh))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        if manager.unreachableCount > 0 {
            Text("\(manager.unreachableCount) service\(manager.unreachableCount == 1 ? "" : "s") unreachable")
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        Divider()

        Button("Settings...") {
            SettingsWindowController.show(configStore: configStore)
        }
        .keyboardShortcut(",")

        Button("Quit Glance") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `xcodebuild build -project Glance.xcodeproj -scheme Glance -destination 'platform=macOS'`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Glance/StatusMenuView.swift
git commit -m "feat: add Settings button to status menu footer"
```
