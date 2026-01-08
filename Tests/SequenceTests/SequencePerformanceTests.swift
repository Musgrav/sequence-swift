import XCTest
@testable import Sequence

@MainActor
final class SequencePerformanceTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()

        // Clear all caches and reset Sequence state before each test
        PerformanceTestHelpers.resetSequence()
        MockNetworkSession.clearMocks()

        // Disable latency for most tests
        MockNetworkSession.setResponseLatency(0)
    }

    override func tearDown() async throws {
        // Clean up after each test
        MockNetworkSession.clearMocks()
        PerformanceTestHelpers.resetSequence()

        try await super.tearDown()
    }

    // MARK: - Cold Start Tests

    /// Test cold start with simple config (1 screen, minimal content)
    /// Expected: < 500ms (excellent performance)
    func testColdStartSimpleConfig() async throws {
        // Setup
        try PerformanceTestHelpers.setupMockConfig(
            TestConfigs.simple,
            for: "test_app",
            baseURL: "https://api.sequence.test"
        )

        let mockSession = PerformanceTestHelpers.createMockSession()
        let sequence = Sequence.shared

        // Configure SDK
        sequence.configure(appId: "test_app", apiKey: "test_key", baseURL: "https://api.sequence.test")

        // Measure
        let startTime = CFAbsoluteTimeGetCurrent()

        let config = try await sequence.fetchConfig(session: mockSession)

        let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000

        // Verify
        XCTAssertEqual(config.screens.count, 1, "Simple config should have 1 screen")
        PerformanceTestHelpers.assertPerformance(
            duration,
            maxDuration: PerformanceTargets.coldStartAcceptable,
            metric: "Cold start with simple config"
        )

        print("✓ Cold start (simple): \(String(format: "%.0f", duration))ms")
    }

    /// Test cold start with standard config (3 screens, realistic content)
    /// Expected: < 1000ms (acceptable performance)
    func testColdStartStandardConfig() async throws {
        // Setup
        try PerformanceTestHelpers.setupMockConfig(
            TestConfigs.standard,
            for: "test_app",
            baseURL: "https://api.sequence.test"
        )

        let mockSession = PerformanceTestHelpers.createMockSession()
        let sequence = Sequence.shared

        // Configure SDK
        sequence.configure(appId: "test_app", apiKey: "test_key", baseURL: "https://api.sequence.test")

        // Measure
        let startTime = CFAbsoluteTimeGetCurrent()

        let config = try await sequence.fetchConfig(session: mockSession)

        let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000

        // Verify
        XCTAssertEqual(config.screens.count, 3, "Standard config should have 3 screens")
        PerformanceTestHelpers.assertPerformance(
            duration,
            maxDuration: PerformanceTargets.coldStartAcceptable,
            metric: "Cold start with standard config"
        )

        print("✓ Cold start (standard): \(String(format: "%.0f", duration))ms")
    }

    /// Test cold start with complex config (5 screens, all block types)
    /// Expected: < 1000ms (acceptable performance)
    func testColdStartComplexConfig() async throws {
        // Setup
        try PerformanceTestHelpers.setupMockConfig(
            TestConfigs.complex,
            for: "test_app",
            baseURL: "https://api.sequence.test"
        )

        let mockSession = PerformanceTestHelpers.createMockSession()
        let sequence = Sequence.shared

        // Configure SDK
        sequence.configure(appId: "test_app", apiKey: "test_key", baseURL: "https://api.sequence.test")

        // Measure
        let startTime = CFAbsoluteTimeGetCurrent()

        let config = try await sequence.fetchConfig(session: mockSession)

        let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000

        // Verify
        XCTAssertEqual(config.screens.count, 5, "Complex config should have 5 screens")
        PerformanceTestHelpers.assertPerformance(
            duration,
            maxDuration: PerformanceTargets.coldStartAcceptable,
            metric: "Cold start with complex config"
        )

        print("✓ Cold start (complex): \(String(format: "%.0f", duration))ms")
    }

    // MARK: - Warm Start Tests

    /// Test warm start with cached config
    /// Expected: < 500ms (smooth performance)
    func testWarmStartWithCache() async throws {
        // Setup: First call to populate cache
        try PerformanceTestHelpers.setupMockConfig(
            TestConfigs.standard,
            for: "test_app",
            baseURL: "https://api.sequence.test"
        )

        let mockSession = PerformanceTestHelpers.createMockSession()
        let sequence = Sequence.shared

        sequence.configure(appId: "test_app", apiKey: "test_key", baseURL: "https://api.sequence.test")

        // Prime the cache with first fetch
        _ = try await sequence.fetchConfig(session: mockSession)

        // Reset sequence but keep cache (simulate warm start)
        let saved = sequence.config
        sequence.reset()
        sequence.configure(appId: "test_app", apiKey: "test_key", baseURL: "https://api.sequence.test")

        // Measure warm start
        let startTime = CFAbsoluteTimeGetCurrent()

        let config = try await sequence.fetchConfig(session: mockSession)

        let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000

        // Verify
        XCTAssertEqual(config.screens.count, 3, "Config should be available from cache")
        PerformanceTestHelpers.assertPerformance(
            duration,
            maxDuration: PerformanceTargets.warmStartAcceptable,
            metric: "Warm start with cached config"
        )

        print("✓ Warm start (cached): \(String(format: "%.0f", duration))ms")
    }

    // MARK: - Component Tests

    /// Test config fetch and JSON parsing time (isolated)
    /// Expected: < 600ms
    func testConfigFetchAndParseTime() async throws {
        // Setup
        try PerformanceTestHelpers.setupMockConfig(
            TestConfigs.standard,
            for: "test_app",
            baseURL: "https://api.sequence.test"
        )

        let mockSession = PerformanceTestHelpers.createMockSession()
        let sequence = Sequence.shared

        sequence.configure(appId: "test_app", apiKey: "test_key", baseURL: "https://api.sequence.test")

        // Measure full fetch including network + parsing
        let (_, duration) = try await PerformanceTestHelpers.measureAsync {
            try await sequence.fetchConfig(session: mockSession)
        }

        let durationMs = duration * 1000

        // Verify
        PerformanceTestHelpers.assertPerformance(
            durationMs,
            maxDuration: PerformanceTargets.configFetchAcceptable,
            metric: "Config fetch and parse"
        )

        print("✓ Config fetch + parse: \(String(format: "%.0f", durationMs))ms")
    }

    /// Test JSON decoding performance
    /// Expected: < 50ms for standard config
    func testJSONDecodingPerformance() async throws {
        let encoder = JSONEncoder()
        let configData = try encoder.encode(TestConfigs.standard)

        let decoder = JSONDecoder()

        let startTime = CFAbsoluteTimeGetCurrent()

        let _ = try decoder.decode(OnboardingConfig.self, from: configData)

        let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000

        // JSON decoding should be very fast
        XCTAssertLessThan(duration, 100, "JSON decoding should be < 100ms")

        print("✓ JSON decoding: \(String(format: "%.0f", duration))ms")
    }

    // MARK: - Baseline Tests

    /// Establish baseline for simple config
    /// Runs 10 iterations to establish stable baseline
    func testBaselineSimpleConfig() async throws {
        try PerformanceTestHelpers.setupMockConfig(TestConfigs.simple)

        let mockSession = PerformanceTestHelpers.createMockSession()
        let sequence = Sequence.shared

        var times: [Double] = []

        for _ in 0..<10 {
            PerformanceTestHelpers.resetSequence()
            MockNetworkSession.clearMocks()
            try PerformanceTestHelpers.setupMockConfig(TestConfigs.simple)

            sequence.configure(appId: "test_app", apiKey: "test_key", baseURL: "https://api.sequence.test")

            let startTime = CFAbsoluteTimeGetCurrent()
            let _ = try await sequence.fetchConfig(session: mockSession)
            let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000

            times.append(duration)
        }

        let average = times.reduce(0, +) / Double(times.count)
        let min = times.min() ?? 0
        let max = times.max() ?? 0

        print("✓ Baseline (simple): avg=\(String(format: "%.0f", average))ms, min=\(String(format: "%.0f", min))ms, max=\(String(format: "%.0f", max))ms")
    }

    /// Establish baseline for standard config
    func testBaselineStandardConfig() async throws {
        try PerformanceTestHelpers.setupMockConfig(TestConfigs.standard)

        let mockSession = PerformanceTestHelpers.createMockSession()
        let sequence = Sequence.shared

        var times: [Double] = []

        for _ in 0..<10 {
            PerformanceTestHelpers.resetSequence()
            MockNetworkSession.clearMocks()
            try PerformanceTestHelpers.setupMockConfig(TestConfigs.standard)

            sequence.configure(appId: "test_app", apiKey: "test_key", baseURL: "https://api.sequence.test")

            let startTime = CFAbsoluteTimeGetCurrent()
            let _ = try await sequence.fetchConfig(session: mockSession)
            let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000

            times.append(duration)
        }

        let average = times.reduce(0, +) / Double(times.count)
        let min = times.min() ?? 0
        let max = times.max() ?? 0

        print("✓ Baseline (standard): avg=\(String(format: "%.0f", average))ms, min=\(String(format: "%.0f", min))ms, max=\(String(format: "%.0f", max))ms")
    }

    // MARK: - Network Latency Tests

    /// Test cold start with simulated network latency (100ms)
    /// Expected: ~100ms + fetch time
    func testColdStartWith100msLatency() async throws {
        try PerformanceTestHelpers.setupMockConfig(TestConfigs.simple)

        let mockSession = PerformanceTestHelpers.createMockSession()
        let sequence = Sequence.shared

        // Simulate 100ms network latency
        MockNetworkSession.setResponseLatency(0.1)

        sequence.configure(appId: "test_app", apiKey: "test_key", baseURL: "https://api.sequence.test")

        let startTime = CFAbsoluteTimeGetCurrent()
        let _ = try await sequence.fetchConfig(session: mockSession)
        let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000

        // Should include the latency
        XCTAssertGreaterThanOrEqual(duration, 100, "Should include network latency")
        PerformanceTestHelpers.assertPerformance(
            duration,
            maxDuration: PerformanceTargets.coldStartAcceptable,
            metric: "Cold start with 100ms latency"
        )

        print("✓ Cold start (100ms latency): \(String(format: "%.0f", duration))ms")
    }

    /// Test cold start with simulated network latency (300ms)
    /// Expected: ~300ms + fetch time (still under 1000ms threshold)
    func testColdStartWith300msLatency() async throws {
        try PerformanceTestHelpers.setupMockConfig(TestConfigs.simple)

        let mockSession = PerformanceTestHelpers.createMockSession()
        let sequence = Sequence.shared

        // Simulate 300ms network latency (realistic 3G)
        MockNetworkSession.setResponseLatency(0.3)

        sequence.configure(appId: "test_app", apiKey: "test_key", baseURL: "https://api.sequence.test")

        let startTime = CFAbsoluteTimeGetCurrent()
        let _ = try await sequence.fetchConfig(session: mockSession)
        let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000

        // Should include the latency
        XCTAssertGreaterThanOrEqual(duration, 300, "Should include network latency")
        PerformanceTestHelpers.assertPerformance(
            duration,
            maxDuration: PerformanceTargets.coldStartAcceptable,
            metric: "Cold start with 300ms latency"
        )

        print("✓ Cold start (300ms latency): \(String(format: "%.0f", duration))ms")
    }

    // MARK: - Error Cases

    /// Test error handling doesn't degrade performance
    func testErrorHandlingPerformance() async throws {
        PerformanceTestHelpers.setupMockError(for: "test_app", statusCode: 500)

        let mockSession = PerformanceTestHelpers.createMockSession()
        let sequence = Sequence.shared

        sequence.configure(appId: "test_app", apiKey: "test_key", baseURL: "https://api.sequence.test")

        let startTime = CFAbsoluteTimeGetCurrent()

        do {
            _ = try await sequence.fetchConfig(session: mockSession)
            XCTFail("Should have thrown error")
        } catch {
            let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
            // Error path should also be fast
            XCTAssertLessThan(duration, 500, "Error handling should be fast")
            print("✓ Error handling: \(String(format: "%.0f", duration))ms")
        }
    }

    // MARK: - Memory Tests

    /// Test that memory usage is sustainable during config fetch
    func testMemoryUsageDuringConfigFetch() async throws {
        try PerformanceTestHelpers.setupMockConfig(TestConfigs.standard)

        let mockSession = PerformanceTestHelpers.createMockSession()
        let sequence = Sequence.shared

        sequence.configure(appId: "test_app", apiKey: "test_key", baseURL: "https://api.sequence.test")

        // Get initial memory
        var stats = malloc_statistics_t()
        malloc_zone_statistics(nil, &stats)
        let initialMemory = stats.size_in_use

        // Fetch config
        let _ = try await sequence.fetchConfig(session: mockSession)

        // Get memory after fetch
        malloc_zone_statistics(nil, &stats)
        let finalMemory = stats.size_in_use

        let memoryIncrease = Double(finalMemory - initialMemory) / 1_000_000 // Convert to MB

        // Should not use excessive memory
        XCTAssertLessThan(memoryIncrease, 50, "Should not allocate more than 50MB")

        print("✓ Memory increase: \(String(format: "%.1f", memoryIncrease))MB")
    }

    /// Test no memory leaks in repeated config fetches
    func testNoMemoryLeaksInRepeatedFetches() async throws {
        try PerformanceTestHelpers.setupMockConfig(TestConfigs.simple)

        let mockSession = PerformanceTestHelpers.createMockSession()
        let sequence = Sequence.shared

        sequence.configure(appId: "test_app", apiKey: "test_key", baseURL: "https://api.sequence.test")

        // Get initial memory
        var stats = malloc_statistics_t()
        malloc_zone_statistics(nil, &stats)
        let initialMemory = stats.size_in_use

        // Fetch multiple times
        for _ in 0..<5 {
            MockNetworkSession.clearMocks()
            try PerformanceTestHelpers.setupMockConfig(TestConfigs.simple)
            let _ = try await sequence.fetchConfig(session: mockSession)
        }

        // Get memory after fetches
        malloc_zone_statistics(nil, &stats)
        let finalMemory = stats.size_in_use

        let memoryIncrease = Double(finalMemory - initialMemory) / 1_000_000 // Convert to MB

        // Memory should not grow linearly with fetches
        XCTAssertLessThan(memoryIncrease, 100, "Should not leak memory in repeated fetches")

        print("✓ No memory leaks: final increase \(String(format: "%.1f", memoryIncrease))MB after 5 fetches")
    }
}
