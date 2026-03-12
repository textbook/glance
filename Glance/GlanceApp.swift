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
        provider: StatuspageProvider(),
        autoStart: true
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
    }
}
