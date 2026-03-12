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
