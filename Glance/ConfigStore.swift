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
