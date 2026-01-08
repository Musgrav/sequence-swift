import Foundation
@testable import Sequence

/// Mock URLProtocol for intercepting network requests in tests
class MockURLProtocol: URLProtocol {

    /// Dictionary mapping URLs to mock responses
    static var mockResponses: [String: (data: Data?, response: URLResponse?, error: Error?)] = [:]

    /// Default response to return if no specific mock is configured
    static var defaultResponse: (data: Data?, response: URLResponse?, error: Error?)?

    /// Whether to add latency to responses (for simulating network delays)
    static var responseLatency: TimeInterval = 0

    // MARK: - URLProtocol Methods

    override class func canInit(with request: URLRequest) -> Bool {
        // Handle all requests
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        let request = self.request

        // Look up mock response for this URL
        let responseKey = request.url?.absoluteString ?? ""
        let mock = MockURLProtocol.mockResponses[responseKey] ?? MockURLProtocol.defaultResponse

        // Apply latency if configured
        if MockURLProtocol.responseLatency > 0 {
            Thread.sleep(forTimeInterval: MockURLProtocol.responseLatency)
        }

        if let error = mock?.error {
            // Simulate error response
            client?.urlProtocol(self, didFailWithError: error)
        } else if let data = mock?.data, let response = mock?.response {
            // Simulate successful response
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } else {
            // Default error if no mock configured
            let error = NSError(domain: "MockNetworkError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No mock response configured"])
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {
        // Nothing to do for mock
    }
}

// MARK: - Mock Network Session Helper

/// Helper class to easily configure mock network responses for testing
class MockNetworkSession {

    /// Create a URLSessionConfiguration that uses the mock protocol
    static func createConfiguration() -> URLSessionConfiguration {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return config
    }

    /// Create a URLSession that uses mock responses
    static func createSession() -> URLSession {
        return URLSession(configuration: createConfiguration())
    }

    /// Setup a mock response for a given config
    static func setupMock(
        for appId: String,
        baseURL: String = "https://api.sequence.test",
        config: OnboardingConfig
    ) throws {
        let urlString = "\(baseURL)/api/v1/config/\(appId)"
        let encoder = JSONEncoder()
        let configData = try encoder.encode(config)

        let response = HTTPURLResponse(
            url: URL(string: urlString)!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!

        MockURLProtocol.mockResponses[urlString] = (data: configData, response: response, error: nil)
    }

    /// Setup a mock error response
    static func setupMockError(
        for appId: String,
        baseURL: String = "https://api.sequence.test",
        statusCode: Int = 500
    ) {
        let urlString = "\(baseURL)/api/v1/config/\(appId)"

        let response = HTTPURLResponse(
            url: URL(string: urlString)!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!

        MockURLProtocol.mockResponses[urlString] = (
            data: nil,
            response: response,
            error: NSError(domain: "HTTPError", code: statusCode, userInfo: nil)
        )
    }

    /// Clear all configured mock responses
    static func clearMocks() {
        MockURLProtocol.mockResponses.removeAll()
        MockURLProtocol.defaultResponse = nil
        MockURLProtocol.responseLatency = 0
    }

    /// Set a response latency to simulate network delay
    static func setResponseLatency(_ latency: TimeInterval) {
        MockURLProtocol.responseLatency = latency
    }
}
