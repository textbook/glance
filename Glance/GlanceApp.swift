import SwiftUI
import AppKit

@main
struct GlanceApp: App {
    @StateObject private var configStore: ConfigStore
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
