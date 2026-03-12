import Foundation

@MainActor
final class StatusManager: ObservableObject {
    @Published private(set) var services: [ServiceStatus] = []
    @Published private(set) var worstStatus: ComponentStatus = .operational
    @Published private(set) var lastRefresh: Date?

    let pollingInterval: TimeInterval
    private let serviceDefinitions: [ServiceDefinition]
    private let provider: any StatusProvider
    private var pollingTask: Task<Void, Never>?

    var unreachableCount: Int {
        services.filter { $0.overallStatus == .unknown }.count
    }

    init(
        serviceDefinitions: [ServiceDefinition],
        provider: any StatusProvider,
        pollingInterval: TimeInterval = 300
    ) {
        self.serviceDefinitions = serviceDefinitions
        self.provider = provider
        self.pollingInterval = pollingInterval
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

        services = results.sorted { $0.id < $1.id }
        worstStatus = ComponentStatus.worst(of: services.map(\.overallStatus))
        lastRefresh = Date()
    }
}
