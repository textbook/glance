import XCTest
@testable import Glance

final class ConfigStoreTests: XCTestCase {

    private var tempURL: URL!

    override func setUp() {
        super.setUp()
        tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("json")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempURL)
        super.tearDown()
    }

    func testDefaultsWhenNoFile() {
        let store = ConfigStore(fileURL: tempURL)
        XCTAssertEqual(store.services.count, 2)
        XCTAssertEqual(store.services[0].name, "Anthropic")
        XCTAssertEqual(store.services[1].name, "GitHub")
        XCTAssertEqual(store.pollingInterval, 300)
    }

    func testLoadsFromFile() throws {
        let json = """
        {
            "services": [
                {"name": "Custom", "baseURL": "https://custom.statuspage.io"}
            ],
            "pollingInterval": 60
        }
        """.data(using: .utf8)!
        try json.write(to: tempURL)

        let store = ConfigStore(fileURL: tempURL)
        XCTAssertEqual(store.services.count, 1)
        XCTAssertEqual(store.services[0].name, "Custom")
        XCTAssertEqual(store.pollingInterval, 60)
    }

    func testFallsBackToDefaultsOnCorruptFile() throws {
        try "not json".data(using: .utf8)!.write(to: tempURL)
        let store = ConfigStore(fileURL: tempURL)
        XCTAssertEqual(store.services.count, 2)
        XCTAssertEqual(store.pollingInterval, 300)
    }

    func testAddServicePersists() {
        let store = ConfigStore(fileURL: tempURL)
        store.addService(name: "New", baseURL: URL(string: "https://new.statuspage.io")!)
        XCTAssertEqual(store.services.count, 3)
        XCTAssertEqual(store.services[2].name, "New")

        let reloaded = ConfigStore(fileURL: tempURL)
        XCTAssertEqual(reloaded.services.count, 3)
        XCTAssertEqual(reloaded.services[2].name, "New")
    }

    func testRemoveServicePersists() {
        let store = ConfigStore(fileURL: tempURL)
        let toRemove = store.services[0]
        store.removeServices(at: IndexSet(integer: 0))
        XCTAssertEqual(store.services.count, 1)
        XCTAssertFalse(store.services.contains(where: { $0.name == toRemove.name }))

        let reloaded = ConfigStore(fileURL: tempURL)
        XCTAssertEqual(reloaded.services.count, 1)
    }

    func testMoveServicePersists() {
        let store = ConfigStore(fileURL: tempURL)
        store.moveServices(from: IndexSet(integer: 0), to: 2)
        XCTAssertEqual(store.services[0].name, "GitHub")
        XCTAssertEqual(store.services[1].name, "Anthropic")

        let reloaded = ConfigStore(fileURL: tempURL)
        XCTAssertEqual(reloaded.services[0].name, "GitHub")
        XCTAssertEqual(reloaded.services[1].name, "Anthropic")
    }

    func testUpdatePollingIntervalPersists() {
        let store = ConfigStore(fileURL: tempURL)
        store.updatePollingInterval(120)
        XCTAssertEqual(store.pollingInterval, 120)

        let reloaded = ConfigStore(fileURL: tempURL)
        XCTAssertEqual(reloaded.pollingInterval, 120)
    }

    func testUpdatePollingIntervalClampsMinimum() {
        let store = ConfigStore(fileURL: tempURL)
        store.updatePollingInterval(5)
        XCTAssertEqual(store.pollingInterval, 30)
    }
}
