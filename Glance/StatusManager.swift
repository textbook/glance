import Combine
import Foundation

@MainActor
final class StatusManager: ObservableObject {
    @Published private(set) var services: [ServiceStatus] = []
    @Published private(set) var worstStatus: ComponentStatus = .operational
    @Published private(set) var lastRefresh: Date?

    private var pollingInterval: TimeInterval
    private var serviceDefinitions: [ServiceDefinition]
    private let provider: any StatusProvider
    private var pollingTask: Task<Void, Never>?
    private var configCancellable: AnyCancellable?

    var unreachableCount: Int {
        services.filter { $0.overallStatus == .unknown }.count
    }

    init(
        configStore: ConfigStore,
        provider: any StatusProvider,
        autoStart: Bool = false
    ) {
        self.serviceDefinitions = configStore.services
        self.pollingInterval = configStore.pollingInterval
        self.provider = provider

        configCancellable = configStore.objectWillChange.sink { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.serviceDefinitions = configStore.services
                self.pollingInterval = configStore.pollingInterval
                self.startPolling()
            }
        }

        if autoStart {
            startPolling()
        }
    }

    init(
        serviceDefinitions: [ServiceDefinition],
        provider: any StatusProvider,
        pollingInterval: TimeInterval = 300,
        autoStart: Bool = false
    ) {
        self.serviceDefinitions = serviceDefinitions
        self.provider = provider
        self.pollingInterval = pollingInterval
        if autoStart {
            startPolling()
        }
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

        services = definitions.map { def in
            results.first { $0.id == def.name } ?? ServiceStatus(
                id: def.name, service: def, overallStatus: .unknown,
                components: [], lastUpdated: Date()
            )
        }
        worstStatus = ComponentStatus.worst(of: services.map(\.overallStatus))
        lastRefresh = Date()
    }
}
