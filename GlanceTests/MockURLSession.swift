import Foundation
@testable import Glance

final class MockURLSession: URLSessionProtocol {
    let data: Data
    let response: URLResponse
    var error: Error?

    init(data: Data, response: URLResponse) {
        self.data = data
        self.response = response
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        if let error { throw error }
        return (data, response)
    }
}
