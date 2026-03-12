import SwiftUI

struct SettingsView: View {
    @ObservedObject var configStore: ConfigStore
    var dismiss: () -> Void

    @State private var selection: ServiceDefinition.ID?
    @State private var showingAddSheet = false

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
                    List(selection: $selection) {
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
                                Image(systemName: "line.3.horizontal")
                                    .foregroundStyle(.tertiary)
                                    .onHover { hovering in
                                        if hovering {
                                            NSCursor.openHand.push()
                                        } else {
                                            NSCursor.pop()
                                        }
                                    }
                            }
                            .tag(service.id)
                            .contextMenu {
                                Button("Copy URL") {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(service.baseURL.absoluteString, forType: .string)
                                }
                            }
                        }
                        .onMove { source, destination in
                            configStore.moveServices(from: source, to: destination)
                        }
                    }
                    .frame(height: max(40 * CGFloat(configStore.services.count), 40))

                    HStack(spacing: 0) {
                        Button(action: { showingAddSheet = true }) {
                            Image(systemName: "plus")
                                .frame(width: 24, height: 20)
                        }
                        Divider()
                            .frame(height: 16)
                        Button(action: removeSelected) {
                            Image(systemName: "minus")
                                .frame(width: 24, height: 20)
                        }
                        .disabled(selection == nil)
                        Spacer()
                    }
                    .buttonStyle(.borderless)
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
        .frame(width: 400, height: 380)
        .sheet(isPresented: $showingAddSheet) {
            AddServiceSheet(configStore: configStore)
        }
    }

    private func removeSelected() {
        guard let selection,
              let index = configStore.services.firstIndex(where: { $0.id == selection }) else { return }
        configStore.removeServices(at: IndexSet(integer: index))
        self.selection = nil
    }
}

struct AddServiceSheet: View {
    @ObservedObject var configStore: ConfigStore
    var provider: any StatusProvider = StatuspageProvider()
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var urlString = ""
    @State private var isChecking = false
    @State private var errorMessage: String?

    private var isValid: Bool {
        !name.isEmpty && URL(string: urlString)?.scheme != nil
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Add Service")
                .font(.headline)

            Form {
                TextField("Name:", text: $name)
                TextField("Status Page URL:", text: $urlString)
                    .onChange(of: urlString) { _ in errorMessage = nil }
            }
            .formStyle(.grouped)

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
            }

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Spacer()
                if isChecking {
                    ProgressView()
                        .controlSize(.small)
                }
                Button("Add") {
                    Task { await addService() }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid || isChecking)
            }
        }
        .padding()
        .frame(width: 320)
    }

    private func addService() async {
        guard let url = URL(string: urlString) else { return }
        let definition = ServiceDefinition(name: name, baseURL: url)
        isChecking = true
        errorMessage = nil
        do {
            _ = try await provider.fetchStatus(for: definition)
            configStore.addService(name: name, baseURL: url)
            dismiss()
        } catch {
            errorMessage = "Could not reach a Statuspage API at this URL. Check the URL is a valid Statuspage (e.g. https://status.example.com)."
        }
        isChecking = false
    }
}

enum SettingsWindowController {
    private static var window: NSWindow?

    static func show(configStore: ConfigStore) {
        if let existing = window, existing.isVisible {
            NSApp.activate(ignoringOtherApps: true)
            existing.orderFrontRegardless()
            existing.makeKeyAndOrderFront(nil)
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
        NSApp.activate(ignoringOtherApps: true)
        newWindow.orderFrontRegardless()
        newWindow.makeKeyAndOrderFront(nil)
        window = newWindow
    }
}
