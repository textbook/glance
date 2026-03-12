import SwiftUI

struct StatusMenuView: View {
    @ObservedObject var manager: StatusManager
    @ObservedObject var configStore: ConfigStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(manager.services) { service in
                        ServiceSectionView(service: service)
                        Divider()
                    }
                }
            }
            .frame(maxHeight: 400)

            footerView
        }
        .frame(width: 280)
    }

    private static func humanizedTime(since date: Date) -> String {
        let seconds = Int(-date.timeIntervalSinceNow)
        switch seconds {
        case ..<60: return "less than a minute ago"
        case ..<120: return "1 minute ago"
        case ..<3600: return "\(seconds / 60) minutes ago"
        case ..<7200: return "1 hour ago"
        default: return "\(seconds / 3600) hours ago"
        }
    }

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

            HStack {
                Button("Settings...") {
                    SettingsWindowController.show(configStore: configStore)
                }
                .keyboardShortcut(",")

                Spacer()

                Button("Quit Glance") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
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
                isExpanded.toggle()
            } label: {
                HStack {
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
                .padding(.leading, 24)
                .padding(.trailing, 12)
                .padding(.bottom, 8)
            }
        }
    }
}
