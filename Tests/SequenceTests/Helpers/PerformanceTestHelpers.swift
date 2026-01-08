import Foundation
import XCTest
@testable import Sequence

/// Helper utilities for performance testing
enum PerformanceTestHelpers {

    // MARK: - Timing Utilities

    /// Measure the execution time of an async operation
    /// - Parameter operation: The async operation to measure
    /// - Returns: Tuple containing the result and duration in seconds
    static func measureAsync<T>(
        _ operation: @escaping () async throws -> T
    ) async throws -> (result: T, duration: TimeInterval) {
        let start = CFAbsoluteTimeGetCurrent()
        let result = try await operation()
        let duration = CFAbsoluteTimeGetCurrent() - start
        return (result, duration)
    }

    /// Measure the execution time of an async operation and return duration in milliseconds
    static func measureAsyncMs<T>(
        _ operation: @escaping () async throws -> T
    ) async throws -> (result: T, durationMs: Double) {
        let (result, duration) = try await measureAsync(operation)
        return (result, duration * 1000)
    }

    // MARK: - Cache Management

    /// Clear all caches to simulate a cold start
    static func clearAllCaches() {
        let defaults = UserDefaults.standard

        // Clear Sequence-specific keys
        defaults.removeObject(forKey: "sequence_onboarding_completed")
        defaults.removeObject(forKey: "sequence_user_id")
        defaults.removeObject(forKey: "sequence_device_id")
        defaults.removeObject(forKey: "sequence_first_viewed_screens")

        // Clear URL cache
        URLCache.shared.removeAllCachedResponses()

        // Try to clear font cache
        let fileManager = FileManager.default
        let cacheURLs = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)

        for cacheURL in cacheURLs {
            let fontCacheDir = cacheURL.appendingPathComponent("SequenceFonts")
            if fileManager.fileExists(atPath: fontCacheDir.path) {
                try? fileManager.removeItem(at: fontCacheDir)
            }
        }

        defaults.synchronize()
    }

    /// Prewarm caches by storing config and other data
    static func prewarmCache(with config: OnboardingConfig) throws {
        // Cache will be populated when config is fetched
        // This is mainly a helper for documentation purposes
    }

    // MARK: - Sequence Management

    /// Reset the Sequence singleton to a fresh state
    @MainActor
    static func resetSequence() {
        let sequence = Sequence.shared

        // Reset configuration
        sequence.reset()

        // Reset onboarding state
        sequence.resetOnboarding()

        // Clear caches
        clearAllCaches()
    }

    // MARK: - View Rendering Helpers

    /// Wait for a specific condition to become true or timeout
    /// - Parameters:
    ///   - timeout: Maximum time to wait in seconds
    ///   - condition: Closure that returns true when condition is met
    static func waitFor(
        timeout: TimeInterval = 2.0,
        condition: @escaping () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if condition() {
                return
            }
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }

        throw TestError.timeout(
            message: "Condition not met within \(timeout) seconds"
        )
    }

    /// Check if a specific screen is currently visible in the view model
    @MainActor
    static func isScreenVisible(
        _ screenId: String,
        in viewModel: OnboardingViewModel
    ) -> Bool {
        return viewModel.currentScreen?.id == screenId
    }

    // MARK: - Test Data Helpers

    /// Create a test URLSession with mock network responses
    static func createMockSession() -> URLSession {
        return MockNetworkSession.createSession()
    }

    /// Setup mock response for config fetch
    static func setupMockConfig(
        _ config: OnboardingConfig,
        for appId: String = "test_app",
        baseURL: String = "https://api.sequence.test"
    ) throws {
        try MockNetworkSession.setupMock(
            for: appId,
            baseURL: baseURL,
            config: config
        )
    }

    /// Setup mock error response
    static func setupMockError(
        for appId: String = "test_app",
        baseURL: String = "https://api.sequence.test",
        statusCode: Int = 500
    ) {
        MockNetworkSession.setupMockError(
            for: appId,
            baseURL: baseURL,
            statusCode: statusCode
        )
    }

    // MARK: - Performance Assertions

    /// Assert that a duration is within acceptable bounds
    /// - Parameters:
    ///   - duration: Duration in milliseconds
    ///   - maxDuration: Maximum acceptable duration in milliseconds
    ///   - metric: Description of what was measured
    static func assertPerformance(
        _ duration: Double,
        maxDuration: Double,
        metric: String,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertLessThanOrEqual(
            duration,
            maxDuration,
            "\(metric) took \(String(format: "%.0f", duration))ms, expected < \(String(format: "%.0f", maxDuration))ms",
            file: file,
            line: line
        )
    }

    /// Assert warning level performance
    static func assertPerformanceWarning(
        _ duration: Double,
        warningThreshold: Double,
        metric: String
    ) {
        if duration > warningThreshold {
            print("⚠️ Performance Warning: \(metric) took \(String(format: "%.0f", duration))ms (threshold: \(String(format: "%.0f", warningThreshold))ms)")
        }
    }
}

// MARK: - Test Errors

enum TestError: Error {
    case timeout(message: String)
    case invalidState(message: String)

    var localizedDescription: String {
        switch self {
        case .timeout(let message):
            return "Test timeout: \(message)"
        case .invalidState(let message):
            return "Invalid test state: \(message)"
        }
    }
}

// MARK: - Performance Measurement Constants

struct PerformanceTargets {
    /// Target cold start time (first screen visible from configure call)
    /// Excellent performance
    static let coldStartExcellent: Double = 500 // ms

    /// Acceptable cold start time
    static let coldStartAcceptable: Double = 1000 // ms

    /// Warning threshold for cold start
    static let coldStartWarning: Double = 1500 // ms

    /// Target warm start time (with cached config)
    static let warmStartExcellent: Double = 200 // ms

    /// Acceptable warm start time
    static let warmStartAcceptable: Double = 500 // ms

    /// Target screen transition time
    static let screenTransitionExcellent: Double = 200 // ms

    /// Acceptable screen transition time
    static let screenTransitionAcceptable: Double = 300 // ms

    /// Target config fetch time
    static let configFetchExcellent: Double = 300 // ms

    /// Acceptable config fetch time
    static let configFetchAcceptable: Double = 600 // ms

    /// Target per-font load time
    static let fontLoadPerFontTarget: Double = 100 // ms
}
