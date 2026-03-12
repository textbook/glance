# Glance: macOS Menu Bar Status Widget

## Overview

A macOS menu bar app that monitors the status of online services via their status pages and displays an aggregate health indicator as a coloured dot. Clicking the dot opens a dropdown showing individual service statuses with expandable component details.

## Requirements

- macOS 13 Ventura or later (required for `MenuBarExtra`)
- Swift 5.9+ / Xcode 15+
- The app is a menu-bar-only agent (`LSUIElement = YES` in Info.plist) — no Dock icon

## Data Model

### ServiceDefinition

Defines a service to monitor.

- `name: String` — display name (e.g. "Anthropic", "GitHub")
- `baseURL: URL` — status page base URL (e.g. `https://anthropic.statuspage.io`)
- `logoName: String` — asset catalog image name

### ComponentStatus (enum)

Maps to Statuspage API `status` field values. The API returns snake_case strings; the enum uses camelCase with a custom `init(rawValue:)` mapping:

| Enum Case              | API Value              | Colour | Summary Text       |
|------------------------|------------------------|--------|-------------------|
| `operational`          | `operational`          | Green  | "All Operational" |
| `degradedPerformance`  | `degraded_performance` | Yellow | "Degraded"        |
| `partialOutage`        | `partial_outage`       | Orange | "Partial Outage"  |
| `majorOutage`          | `major_outage`         | Red    | "Major Outage"    |
| `unknown`              | (unreachable/error)    | Grey   | "Unable to reach" |

Worst-status aggregation uses enum declaration order (operational < degradedPerformance < partialOutage < majorOutage). The `unknown` case is excluded from aggregation entirely — it represents a fetch failure, not a known bad status.

### ServiceStatus

Result of polling a single service.

- `service: ServiceDefinition`
- `overallStatus: ComponentStatus` — worst component status, or `.unknown` if unreachable
- `components: [(name: String, status: ComponentStatus)]`
- `lastUpdated: Date`

`StatusManager` publishes these as `@Published` properties directly (no separate `AggregateStatus` struct):

- `services: [ServiceStatus]` — all service results
- `worstStatus: ComponentStatus` — computed from worst known status across all services, excluding `.unknown`

## Architecture

```
GlanceApp (SwiftUI App entry point)
 └─ MenuBarExtra (coloured dot icon)
     └─ StatusMenuView
         ├─ Per-service collapsible section
         │   ├─ Logo + name + summary status
         │   └─ Expandable component list with status dots
         ├─ Divider
         ├─ "Last checked: Xm ago"
         └─ Quit button

StatusManager (ObservableObject)
 - @Published services: [ServiceStatus]
 - @Published worstStatus: ComponentStatus
 - pollingInterval: TimeInterval (configurable, default 300s)
 - refreshAll() async

StatusProvider (protocol)
 - fetchStatus(for: ServiceDefinition) async throws -> ServiceStatus

StatuspageProvider (StatusProvider implementation)
 - GET {baseURL}/api/v2/summary.json
 - Parses JSON, maps component statuses
```

## File Structure

| File | Responsibility |
|------|---------------|
| `GlanceApp.swift` | App entry point, `MenuBarExtra` with coloured dot |
| `StatusMenuView.swift` | Dropdown content: collapsible service sections, footer |
| `StatusManager.swift` | Polling timer, aggregation, publishes services and worstStatus |
| `StatusProvider.swift` | `StatusProvider` protocol + `StatuspageProvider` implementation |
| `Models.swift` | `ServiceDefinition`, `ComponentStatus`, `ServiceStatus` |
| `Assets.xcassets` | Service logos (Anthropic, GitHub) |

## Menu Bar Icon

A single coloured circle reflecting the worst known status across all monitored services:

- Green: all operational
- Yellow: degraded performance somewhere
- Orange: partial outage somewhere
- Red: major outage somewhere

**Implementation note:** SwiftUI's `MenuBarExtra` may template SF Symbol images, preventing colour tinting from working reliably. Use pre-rendered `NSImage` assets (one per colour) set with `image.isTemplate = false`, or use `renderingMode(.original)`. Test on target macOS version and fall back to separate assets if tinting doesn't render correctly.

## Dropdown UI

Collapsible sections per service:

- **Collapsed**: disclosure arrow, service logo, service name, summary text on the right (see ComponentStatus table for text per status)
- **Expanded**: list of components, each with a small coloured status dot and component name
- **Auto-expand**: services with non-operational status expand by default

Footer shows "Last checked: X minutes ago", unreachable count if any (e.g. "1 service unreachable"), and a "Quit Glance" button.

## StatusProvider Protocol

```swift
protocol StatusProvider {
    func fetchStatus(for service: ServiceDefinition) async throws -> ServiceStatus
}
```

Only `StatuspageProvider` is implemented in this iteration. The protocol exists so other provider types (Instatus, custom endpoints) can be added later by conforming to the same interface.

### Statuspage API

Endpoint: `GET {baseURL}/api/v2/summary.json`

Response fields used:
- `components[]` — array of components with `name`, `status`, `group`, `group_id`
- Component `status` values: `operational`, `degraded_performance`, `partial_outage`, `major_outage`

The top-level `status.indicator` field is ignored; overall status is derived from component-level aggregation instead, for consistency with how the app computes worst-status.

Components where `group` is `true` are group headers; they are skipped. Only leaf components are displayed.

## Polling

- Configurable interval, default 5 minutes (300 seconds)
- Uses Swift `Task.sleep` in an async loop
- Polls all services concurrently using a `TaskGroup`
- First poll fires immediately on app launch
- HTTP request timeout: 15 seconds per service
- No retry within a polling cycle — a failed request marks the service as `.unknown` until the next cycle

## Error Handling

When a status page cannot be reached (network error, timeout, non-200 response, malformed JSON):

- That service's status is set to `.unknown`
- Displayed with a grey dot and "Unable to reach" text
- Does not escalate the overall menu bar dot colour
- Unreachable count shown in dropdown footer (e.g. "1 service unreachable")
- Recovers automatically on next successful poll

## Hardcoded Services (Initial)

```swift
let services: [ServiceDefinition] = [
    ServiceDefinition(name: "Anthropic", baseURL: URL(string: "https://anthropic.statuspage.io")!, logoName: "anthropic-logo"),
    ServiceDefinition(name: "GitHub", baseURL: URL(string: "https://www.githubstatus.com")!, logoName: "github-logo"),
]
```

## Future Extensions (Not In Scope)

These are explicitly deferred but the architecture accommodates them:

- **Config file** (`~/.config/glance/services.json`) for user-defined services
- **macOS notifications** on status changes
- **Non-Statuspage providers** via additional `StatusProvider` conformances
