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
