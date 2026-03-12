import SwiftUI
import AppKit

@main
struct GlanceApp: App {
    @StateObject private var manager = StatusManager(
        serviceDefinitions: [
            ServiceDefinition(
                name: "Anthropic",
                baseURL: URL(string: "https://anthropic.statuspage.io")!
            ),
            ServiceDefinition(
                name: "GitHub",
                baseURL: URL(string: "https://www.githubstatus.com")!
            ),
        ],
        provider: StatuspageProvider(),
        autoStart: true
    )

    var body: some Scene {
        MenuBarExtra {
            StatusMenuView(manager: manager)
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
